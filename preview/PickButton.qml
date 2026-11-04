import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// A value printed as text on a button that opens the list of the choices,
// upward (the bar is at the bottom): [value, text] pairs. With wheelPicks,
// the wheel over it goes through them too, gently: one choice a notch (the
// small steps of a touchpad or a fine wheel added up), one at most every
// stepMs, and the choice is sent once the wheel has been still for
// settleMs: a spin through three only loads the last. The button is as wide
// as its longest choice (at most maxTextWidth, cut with "…" beyond), so the
// bar keeps its width; the tooltip gives the whole value.
QQC2.ToolButton {
    id: pick
    property var choices: []
    property int current: 0
    property string prefix
    property string tip
    property bool wheelPicks: false
    property int stepMs: 150
    property int settleMs: 350
    property real _wheel: 0
    property double _lastStep: 0
    signal picked(var value)
    property real maxTextWidth: Kirigami.Units.gridUnit * 4.5
    focusPolicy: Qt.NoFocus
    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
    // The value, drawn by contentItem alone: the desktop style would draw
    // the button's own text too, bold, under it.
    readonly property string label: choices.length ? prefix + choices[current][1] : ""
    FontMetrics { id: metrics; font: pick.font }
    readonly property real _textWidth: Math.min(maxTextWidth, Math.ceil(Math.max.apply(null, [0].concat(choices.map(function (c) { return metrics.advanceWidth(prefix + c[1]); })))))
    implicitWidth: _textWidth + leftPadding + rightPadding + 4   // the measure is a little short of the drawing
    contentItem: QQC2.Label {
        text: pick.label
        font: pick.font
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        opacity: pick.enabled ? 1 : 0.5
    }
    // A second click closes the list: a press on the button itself no
    // longer counts as outside (it closed the menu, then reopened it).
    onClicked: pickMenu.visible ? pickMenu.close() : pickMenu.open()
    // The setting and its whole value, then how to change it, smaller.
    QQC2.ToolTip.text: (tip ? tip + ": " : "") + "<b>" + label + "</b><br><i><span style=\"font-size:" + Math.round(Kirigami.Theme.defaultFont.pointSize * 0.8 * 10) / 10 + "pt\">" + (wheelPicks ? "Wheel or click to change" : "Click to change") + "</span></i>"
    QQC2.ToolTip.visible: hovered && !pickMenu.visible
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

    Timer {
        id: settle
        interval: pick.settleMs
        onTriggered: pick.picked(pick.choices[pick.current][0])
    }

    WheelHandler {
        enabled: pick.wheelPicks && pick.enabled && pick.choices.length > 1
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function (event) {
            // A notch is 120; away from you (positive) goes down the list.
            pick._wheel += event.angleDelta.y;
            var notches = Math.trunc(pick._wheel / 120);
            if (notches === 0) return;
            pick._wheel -= notches * 120;
            var now = Date.now();
            if (now - pick._lastStep < pick.stepMs) return;
            pick._lastStep = now;
            var next = Math.max(0, Math.min(pick.choices.length - 1, pick.current + (notches > 0 ? 1 : -1)));
            if (next === pick.current) return;
            pick.current = next;
            settle.restart();
        }
    }

    QQC2.Menu {
        id: pickMenu
        y: -implicitHeight
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent
        Instantiator {
            model: pick.choices
            delegate: QQC2.MenuItem {
                required property var modelData
                required property int index
                text: modelData[1]
                checkable: true
                checked: index === pick.current
                onTriggered: {
                    settle.stop();
                    pick.current = index;
                    // A click unchecks a checked item: the mark stays where the value is.
                    checked = Qt.binding(function () { return index === pick.current; });
                    pick.picked(modelData[0]);
                }
            }
            onObjectAdded: function (i, o) { pickMenu.insertItem(i, o); }
            onObjectRemoved: function (i, o) { pickMenu.removeItem(o); }
        }
    }
}
