import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// The kinds shown, several at once, as text on a button that opens their
// boxes upward (the bar is at the bottom): [value, text] pairs. The list
// stays open while boxes are ticked (a menu would close on each one);
// "All" ticks them all. Each change is sent at once: picked(values). As
// wide as its longest text (at most maxTextWidth, cut with "…" beyond), so
// the bar keeps its width; the tooltip names the kinds.
QQC2.ToolButton {
    id: kinds
    property var choices: []
    property var checkedValues: choices.map(function (c) { return c[0]; })
    property string tip
    signal picked(var values)
    readonly property alias popup: box   // for the tests
    property real maxTextWidth: Kirigami.Units.gridUnit * 4.5
    focusPolicy: Qt.NoFocus
    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
    readonly property var _labels: choices.filter(function (c) { return checkedValues.indexOf(c[0]) >= 0; }).map(function (c) { return c[1]; })
    // Drawn by contentItem alone: the desktop style would draw the button's
    // own text too, bold, under it.
    readonly property string label: _labels.length === choices.length ? "All"
        : _labels.length === 0 ? "None"
        : _labels.length <= 2 ? _labels.join(" + ")
        : _labels.length + " kinds"
    // Every text the button can show: "All", "None", one or two kinds, "n kinds".
    function _texts() {
        var t = ["All", "None", choices.length + " kinds"], l = choices.map(function (c) { return c[1]; });
        for (var i = 0; i < l.length; i++) {
            t.push(l[i]);
            for (var j = i + 1; j < l.length; j++) t.push(l[i] + " + " + l[j]);
        }
        return t;
    }
    FontMetrics { id: metrics; font: kinds.font }
    readonly property real _textWidth: Math.min(maxTextWidth, Math.ceil(Math.max.apply(null, _texts().map(function (s) { return metrics.advanceWidth(s); }))))
    implicitWidth: _textWidth + leftPadding + rightPadding + 4   // the measure is a little short of the drawing
    contentItem: QQC2.Label {
        text: kinds.label
        font: kinds.font
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        opacity: kinds.enabled ? 1 : 0.5
    }
    onClicked: box.visible ? box.close() : box.open()
    QQC2.ToolTip.text: tip + ": <b>" + (_labels.length === choices.length ? "all" : _labels.length === 0 ? "none" : _labels.join(", ")) + "</b><br><i><span style=\"font-size:" + Math.round(Kirigami.Theme.defaultFont.pointSize * 0.8 * 10) / 10 + "pt\">Click to change</span></i>"
    QQC2.ToolTip.visible: hovered && !box.visible
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

    function _set(values) {
        // In the order of the choices.
        checkedValues = choices.map(function (c) { return c[0]; }).filter(function (v) { return values.indexOf(v) >= 0; });
        picked(checkedValues);
    }

    QQC2.Popup {
        id: box
        y: -implicitHeight
        padding: Kirigami.Units.smallSpacing
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent
        contentItem: ColumnLayout {
            spacing: 0
            QQC2.CheckDelegate {
                Layout.fillWidth: true
                text: "All"
                font.bold: true
                function allState() {
                    return kinds.checkedValues.length === kinds.choices.length ? Qt.Checked
                        : kinds.checkedValues.length === 0 ? Qt.Unchecked : Qt.PartiallyChecked;
                }
                checkState: allState()
                // A click ticks them all, or, all ticked, clears them; the
                // box then follows the kinds again (the click broke the binding).
                onClicked: {
                    var all = kinds.checkedValues.length === kinds.choices.length;
                    kinds._set(all ? [] : kinds.choices.map(function (c) { return c[0]; }));
                    checkState = Qt.binding(allState);
                }
            }
            Kirigami.Separator { Layout.fillWidth: true }
            Repeater {
                model: kinds.choices
                delegate: QQC2.CheckDelegate {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData[1]
                    checked: kinds.checkedValues.indexOf(modelData[0]) >= 0
                    onClicked: {
                        var v = kinds.checkedValues.filter(function (x) { return x !== modelData[0]; });
                        if (checked) v.push(modelData[0]);
                        kinds._set(v);
                        checked = Qt.binding(function () { return kinds.checkedValues.indexOf(modelData[0]) >= 0; });
                    }
                }
            }
        }
    }
}
