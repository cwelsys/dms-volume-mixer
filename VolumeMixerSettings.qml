import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
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

            DankToggle {
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

    SelectionSetting {
        settingKey: "sortOrder"
        label: "Sort Order"
        defaultValue: "name_asc"
        options: [
            { label: "Name (A–Z)",        value: "name_asc"    },
            { label: "Name (Z–A)",        value: "name_desc"   },
            { label: "Volume (High–Low)", value: "volume_desc" },
            { label: "Volume (Low–High)", value: "volume_asc"  },
            { label: "None",              value: "none"        }
        ]
    }

    Column {
        id: streamAliasSection
        width: parent.width
        spacing: Theme.spacingXS

        property var aliases: ({})

        function reload() {
            aliases = root.loadValue("streamAliases", {})
        }

        function save(obj) {
            aliases = obj
            root.saveValue("streamAliases", obj)
        }

        Component.onCompleted: reload()

        StyledText {
            text: "Stream Aliases"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            text: "Custom display names for audio streams (matched by binary, node name, or app name)"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            width: parent.width
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: Object.keys(streamAliasSection.aliases)

            Row {
                required property string modelData
                width: streamAliasSection.width
                height: 28
                spacing: Theme.spacingS

                StyledText {
                    text: modelData + "  →  " + streamAliasSection.aliases[modelData]
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - removeBtn.width - parent.spacing
                    elide: Text.ElideRight
                }

                DankActionButton {
                    id: removeBtn
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "close"
                    iconSize: 12
                    buttonSize: 20
                    iconColor: Theme.error
                    onClicked: {
                        let a = Object.assign({}, streamAliasSection.aliases)
                        delete a[modelData]
                        streamAliasSection.save(a)
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: Theme.spacingS

            DankTextField {
                id: aliasKeyField
                width: (parent.width - addAliasBtn.width - parent.spacing * 2) / 2
                height: 28
                placeholderText: "identifier"
                font.pixelSize: Theme.fontSizeSmall
                onAccepted: if (addAliasBtn.enabled) addAliasBtn.clicked()
            }

            DankTextField {
                id: aliasValueField
                width: aliasKeyField.width
                height: 28
                placeholderText: "display name"
                font.pixelSize: Theme.fontSizeSmall
                onAccepted: if (addAliasBtn.enabled) addAliasBtn.clicked()
            }

            DankActionButton {
                id: addAliasBtn
                anchors.verticalCenter: parent.verticalCenter
                iconName: "add"
                iconSize: 14
                buttonSize: 28
                enabled: aliasKeyField.text.trim() !== "" && aliasValueField.text.trim() !== ""
                iconColor: enabled ? Theme.primary : Theme.surfaceVariantText
                onClicked: {
                    let a = Object.assign({}, streamAliasSection.aliases)
                    a[aliasKeyField.text.trim()] = aliasValueField.text.trim()
                    streamAliasSection.save(a)
                    aliasKeyField.clear()
                    aliasValueField.clear()
                }
            }
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

            DankActionButton {
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

            DankSlider {
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
