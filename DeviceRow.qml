import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: deviceRow

    required property var node
    signal activated()

    readonly property bool isActive: node === AudioService.sink

    width: parent ? parent.width : 0
    height: 50
    radius: Theme.cornerRadius
    color: deviceArea.containsMouse
        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
        : Theme.nestedSurface
    border.width: 0

    DankRipple { id: ripple; cornerRadius: deviceRow.radius }

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        spacing: Theme.spacingS

        DankIcon {
            id: devIcon
            name: AudioService.sinkIcon(deviceRow.node)
            size: Theme.iconSize - 4
            color: deviceRow.isActive ? Theme.primary : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - devIcon.width - parent.spacing

            StyledText {
                width: parent.width
                text: AudioService.displayName(deviceRow.node)
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                font.weight: deviceRow.isActive ? Font.Medium : Font.Normal
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }

            StyledText {
                width: parent.width
                text: deviceRow.isActive ? "Active" : "Available"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
        }
    }

    MouseArea {
        id: deviceArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            const m = mapToItem(deviceRow, mouse.x, mouse.y);
            ripple.trigger(m.x, m.y);
        }
        onClicked: deviceRow.activated()
    }
}
