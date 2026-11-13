import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import "StreamLogic.js" as Logic

Column {
    id: streamRow

    required property var group
    property int maxVol: 100
    property int snapInterval: 25
    property bool expanded: false

    readonly property var nodes: group && group.nodes ? group.nodes : []
    readonly property string appName: group ? group.appName : ""
    readonly property string iconSource: group ? group.iconSource : ""
    readonly property bool expandable: nodes.length > 1

    // Identity candidates for MPRIS correlation, from the head node.
    readonly property var _candidates: {
        const n = nodes.length ? nodes[0] : null;
        const props = (n && n.properties) ? n.properties : ({});
        return Logic.buildCandidates(props);
    }
    readonly property string _entryId: (group && group.entry && group.entry.id) ? String(group.entry.id) : ""

    // First MPRIS player whose identity matches this group, or null.
    readonly property var _mprisPlayer: {
        const players = MprisController.availablePlayers;
        if (!players)
            return null;
        for (let i = 0; i < players.length; i++) {
            const p = players[i];
            if (!p)
                continue;
            const de = ("desktopEntry" in p && p.desktopEntry) ? String(p.desktopEntry) : "";
            if (Logic.playerMatchesGroup(p.identity, de, _entryId, _candidates))
                return p;
        }
        return null;
    }

    // Header track: Playing or Paused (Stopped excluded).
    readonly property string nowPlayingLoaded: {
        const p = _mprisPlayer;
        if (!p || !p.trackTitle || p.playbackState === MprisPlaybackState.Stopped)
            return "";
        return Logic.formatNowPlaying(p.trackTitle, p.trackArtist);
    }

    // Per-stream fill: only an actively Playing session, so a stale title never sticks to a blank stream.
    readonly property string nowPlayingActive: {
        const p = _mprisPlayer;
        if (!p || !p.isPlaying)
            return "";
        return Logic.formatNowPlaying(p.trackTitle, p.trackArtist);
    }

    // Index of the sole descriptor-less stream in the group, or -1 if 0 or 2+.
    readonly property int _soleBlankIndex: {
        const d = group ? group.descriptors : [];
        let idx = -1, count = 0;
        for (let i = 0; i < d.length; i++) {
            if (!d[i]) { count++; idx = i; }
        }
        return count === 1 ? idx : -1;
    }

    readonly property string subtitle: {
        const d = group ? group.descriptors : [];
        if (nodes.length > 1) {
            const first = d.length ? d[0] : "";
            const allSame = first !== "" && d.every(x => x === first);
            if (allSame)
                // Homogeneous group: now-playing leads.
                return nowPlayingLoaded !== "" ? nowPlayingLoaded : first;
            return nodes.length + " streams";
        }
        return nowPlayingLoaded !== "" ? nowPlayingLoaded : (d.length ? d[0] : "");
    }

    readonly property real groupVolumePercent: {
        let mx = 0;
        for (let i = 0; i < nodes.length; i++) {
            const a = nodes[i].audio;
            if (a && a.volume > mx)
                mx = a.volume;
        }
        return Math.round(mx * 100);
    }

    readonly property bool allMuted: nodes.length === 0 ? true : nodes.every(n => !n.audio || n.audio.muted)

    function setGroupVolume(percent) {
        SessionData.suppressOSDTemporarily();
        for (let i = 0; i < nodes.length; i++) {
            const a = nodes[i].audio;
            if (!a)
                continue;
            a.volume = percent / 100;
            if (percent > 0 && a.muted)
                a.muted = false;
        }
        AudioService.playVolumeChangeSoundIfEnabled();
    }

    function toggleGroupMute() {
        SessionData.suppressOSDTemporarily();
        const anyUnmuted = nodes.some(n => n.audio && !n.audio.muted);
        for (let i = 0; i < nodes.length; i++) {
            const a = nodes[i].audio;
            if (a)
                a.muted = anyUnmuted;
        }
    }

    function resetGroup() {
        SessionData.suppressOSDTemporarily();
        for (let i = 0; i < nodes.length; i++) {
            const a = nodes[i].audio;
            if (!a)
                continue;
            a.volume = 1.0;
            a.muted = false;
        }
    }

    width: parent ? parent.width : 0
    spacing: Theme.spacingXS

    // === Header (aggregate) row ===
    Rectangle {
        width: parent.width
        height: 50
        radius: Theme.cornerRadius
        color: Theme.nestedSurface
        border.width: 0

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            spacing: Theme.spacingS

            // App icon; hovering it reveals a reset-to-100% overlay.
            Item {
                id: iconSlot
                Layout.preferredWidth: Theme.iconSize
                Layout.preferredHeight: Theme.iconSize
                Layout.alignment: Qt.AlignVCenter

                IconImage {
                    id: appIcon
                    anchors.fill: parent
                    source: streamRow.iconSource
                    smooth: true
                    mipmap: true
                    asynchronous: true
                    visible: status === Image.Ready
                    opacity: resetArea.containsMouse ? 0.15 : 1.0
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !appIcon.visible
                    radius: Theme.cornerRadius
                    color: Theme.surfaceLight
                    opacity: resetArea.containsMouse ? 0.15 : 1.0

                    StyledText {
                        anchors.centerIn: parent
                        text: streamRow.appName ? streamRow.appName.charAt(0).toUpperCase() : "?"
                        font.pixelSize: Theme.iconSize * 0.4
                        font.weight: Font.Medium
                        color: Theme.primary
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.cornerRadius
                    visible: resetArea.containsMouse
                    color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.85)

                    DIcon {
                        anchors.centerIn: parent
                        name: "replay"
                        size: Theme.iconSize - 6
                        color: Theme.primary
                    }
                }

                MouseArea {
                    id: resetArea
                    anchors.fill: parent
                    anchors.margins: -Theme.spacingXS
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: streamRow.resetGroup()
                }
            }

            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                StyledText {
                    width: parent.width
                    text: streamRow.appName
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                StyledText {
                    width: parent.width
                    visible: streamRow.subtitle !== ""
                    text: streamRow.subtitle
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }
            }

            // Expand/collapse chevron (only when >1 stream)
            Rectangle {
                Layout.preferredWidth: Theme.iconSize + Theme.spacingS * 2
                Layout.preferredHeight: Theme.iconSize + Theme.spacingS * 2
                Layout.alignment: Qt.AlignVCenter
                visible: streamRow.expandable
                radius: Theme.cornerRadius
                color: chevronArea.containsMouse ? Theme.primaryHover : "transparent"

                MouseArea {
                    id: chevronArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: streamRow.expanded = !streamRow.expanded
                }

                DIcon {
                    anchors.centerIn: parent
                    name: streamRow.expanded ? "expand_less" : "expand_more"
                    size: Theme.iconSize - 4
                    color: Theme.surfaceVariantText
                }
            }

            Rectangle {
                Layout.preferredWidth: Theme.iconSize + Theme.spacingS * 2
                Layout.preferredHeight: Theme.iconSize + Theme.spacingS * 2
                Layout.alignment: Qt.AlignVCenter
                radius: Theme.cornerRadius
                color: muteArea.containsMouse ? Theme.primaryHover : "transparent"

                DRipple { id: muteRipple; cornerRadius: parent.radius }

                MouseArea {
                    id: muteArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => muteRipple.trigger(mouse.x, mouse.y)
                    onClicked: streamRow.toggleGroupMute()
                }

                DIcon {
                    anchors.centerIn: parent
                    name: {
                        if (streamRow.allMuted)
                            return "volume_off";
                        if (streamRow.groupVolumePercent === 0)
                            return "volume_mute";
                        if (streamRow.groupVolumePercent <= 33)
                            return "volume_down";
                        return "volume_up";
                    }
                    size: Theme.iconSize - 4
                    color: (!streamRow.allMuted && streamRow.groupVolumePercent > 0) ? Theme.primary : Theme.surfaceText
                }
            }

            VolumeSlider {
                id: slider
                Layout.preferredWidth: 100
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignVCenter
                maximum: streamRow.maxVol
                percent: streamRow.groupVolumePercent
                snapInterval: streamRow.snapInterval
                showValue: true
                thumbOutlineColor: Theme.surfaceContainer

                onPercentRequested: newValue => streamRow.setGroupVolume(newValue)
            }
        }
    }

    // === Per-stream sub-rows (expanded) ===
    Repeater {
        model: ScriptModel { values: streamRow.expanded ? streamRow.nodes : [] }
        delegate: Rectangle {
            required property var modelData
            required property int index

            readonly property string subLabel: {
                const d = streamRow.group ? streamRow.group.descriptors : [];
                const dv = (index < d.length) ? d[index] : "";
                if (dv !== "")
                    return dv;
                // Only the sole blank stream, and only from an actively-playing session.
                if (index === streamRow._soleBlankIndex && streamRow.nowPlayingActive !== "")
                    return streamRow.nowPlayingActive;
                return "Stream " + (index + 1);
            }

            width: streamRow.width - Theme.spacingL
            x: Theme.spacingL
            height: 44
            radius: Theme.cornerRadius
            color: Theme.nestedSurface

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                spacing: Theme.spacingS

                StyledText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: subLabel
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                DIcon {
                    Layout.alignment: Qt.AlignVCenter
                    name: (!modelData.audio || modelData.audio.muted) ? "volume_off" : "volume_up"
                    size: Theme.iconSize - 6
                    color: (modelData.audio && !modelData.audio.muted) ? Theme.primary : Theme.surfaceText

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.audio) {
                                SessionData.suppressOSDTemporarily();
                                modelData.audio.muted = !modelData.audio.muted;
                            }
                        }
                    }
                }

                VolumeSlider {
                    id: subSlider
                    Layout.preferredWidth: 90
                    Layout.preferredHeight: 36
                    Layout.alignment: Qt.AlignVCenter
                    maximum: streamRow.maxVol
                    percent: modelData.audio ? Math.round(modelData.audio.volume * 100) : 0
                    snapInterval: streamRow.snapInterval
                    showValue: true
                    thumbOutlineColor: Theme.surfaceContainer

                    onPercentRequested: newValue => {
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
