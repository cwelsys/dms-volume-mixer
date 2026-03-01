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

    readonly property real masterVolume: AudioService.sink?.audio
        ? Math.round(AudioService.sink.audio.volume * 100)
        : 0
    readonly property bool masterMuted: AudioService.sink?.audio?.muted ?? false

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
        AudioService.volumeChanged();
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
            acceptedButtons: Qt.NoButton
            implicitWidth: hPillRow.implicitWidth
            implicitHeight: hPillRow.implicitHeight
            onWheel: wheel => root.adjustVolumeByScroll(wheel)

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
            acceptedButtons: Qt.NoButton
            implicitWidth: vPillCol.implicitWidth
            implicitHeight: vPillCol.implicitHeight
            onWheel: wheel => root.adjustVolumeByScroll(wheel)

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
                implicitHeight: Theme.spacingM + topSection.height + Theme.spacingS + scrollSection.height + Theme.spacingM

                property bool devicesExpanded: false

                property int maxStreamVol: {
                    const stored = root.pluginData?.maxStreamVol;
                    if (typeof stored === "number" && stored >= 100)
                        return stored;
                    return 200;
                }

                readonly property bool showDeviceSelector: root.pluginData?.showDeviceSelector !== false
                readonly property string sortOrder: root.pluginData?.sortOrder ?? "name_asc"

                Column {
                    id: topSection
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: Theme.spacingM
                    anchors.leftMargin: Theme.spacingM
                    anchors.rightMargin: Theme.spacingM
                    spacing: Theme.spacingS

                    Row {
                        width: parent.width
                        height: 40
                        spacing: 0

                        Rectangle {
                            width: Theme.iconSize + Theme.spacingS * 2
                            height: Theme.iconSize + Theme.spacingS * 2
                            anchors.verticalCenter: parent.verticalCenter
                            radius: (Theme.iconSize + Theme.spacingS * 2) / 2
                            color: masterMuteArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                            DankRipple {
                                id: masterMuteRipple
                                cornerRadius: parent.radius
                            }

                            MouseArea {
                                id: masterMuteArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => masterMuteRipple.trigger(mouse.x, mouse.y)
                                onClicked: {
                                    if (AudioService.sink?.audio)
                                        AudioService.sink.audio.muted = !AudioService.sink.audio.muted;
                                }
                            }

                            DankIcon {
                                anchors.centerIn: parent
                                name: {
                                    if (!AudioService.sink?.audio || AudioService.sink.audio.muted)
                                        return "volume_off";
                                    const v = AudioService.sink.audio.volume;
                                    if (v === 0)
                                        return "volume_mute";
                                    if (v <= 0.33)
                                        return "volume_down";
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
                            width: parent.width - (Theme.iconSize + Theme.spacingS * 2)
                            height: 40
                            minimum: 0
                            maximum: AudioService.sinkMaxVolume
                            value: AudioService.sink?.audio ? Math.min(AudioService.sinkMaxVolume, Math.round(AudioService.sink.audio.volume * 100)) : 0
                            showValue: true
                            unit: "%"
                            valueOverride: actualVolumePercent
                            thumbOutlineColor: Theme.surfaceVariant

                            onSliderValueChanged: newValue => {
                                if (AudioService.sink?.audio) {
                                    AudioService.sink.audio.volume = newValue / 100;
                                    if (newValue > 0 && AudioService.sink.audio.muted)
                                        AudioService.sink.audio.muted = false;
                                    AudioService.volumeChanged();
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: activeDeviceCard
                        visible: AudioService.sink !== null && popoutItem.showDeviceSelector
                        width: parent.width
                        height: 50
                        radius: Theme.cornerRadius
                        color: activeDeviceArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                        border.color: Theme.primary
                        border.width: 0

                        DankRipple {
                            id: activeDeviceRipple
                            cornerRadius: activeDeviceCard.radius
                        }

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
                            onClicked: {
                                popoutItem.devicesExpanded = !popoutItem.devicesExpanded;
                            }
                        }
                    }
                }

                DankFlickable {
                    id: scrollSection
                    anchors.top: topSection.bottom
                    anchors.topMargin: Theme.spacingS
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Theme.spacingM
                    anchors.rightMargin: Theme.spacingM
                    height: Math.min(scrollColumn.height, 300)
                    contentHeight: scrollColumn.height
                    clip: true

                    Column {
                        id: scrollColumn
                        width: parent.width
                        spacing: Theme.spacingS
                        bottomPadding: Theme.spacingS

                        Repeater {
                            model: ScriptModel {
                                values: popoutItem.devicesExpanded && popoutItem.showDeviceSelector
                                    ? Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream && n !== AudioService.sink)
                                    : []
                            }

                            delegate: Rectangle {
                                id: otherDeviceDelegate
                                required property var modelData

                                width: parent.width
                                height: 50
                                radius: Theme.cornerRadius
                                color: otherDeviceArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                                border.width: 0

                                DankRipple {
                                    id: otherDeviceRipple
                                    cornerRadius: otherDeviceDelegate.radius
                                }

                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: Theme.spacingM
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: AudioService.sinkIcon(modelData)
                                        size: Theme.iconSize - 4
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter

                                        StyledText {
                                            text: AudioService.displayName(modelData)
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: Theme.surfaceText
                                        }

                                        StyledText {
                                            text: "Available"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }
                                    }
                                }

                                MouseArea {
                                    id: otherDeviceArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: mouse => {
                                        const mapped = otherDeviceArea.mapToItem(otherDeviceDelegate, mouse.x, mouse.y);
                                        otherDeviceRipple.trigger(mapped.x, mapped.y);
                                    }
                                    onClicked: {
                                        Pipewire.preferredDefaultAudioSink = modelData;
                                        popoutItem.devicesExpanded = false;
                                    }
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            height: 20

                        }

                        Repeater {
                            model: ScriptModel {
                                values: {
                                    const nodes = Pipewire.nodes.values.filter(n => n.audio && n.isSink && n.isStream && n.name !== "quickshell");
                                    const order = popoutItem.sortOrder;
                                    if (order === "none") return nodes;
                                    return nodes.sort((a, b) => {
                                        if (order === "volume_desc")
                                            return (b.audio?.volume ?? 0) - (a.audio?.volume ?? 0);
                                        if (order === "volume_asc")
                                            return (a.audio?.volume ?? 0) - (b.audio?.volume ?? 0);
                                        if (order === "name_desc")
                                            return (b.properties?.["application.name"] ?? "").localeCompare(a.properties?.["application.name"] ?? "");
                                        return (a.properties?.["application.name"] ?? "").localeCompare(b.properties?.["application.name"] ?? "");
                                    });
                                }
                            }

                            delegate: Rectangle {
                                required property var modelData

                                width: parent.width
                                height: 50
                                radius: Theme.cornerRadius
                                color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                                border.width: 0

                                PwObjectTracker {
                                    objects: [modelData]
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.rightMargin: Theme.spacingM
                                    spacing: Theme.spacingS

                                    Rectangle {
                                        Layout.preferredWidth: Theme.iconSize - 4
                                        Layout.preferredHeight: Theme.iconSize - 4
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: (Theme.iconSize - 4) / 2
                                        color: resetArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                                        DankRipple {
                                            id: resetRipple
                                            cornerRadius: parent.radius
                                        }

                                        MouseArea {
                                            id: resetArea
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onPressed: mouse => resetRipple.trigger(mouse.x, mouse.y)
                                            onClicked: {
                                                if (modelData.audio) {
                                                    SessionData.suppressOSDTemporarily();
                                                    modelData.audio.volume = 1.0;
                                                    if (modelData.audio.muted)
                                                        modelData.audio.muted = false;
                                                }
                                            }
                                        }

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "replay"
                                            size: Theme.iconSize - 6
                                            color: resetArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                        }
                                    }

                                    Item {
                                        id: titleClip
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: titleText.implicitHeight
                                        Layout.alignment: Qt.AlignVCenter
                                        clip: true

                                        readonly property bool overflows: titleText.implicitWidth > titleClip.width
                                        readonly property int scrollPx: overflows ? Math.ceil(titleText.implicitWidth - titleClip.width) : 0

                                        HoverHandler {
                                            id: titleHover
                                            onHoveredChanged: {
                                                if (hovered && titleClip.overflows) {
                                                    snapBack.stop();
                                                    titleText.x = 0;
                                                    scrollAnim.restart();
                                                } else {
                                                    scrollAnim.stop();
                                                    snapBack.start();
                                                }
                                            }
                                        }

                                        StyledText {
                                            id: titleText
                                            text: {
                                                const media = modelData.properties?.["media.name"] || "";
                                                const app = AudioService.displayName(modelData);
                                                return media ? app + ": " + media : app;
                                            }
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: Theme.surfaceText
                                            wrapMode: Text.NoWrap
                                            elide: Text.ElideNone
                                        }

                                        SequentialAnimation {
                                            id: scrollAnim
                                            loops: Animation.Infinite

                                            PauseAnimation { duration: 500 }
                                            NumberAnimation {
                                                target: titleText
                                                property: "x"
                                                to: -titleClip.scrollPx
                                                duration: Math.max(1500, titleClip.scrollPx * 25)
                                                easing.type: Easing.InOutSine
                                            }
                                            PauseAnimation { duration: 1200 }
                                            NumberAnimation {
                                                target: titleText
                                                property: "x"
                                                to: 0
                                                duration: 500
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        NumberAnimation {
                                            id: snapBack
                                            target: titleText
                                            property: "x"
                                            to: 0
                                            duration: 200
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: Theme.iconSize + Theme.spacingS * 2
                                        Layout.preferredHeight: Theme.iconSize + Theme.spacingS * 2
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: Theme.cornerRadius
                                        color: streamMuteArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                                        DankRipple {
                                            id: streamMuteRipple
                                            cornerRadius: parent.radius
                                        }

                                        MouseArea {
                                            id: streamMuteArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onPressed: mouse => streamMuteRipple.trigger(mouse.x, mouse.y)
                                            onClicked: {
                                                if (modelData.audio) {
                                                    SessionData.suppressOSDTemporarily();
                                                    modelData.audio.muted = !modelData.audio.muted;
                                                }
                                            }
                                        }

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: {
                                                if (!modelData.audio || modelData.audio.muted)
                                                    return "volume_off";
                                                const v = modelData.audio.volume;
                                                if (v === 0)
                                                    return "volume_mute";
                                                if (v <= 0.33)
                                                    return "volume_down";
                                                return "volume_up";
                                            }
                                            size: Theme.iconSize
                                            color: modelData.audio && !modelData.audio.muted && modelData.audio.volume > 0 ? Theme.primary : Theme.surfaceText
                                        }
                                    }

                                    DankSlider {
                                        id: streamSlider
                                        readonly property real actualVolumePercent: modelData.audio ? Math.round(modelData.audio.volume * 100) : 0

                                        Layout.preferredWidth: 100
                                        Layout.preferredHeight: 40
                                        minimum: 0
                                        maximum: popoutItem.maxStreamVol
                                        showValue: true

                                        Binding on value {
                                            value: modelData.audio ? Math.min(popoutItem.maxStreamVol, Math.round(modelData.audio.volume * 100)) : 0
                                            when: !streamSlider.isDragging
                                        }
                                        unit: "%"
                                        valueOverride: actualVolumePercent
                                        thumbOutlineColor: Theme.surfaceContainer

                                        onSliderValueChanged: newValue => {
                                            if (modelData.audio) {
                                                SessionData.suppressOSDTemporarily();
                                                modelData.audio.volume = newValue / 100;
                                                if (newValue > 0 && modelData.audio.muted)
                                                    modelData.audio.muted = false;
                                                AudioService.playVolumeChangeSoundIfEnabled();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
