import QtQuick
import qs.DCommon.Common
import qs.DCommon.Widgets
import qs.Services
import "StreamLogic.js" as Logic

DSlider {
    id: root

    property int percent: 0
    property int snapInterval: 25

    signal percentRequested(int newPercent)

    readonly property var _points: Logic.snapPoints(root.snapInterval, root.maximum)
    readonly property real _travel: Math.max(0, root.availableWidth - root.handleWidth)
    readonly property real _handleCenter: root.leftPadding + root.handleWidth / 2 + root._travel * root.visualRatio
    readonly property bool _marksFit: {
        const span = root.maximum - root.minimum;
        if (root._points.length < 2 || span <= 0)
            return true;
        let gap = span;
        for (let i = 1; i < root._points.length; i++)
            gap = Math.min(gap, root._points[i] - root._points[i - 1]);
        return root._travel * gap / span >= Style.sliderTickSize + Style.sliderHandleGap;
    }

    property int _pending: -1

    function _request(next) {
        if (next === root._pending)
            return;
        root._pending = next;
        root.percentRequested(next);
    }

    onPercentChanged: root._pending = -1
    onIsDraggingChanged: {
        if (root.isDragging)
            root._pending = -1;
    }

    minimum: 0
    unit: "%"
    valueOverride: root.percent

    Binding on value {
        value: Math.min(root.maximum, root.percent)
        when: !root.isDragging
    }

    onSliderValueChanged: newValue => {
        const snapped = root.isDragging ? Logic.softSnap(newValue, root._points, Logic.snapRadius, root.maximum) : newValue;
        root.value = snapped;
        root._request(snapped);
    }

    Repeater {
        model: root._marksFit ? root._points : []

        StyledRect {
            required property int modelData
            readonly property real ratio: root.ratioForValue(modelData)
            readonly property real centerX: root.leftPadding + root.handleWidth / 2 + root._travel * (root.mirrored ? 1 - ratio : ratio)
            readonly property bool onFilled: root.mirrored ? centerX > root._handleCenter : centerX < root._handleCenter

            width: Style.sliderTickSize
            height: width
            radius: Style.fullRadius(width, height)
            x: centerX - width / 2
            y: (root.height - height) / 2
            color: onFilled ? root.fillTextColor : Style.onSurfaceVariant
            visible: modelData > root.minimum && modelData < root.maximum && Math.abs(centerX - root._handleCenter) > Style.sliderHandleGap * 2
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            if (wheel.angleDelta.y === 0) {
                wheel.accepted = false;
                return;
            }
            const step = AudioService.wheelVolumeStep;
            const current = root._pending >= 0 ? root._pending : root.percent;
            root._request(Logic.wheelSnap(current, wheel.angleDelta.y > 0 ? step : -step, root._points, Logic.snapRadius, root.maximum));
            wheel.accepted = true;
        }
    }
}
