import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "volumeMixer"

    SelectionSetting {
        settingKey: "pillIcon"
        label: "Pill Icon"
        defaultValue: "volume"
        options: [
            { label: "Volume (Dynamic)", value: "volume" },
            { label: "Mixer",            value: "mixer"  }
        ]
    }

    SelectionSetting {
        settingKey: "pillDisplay"
        label: "Pill Display"
        defaultValue: "both"
        options: [
            { label: "Both", value: "both" },
            { label: "Icon", value: "icon" },
            { label: "Percent", value: "percent" }
        ]
    }

    SelectionSetting {
        settingKey: "snapInterval"
        label: "Slider Snapping"
        defaultValue: "25"
        options: [
            { label: "Quarters (25/50/75)", value: "25" },
            { label: "Every 10", value: "10" },
            { label: "Off", value: "0" }
        ]
    }

    ToggleSetting {
        settingKey: "identifyFromProcesses"
        label: "Identify Apps From Processes"
        description: "Reads /proc for processes playing audio to name games and wrapped apps"
        defaultValue: true
    }

    Column {
        id: deviceSelectorSetting
        width: parent.width
        spacing: Theme.spacingXS

        property bool isInitialized: false
        property bool value: true

        function loadValue() {
            value = root.loadValue("showDeviceSelector", true)
            isInitialized = true
        }

        Component.onCompleted: Qt.callLater(loadValue)

        onValueChanged: {
            if (!isInitialized) return
            root.saveValue("showDeviceSelector", value)
        }

        Item {
            width: parent.width
            height: deviceLabel.implicitHeight

            StyledText {
                id: deviceLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Output Device"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            DToggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: deviceSelectorSetting.value
                onToggled: isChecked => deviceSelectorSetting.value = isChecked
            }
        }

        StyledText {
            text: "Display active output device selection"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            width: parent.width
            wrapMode: Text.WordWrap
        }
    }

    Column {
        id: maxVolSection
        width: parent.width
        spacing: Theme.spacingS

        readonly property int defaultValue: 200
        property int currentValue: 200

        function loadValue() {
            currentValue = root.loadValue("maxStreamVol", defaultValue)
        }

        Component.onCompleted: loadValue()

        StyledText {
            text: "Volume Cap"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            text: "How high the slider goes"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            width: parent.width
            wrapMode: Text.WordWrap
        }

        RowLayout {
            width: parent.width
            spacing: Theme.spacingS

            DActionButton {
                Layout.alignment: Qt.AlignVCenter
                iconName: "replay"
                iconSize: 12
                buttonSize: 20
                enabled: maxVolSection.currentValue !== maxVolSection.defaultValue
                iconColor: enabled ? Theme.primary : Theme.surfaceVariantText
                tooltipText: "Reset to default"
                onClicked: {
                    maxVolSection.currentValue = maxVolSection.defaultValue
                    root.saveValue("maxStreamVol", maxVolSection.defaultValue)
                }
            }

            DSlider {
                id: maxVolSlider
                Layout.fillWidth: true
                minimum: 100
                maximum: 1000
                showValue: true
                unit: "%"
                wheelEnabled: false
                thumbOutlineColor: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)

                Binding on value {
                    value: maxVolSection.currentValue
                    when: !maxVolSlider.isDragging
                }

                onSliderValueChanged: newValue => {
                    maxVolSection.currentValue = newValue
                    root.saveValue("maxStreamVol", newValue)
                }
            }
        }
    }
}
