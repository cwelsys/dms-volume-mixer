import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    popoutWidth: 400
    property int maxPopoutHeight: 450

    readonly property real masterVolume: AudioService.sink?.audio
        ? Math.round(AudioService.sink.audio.volume * 100)
        : 0
    readonly property bool masterMuted: AudioService.sink?.audio?.muted ?? false

    // Keep stream-node .properties populated at all times so grouping/resolution
    // (StreamIdentity.buildGroups) sees real props the moment the popout opens.
    // A PwNode's properties map is empty until a PwObjectTracker binds it.
    readonly property var trackedStreamNodes: Pipewire.nodes.values.filter(n => n.audio && n.isSink && n.isStream && n.name !== "quickshell")

    PwObjectTracker { objects: root.trackedStreamNodes }

    // Root-level, not inside the popout: the popout Component is torn down on
    // close, and the PID -> Steam app id cache should outlive it rather than
    // re-reading /proc every time the mixer is opened.
    StreamIdentity { id: streamIdentity }

    function adjustVolumeByScroll(wheelEvent) {
        if (!AudioService.sink?.audio)
            return;
        let currentVolume = AudioService.sink.audio.volume * 100;
        let maxVol = AudioService.sinkMaxVolume;
        let newVolume;
        if (wheelEvent.angleDelta.y > 0)
            newVolume = Math.min(maxVol, currentVolume + 5);
        else
            newVolume = Math.max(0, currentVolume - 5);
        AudioService.sink.audio.muted = false;
        AudioService.sink.audio.volume = newVolume / 100;
        wheelEvent.accepted = true;
    }

    function pillIcon() {
        if ((root.pluginData?.pillIcon ?? "volume") === "mixer")
            return "tune";
        if (root.masterMuted || root.masterVolume === 0)
            return "volume_off";
        if (root.masterVolume <= 33)
            return "volume_down";
        return "volume_up";
    }

    horizontalBarPill: Component {
        MouseArea {
            acceptedButtons: Qt.MiddleButton
            implicitWidth: hPillRow.implicitWidth
            implicitHeight: hPillRow.implicitHeight
            onWheel: wheel => root.adjustVolumeByScroll(wheel)
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton)
                    AudioService.toggleMute();
            }

            Row {
                id: hPillRow
                spacing: Theme.spacingS

                DankIcon {
                    visible: (root.pluginData?.pillDisplay ?? "both") !== "percent"
                    name: root.pillIcon()
                    size: Theme.barIconSize(root.barThickness, -4)
                    color: Theme.widgetIconColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    visible: (root.pluginData?.pillDisplay ?? "both") !== "icon"
                    text: root.masterVolume + "%"
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    verticalBarPill: Component {
        MouseArea {
            acceptedButtons: Qt.MiddleButton
            implicitWidth: vPillCol.implicitWidth
            implicitHeight: vPillCol.implicitHeight
            onWheel: wheel => root.adjustVolumeByScroll(wheel)
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton)
                    AudioService.toggleMute();
            }

            Column {
                id: vPillCol
                spacing: 1

                DankIcon {
                    visible: (root.pluginData?.pillDisplay ?? "both") !== "percent"
                    name: root.pillIcon()
                    size: Theme.barIconSize(root.barThickness, -2)
                    color: Theme.widgetIconColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    visible: (root.pluginData?.pillDisplay ?? "both") !== "icon"
                    text: root.masterVolume + "%"
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {

            Item {
                id: popoutItem
                width: parent.width
                readonly property int topPad: Theme.spacingM
                implicitHeight: Math.min(topPad + topSection.height + Theme.spacingS + flick.contentHeight + Theme.spacingM, root.maxPopoutHeight)

                readonly property bool showDeviceSelector: root.pluginData?.showDeviceSelector !== false
                property bool devicesExpanded: false
                property int maxStreamVol: {
                    const stored = root.pluginData?.maxStreamVol;
                    return (typeof stored === "number" && stored >= 100) ? stored : 200;
                }

                readonly property var streamNodes: root.trackedStreamNodes
                readonly property var streamGroups: {
                    streamIdentity.steamRevision;
                    return streamIdentity.buildGroups(streamNodes);
                }
                readonly property var otherDevices: {
                    const hidden = SessionData.hiddenOutputDeviceNames ?? [];
                    return Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream && n !== AudioService.sink && !hidden.includes(n.name));
                }

                Column {
                    id: topSection
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: popoutItem.topPad
                    anchors.leftMargin: Theme.spacingM
                    anchors.rightMargin: Theme.spacingM
                    spacing: Theme.spacingS

                    // === Master row ===
                    Row {
                        width: parent.width
                        height: 40
                        spacing: Theme.spacingS

                        Rectangle {
                            width: Theme.iconSize + Theme.spacingS * 2
                            height: Theme.iconSize + Theme.spacingS * 2
                            anchors.verticalCenter: parent.verticalCenter
                            radius: (Theme.iconSize + Theme.spacingS * 2) / 2
                            color: masterMuteArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                            DankRipple { id: masterMuteRipple; cornerRadius: parent.radius }

                            MouseArea {
                                id: masterMuteArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => masterMuteRipple.trigger(mouse.x, mouse.y)
                                onClicked: {
                                    if (AudioService.sink?.audio) {
                                        SessionData.suppressOSDTemporarily();
                                        AudioService.sink.audio.muted = !AudioService.sink.audio.muted;
                                    }
                                }
                            }

                            DankIcon {
                                anchors.centerIn: parent
                                name: {
                                    if (!AudioService.sink?.audio || AudioService.sink.audio.muted)
                                        return "volume_off";
                                    const v = AudioService.sink.audio.volume;
                                    if (v === 0) return "volume_mute";
                                    if (v <= 0.33) return "volume_down";
                                    return "volume_up";
                                }
                                size: Theme.iconSize
                                color: AudioService.sink?.audio && !AudioService.sink.audio.muted && AudioService.sink.audio.volume > 0 ? Theme.primary : Theme.surfaceText
                            }
                        }

                        DankSlider {
                            id: masterSlider
                            readonly property real actualVolumePercent: AudioService.sink?.audio ? Math.round(AudioService.sink.audio.volume * 100) : 0

                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - (Theme.iconSize + Theme.spacingS * 2) - masterPct.width - parent.spacing * 2
                            height: 40
                            minimum: 0
                            maximum: AudioService.sinkMaxVolume
                            showValue: false
                            unit: "%"
                            valueOverride: actualVolumePercent
                            thumbOutlineColor: Theme.surfaceVariant

                            Binding on value {
                                value: Math.min(AudioService.sinkMaxVolume, masterSlider.actualVolumePercent)
                                when: !masterSlider.isDragging
                            }

                            onSliderValueChanged: newValue => {
                                if (AudioService.sink?.audio) {
                                    // Suppressing the OSD also gates AudioService's own
                                    // volume-change sound, so play it back explicitly.
                                    SessionData.suppressOSDTemporarily();
                                    AudioService.sink.audio.volume = newValue / 100;
                                    if (newValue > 0 && AudioService.sink.audio.muted)
                                        AudioService.sink.audio.muted = false;
                                    AudioService.playVolumeChangeSoundIfEnabled();
                                }
                            }
                        }

                        StyledText {
                            id: masterPct
                            anchors.verticalCenter: parent.verticalCenter
                            // TextMetrics reports a fractional advance while Text rounds its
                            // own requirement up, so an exact-fit width elides "100%" to "100…".
                            width: Math.ceil(pctMetrics.width) + 1
                            horizontalAlignment: Text.AlignRight
                            text: root.masterVolume + "%"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            elide: Text.ElideNone
                            wrapMode: Text.NoWrap

                            TextMetrics {
                                id: pctMetrics
                                font: masterPct.font
                                text: Math.round(AudioService.sinkMaxVolume) + "%"
                            }
                        }
                    }

                    // === Active device card (disclosure toggle) ===
                    Rectangle {
                        id: activeDeviceCard
                        visible: AudioService.sink !== null && popoutItem.showDeviceSelector
                        width: parent.width
                        height: 50
                        radius: Theme.cornerRadius
                        color: activeDeviceArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Theme.nestedSurface

                        DankRipple { id: activeDeviceRipple; cornerRadius: activeDeviceCard.radius }

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.spacingM
                            spacing: Theme.spacingS

                            DankIcon {
                                name: AudioService.sinkIcon(AudioService.sink)
                                size: Theme.iconSize - 4
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    text: AudioService.displayName(AudioService.sink)
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                }

                                StyledText {
                                    text: "Active"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                            }
                        }

                        DankIcon {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            name: popoutItem.devicesExpanded ? "expand_less" : "expand_more"
                            size: Theme.iconSize - 4
                            color: Theme.surfaceVariantText
                        }

                        MouseArea {
                            id: activeDeviceArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => {
                                const mapped = activeDeviceArea.mapToItem(activeDeviceCard, mouse.x, mouse.y);
                                activeDeviceRipple.trigger(mapped.x, mapped.y);
                            }
                            onClicked: popoutItem.devicesExpanded = !popoutItem.devicesExpanded
                        }
                    }
                }

                DankFlickable {
                    id: flick
                    anchors.top: topSection.bottom
                    anchors.topMargin: Theme.spacingS
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Theme.spacingM
                    anchors.rightMargin: Theme.spacingM
                    anchors.bottomMargin: Theme.spacingM
                    contentHeight: listColumn.implicitHeight
                    clip: true

                    Column {
                        id: listColumn
                        width: flick.width
                        spacing: Theme.spacingS

                        // === Expanded device list ===
                        Repeater {
                            model: ScriptModel {
                                values: popoutItem.devicesExpanded && popoutItem.showDeviceSelector ? popoutItem.otherDevices : []
                            }
                            delegate: DeviceRow {
                                required property var modelData
                                width: listColumn.width
                                node: modelData
                                onActivated: {
                                    AudioService.setSink(modelData);
                                    popoutItem.devicesExpanded = false;
                                }
                            }
                        }

                        // Headroom for the first stream row's floating %-bubble.
                        Item {
                            width: 1
                            height: 10
                            visible: popoutItem.streamGroups.length > 0
                        }

                        // === Applications ===
                        Repeater {
                            model: ScriptModel { objectProp: "key"; values: popoutItem.streamGroups }
                            delegate: StreamRow {
                                required property var modelData
                                width: listColumn.width
                                group: modelData
                                maxVol: popoutItem.maxStreamVol
                            }
                        }
                    }
                }
            }
        }
    }
}
