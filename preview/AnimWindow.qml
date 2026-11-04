import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Effects
import QtWebEngine
import org.kde.kirigami as Kirigami

// Test window of the temperature animation (qml AnimWindow.qml): the radar page of the
// animations worktree, and the time bar the Animations tab would have,
// in QML like the radar's. The page does the pictures (window.anim*);
// this bar reads window.animState() a few times a second.
QQC2.ApplicationWindow {
    id: root
    visible: true
    width: Qt.application.arguments.indexOf("--narrow") >= 0 ? 600 : 1050
    height: 720
    title: "Animations (test)"
    color: Kirigami.Theme.backgroundColor

    property var state: null          // window.animState()
    property bool started: false
    property bool ctrlDown: false     // Ctrl held: readout under the pointer, cross cursor
    readonly property int count: state ? state.times.length : 0
    readonly property int readyCount: state ? state.ready.filter(function (r) { return r; }).length : 0

    // The time shown, between two frames while playing, and how far from now.
    function timeText() {
        return state && state.time !== null ? new Date(state.time).toLocaleString(Qt.locale(), "dddd d MMMM, HH:mm") : "…";
    }
    function fromNowText() {
        if (!state || state.time === null) return "";
        var h = Math.round((state.time - state.times[state.now]) / 3600000);
        return h === 0 ? "now" : (h > 0 ? "+" + h + " h" : h + " h");
    }
    function js(code) { web.runJavaScript(code); }

    // The box of the time over the map keeps one width: that of the longest
    // date of the range, and of the longest offset from now. frameTimes
    // changes with the range only (state is new ten times a second).
    property var frameTimes: []
    FontMetrics { id: timeMetrics; font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1; font.bold: true }
    FontMetrics { id: fromNowMetrics; font: Kirigami.Theme.defaultFont }
    readonly property real timeWidth: Math.ceil(Math.max.apply(null, [0].concat(frameTimes.map(function (t) {
        return timeMetrics.advanceWidth(new Date(t).toLocaleString(Qt.locale(), "dddd d MMMM, ") + "00:00");
    })))) + 2
    readonly property real fromNowWidth: Math.ceil(Math.max(fromNowMetrics.advanceWidth("now"),
        fromNowMetrics.advanceWidth("-" + pastH + " h"), fromNowMetrics.advanceWidth("+" + futureH + " h"))) + 2
    // The page switches and says where it stands: the last reading may be a
    // tenth of a second old.
    function toggle() {
        web.runJavaScript("window.animToggle()", function (playing) {
            if (root.state) root.state = Object.assign({}, root.state, { playing: playing });
        });
    }

    // Space plays or pauses, the arrows step one hour, Page Up and Page Down
    // (or Ctrl and an arrow, for keyboards where they need Fn) go to the
    // previous or next picture from the forecast file. Shortcuts
    // come before the map and the slider, which would take the keys too.
    Shortcut { sequence: "Space"; enabled: root.started; onActivated: root.toggle() }
    Shortcut { sequence: "Left"; enabled: root.started; onActivated: root.js("window.animStep(-1)") }
    Shortcut { sequence: "Right"; enabled: root.started; onActivated: root.js("window.animStep(1)") }
    Shortcut { sequences: [StandardKey.MoveToPreviousPage, "Ctrl+Left"]; enabled: root.started; onActivated: root.js("window.animStepFile(-1)") }
    // Esc closes the help wherever the keyboard is (the map, the bar).
    Shortcut { sequence: "Escape"; enabled: helpPanel.opened; onActivated: helpPanel.close() }
    Shortcut { sequences: [StandardKey.MoveToNextPage, "Ctrl+Right"]; enabled: root.started; onActivated: root.js("window.animStepFile(1)") }

    // PickButton: PickButton.qml, next to this file.

    // One choice of a setting in a menu: root[key] = value, then the page's call.
    property int maxFps: 8
    property int resolution: 1
    // Coasts and borders over the color layers (the page's own default: on).
    property bool mapLines: true
    component MenuPick: QQC2.MenuItem {
        property string key
        property int value
        property string call
        checkable: true
        checked: root[key] === value
        onTriggered: {
            root[key] = value;
            checked = Qt.binding(function () { return root[key] === value; });
            root.js("window." + call + "(" + value + ")");
        }
    }

    // A layer of the animation switched on or off, like the toggles of the
    // radar's bar: the widget's weather icon, dimmed while off. A colored
    // layer takes its opacity from the wheel over its button while it is on
    // (5 % a notch, 10 to 100 %), shown by the line under the icon.
    readonly property string iconsDir: Qt.resolvedUrl("../contents/icons/flat-color/22/")
    // Light theme (as the widget tells it): the pale weather icons are drawn
    // a little darker, and the ones off are dimmed less.
    readonly property bool isDark: {
        var c = Kirigami.Theme.backgroundColor;
        return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) < 0.5;
    }
    property var layersOn: ({ temperature: true, wind: true, pressure: false, isobars: false, airquality: false, precipitation: false, clouds: false, humidity: false, dewpoint: false })
    property int tempOpacity: {
        var a = Qt.application.arguments.filter(function (s) { return s.indexOf("--temp-opacity=") === 0; });
        return a.length ? parseInt(a[0].slice(15)) : 45;
    }
    property int presOpacity: 60
    property int aqOpacity: 60
    property int precipOpacity: 80
    property int cloudOpacity: 70
    property int humidityOpacity: 60   // humidity-spike.js
    property int dewOpacity: 60
    // The wind levels of the wind level spike (wind-level-spike.js), as window.windLevels() gives them.
    readonly property var windLevelChoices: [["10m", "10 m"], ["700hPa", "700 hPa"]]
    // The cloud levels of the clouds spike (clouds-spike.js), as window.cloudLevels() gives them.
    readonly property var cloudChoices: [["high", "High"], ["mid", "Mid"], ["low", "Low"]]
    // The kinds of the precipitation spike (precip-spike.js), as window.precipKinds() gives them.
    readonly property var precipChoices: [["rain", "Rain"], ["snow", "Snow"], ["wet_snow", "Wet snow"], ["mix", "Rain and snow"], ["freezing_rain", "Freezing rain"], ["freezing_drizzle", "Freezing drizzle"], ["ice_pellets", "Ice pellets"]]
    // The pollutants of the air quality spike (aq-spike.js), as window.aqPollutants() gives them.
    readonly property var aqChoices: [["pm2_5", "PM2.5"], ["pm10", "PM10"], ["ozone", "O₃"], ["nitrogen_dioxide", "NO₂"], ["sulphur_dioxide", "SO₂"], ["dust", "Dust"], ["aerosol_optical_depth", "AOD"], ["uv_index", "UV"]]
    component LayerToggle: QQC2.ToolButton {
        id: layerToggle
        property string layerId
        property string iconFile           // in iconsDir, or a file: URL
        property string title
        property string opacityKey: ""     // root property holding the percent
        property string opacityCall: ""    // page function taking it
        readonly property bool hasOpacity: opacityKey !== ""
        readonly property int opacityValue: hasOpacity ? root[opacityKey] : 100
        property real _wheel: 0
        checkable: true
        checked: root.state && root.state.layers ? !!root.state.layers[layerId] : !!root.layersOn[layerId]
        focusPolicy: Qt.NoFocus
        implicitWidth: 30
        implicitHeight: 26
        contentItem: Item {
            opacity: layerToggle.checked ? 1.0 : root.isDark ? 0.35 : 0.7
            Kirigami.Icon {
                id: toggleIcon
                anchors.centerIn: parent
                layer.enabled: !root.isDark
                layer.effect: MultiEffect { brightness: -0.3 }
                implicitWidth: 26
                implicitHeight: 26
                roundToIconSize: false
                source: layerToggle.iconFile.indexOf("file:") === 0 ? layerToggle.iconFile : root.iconsDir + layerToggle.iconFile
            }
        }
        Rectangle {
            visible: layerToggle.hasOpacity && layerToggle.checked
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 3
            width: (parent.width - 6) * layerToggle.opacityValue / 100
            height: 2
            radius: 1
            color: Kirigami.Theme.highlightColor
        }
        WheelHandler {
            enabled: layerToggle.hasOpacity && layerToggle.checked
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function (event) {
                // A notch is 120 (toward you: more opaque); a touchpad sends small steps, added up.
                layerToggle._wheel -= event.angleDelta.y;
                var notches = Math.trunc(layerToggle._wheel / 120);
                if (notches === 0) return;
                layerToggle._wheel -= notches * 120;
                var v = Math.max(10, Math.min(100, root[layerToggle.opacityKey] + notches * 5));
                if (v === root[layerToggle.opacityKey]) return;
                root[layerToggle.opacityKey] = v;
                root.js("window." + layerToggle.opacityCall + "(" + v + ")");
            }
        }
        onToggled: {
            root.layersOn[layerId] = checked;
            root.js("window.animSetLayer('" + layerId + "', " + checked + ")");
        }
        // The title, the opacity, then how to change it, smaller.
        QQC2.ToolTip.text: hasOpacity && checked ? "<b>" + title + "</b><br>Opacity: " + opacityValue + " %<br><i><span style=\"font-size:" + Math.round(Kirigami.Theme.defaultFont.pointSize * 0.8 * 10) / 10 + "pt\">(wheel)</span></i>" : title
        QQC2.ToolTip.visible: hovered
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
    }

    // Buttons that go together (a layer and its options), in a light frame
    // of their own, so the bar reads as groups.
    // A group with a layer on gets an edge in the highlight color.
    component LayerGroup: Rectangle {
        default property alias content: groupRow.data
        readonly property bool active: {
            for (var i = 0; i < groupRow.children.length; i++) {
                var c = groupRow.children[i];
                if (c.layerId !== undefined && c.checked) return true;
            }
            return false;
        }
        implicitWidth: groupRow.implicitWidth + 4
        implicitHeight: groupRow.implicitHeight + 4
        radius: 5
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06)
        border.width: 1
        border.color: active ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
        RowLayout {
            id: groupRow
            anchors.centerIn: parent
            spacing: 0
        }
    }

    // A step button: a theme icon, with a green bar beside it for the steps
    // to a picture from the forecast file (the theme has no >>| icon).
    component StepButton: QQC2.ToolButton {
        id: stepButton
        property string iconName
        property int bar: 0            // -1 bar on the left, 1 on the right, 0 none
        property string tip
        enabled: root.count > 0
        focusPolicy: Qt.NoFocus
        // The icon and its green bar, one block in the middle of the button.
        contentItem: Item {
            implicitWidth: stepRow.implicitWidth
            implicitHeight: stepRow.implicitHeight
            Row {
                id: stepRow
                anchors.centerIn: parent
                spacing: 2
                layoutDirection: stepButton.bar < 0 ? Qt.RightToLeft : Qt.LeftToRight
                Kirigami.Icon {
                    id: stepIcon
                    width: Kirigami.Units.iconSizes.smallMedium
                    height: width
                    source: stepButton.iconName
                    opacity: stepButton.enabled ? 1 : 0.4
                }
                Rectangle {
                    visible: stepButton.bar !== 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: stepIcon.height * 0.6
                    radius: 1
                    color: Kirigami.Theme.positiveTextColor
                    opacity: stepIcon.opacity
                }
            }
        }
        QQC2.ToolTip.text: tip
        QQC2.ToolTip.visible: hovered
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
    }

    // Hours before and after now, every 3 h: the files are kept about 8 days
    // back, and every run reaches 6 days ahead.
    readonly property var pastChoices: [[12, "12 h"], [24, "1 d"], [48, "2 d"], [72, "3 d"], [120, "5 d"], [192, "8 d"]]
    readonly property var futureChoices: [[12, "12 h"], [24, "1 d"], [48, "2 d"], [72, "3 d"], [96, "4 d"], [144, "6 d"]]
    property int pastH: 24
    property int futureH: 48
    function setRange() { js("window.animSetRange(" + pastH + ", " + futureH + ")"); }

    ColumnLayout {
        id: keyCatcher
        anchors.fill: parent
        spacing: 0
        // Ctrl while the keyboard is on the QML side: the page gets no key
        // then, so tell it (the readout under the pointer, and its cross).
        focus: true
        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Control && !event.isAutoRepeat) {
                root.ctrlDown = true;
                root.js("if (window.setReadout) window.setReadout(true)");
            }
        }
        Keys.onReleased: function (event) {
            if (event.key === Qt.Key_Control && !event.isAutoRepeat) {
                root.ctrlDown = false;
                root.js("if (window.setReadout) window.setReadout(false)");
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

        // A storage of its own on disk, like the widget's MapWebProfile.qml
        // (Qt 6's default profile keeps nothing): the pictures kept in
        // IndexedDB survive a restart of the window.
        WebEngineProfilePrototype {
            id: testProfile
            storageName: "aww-anim-preview"
            httpCacheMaximumSize: 150 * 1024 * 1024
        }

        WebEngineView {
            id: web
            anchors.fill: parent
            // The profile first, then the page: QtWebEngine keeps the profile
            // of the first load (the widget does the same).
            Component.onCompleted: {
                web.profile = testProfile.instance();
                web.url = Qt.resolvedUrl("launch.html");
            }
            // Same settings as the widget's RadarWebEngineViewLibreWXR.qml.
            settings.javascriptEnabled: true
            settings.localContentCanAccessRemoteUrls: true
            settings.localContentCanAccessFileUrls: true
            onJavaScriptConsoleMessage: function (level, message, lineNumber, sourceID) {
                // Ctrl seen by the page (the map has the keyboard): the cross.
                // Esc in the page (the map has the keyboard): the help goes.
                if (message === "[keys] escape") {
                    if (helpPanel.opened) helpPanel.close();
                    return;
                }
                if (message.indexOf("[readout] ctrl:") === 0) {
                    root.ctrlDown = message.slice(15) === "1";
                    return;
                }
                console.log("[page] " + message);
            }
            onLoadingChanged: function (info) {
                if (info.status === WebEngineView.LoadSucceededStatus && web.url.toString().indexOf("anim-test") >= 0)
                    startTimer.start();
            }
        }

        // The cross while Ctrl is held, set by Qt at once: Chromium would only
        // change its own cursor at the next mouse move. A hover handler takes
        // no event from the map. Off while Ctrl is up: unsetting its cursor
        // instead left an arrow over the map, and the map's hand never came back.
        Item {
            anchors.fill: web
            HoverHandler {
                enabled: root.ctrlDown
                cursorShape: Qt.CrossCursor
                // Meanwhile the page gets no moves: the readout follows from here.
                onPointChanged: if (enabled) root.js("if (window.readoutAt) window.readoutAt(" + point.position.x + ", " + point.position.y + ")")
            }
        }

        // The time shown, over the map under the legend; the dot as the handle:
        // green from the forecast file, orange worked out.
        Rectangle {
            visible: root.state !== null && root.state.time !== null
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Kirigami.Units.gridUnit * 3.2
            width: overlayRow.implicitWidth + Kirigami.Units.largeSpacing * 2
            height: overlayRow.implicitHeight + Kirigami.Units.smallSpacing * 2 + 4   // 4 px more at the bottom: the progress line
            radius: Kirigami.Units.cornerRadius
            color: Qt.rgba(0x29 / 255, 0x31 / 255, 0x25 / 255, 0.9)   // #293125, his pick
            RowLayout {
                id: overlayRow
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -2
                spacing: Kirigami.Units.smallSpacing * 2
                Rectangle {
                    width: Kirigami.Units.smallSpacing * 2.5
                    height: width
                    radius: width / 2
                    color: root.state && root.state.fromFile ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.neutralTextColor
                }
                QQC2.Label {
                    Layout.preferredWidth: root.timeWidth
                    text: root.timeText()
                    color: "white"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                    font.bold: true
                }
                QQC2.Label {
                    Layout.preferredWidth: root.fromNowWidth
                    text: root.fromNowText()
                    color: "white"
                    opacity: 0.75
                }
            }
            // How far into the range the picture shown is, as the line under
            // a layer's icon shows its opacity, at the bottom of the box.
            Rectangle {
                readonly property real done: root.count > 1 && root.state.index >= 0 ? Math.min(1, root.state.index / (root.count - 1)) : 0
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1
                anchors.left: parent.left
                anchors.leftMargin: parent.radius
                width: (parent.width - 2 * parent.radius) * done
                height: 3
                radius: 1.5
                color: Kirigami.Theme.highlightColor
            }
        }
        }

        // The map comes a little after the page: ask until it takes.
        Timer {
            id: startTimer
            interval: 500
            repeat: true
            onTriggered: web.runJavaScript("window.animStart ? window.animStart(" + root.pastH + ", " + root.futureH + ", " + JSON.stringify(root.layersOn) + ") : false", function (ok) {
                if (ok) { root.started = true; startTimer.stop(); root.js("window.animSetStep(1500); window.setTempStep(2.5)"); }
            })
        }

        Timer {
            interval: 100
            repeat: true
            running: root.started
            onTriggered: web.runJavaScript("JSON.stringify(window.animState())", function (s) {
                if (!s) return;
                root.state = JSON.parse(s);
                var t = root.state.times;
                if (t.length !== root.frameTimes.length || t[0] !== root.frameTimes[0]) root.frameTimes = t;
            })
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            // Steps, paused: to the previous or next picture from the forecast
            // file (green handle), or one hour (often a worked-out one).
            StepButton {
                iconName: "media-seek-backward"
                bar: -1
                tip: "Previous picture from the forecast file (Page Up, Ctrl+Left)"
                onClicked: root.js("window.animStepFile(-1)")
            }
            StepButton {
                iconName: "media-skip-backward"
                tip: "One hour back (Left)"
                onClicked: root.js("window.animStep(-1)")
            }

            StepButton {
                iconName: root.state && root.state.playing ? "media-playback-pause" : "media-playback-start"
                enabled: root.readyCount > 1
                tip: "Play or pause (Space)"
                onClicked: root.toggle()
            }

            StepButton {
                iconName: "media-skip-forward"
                tip: "One hour ahead (Right)"
                onClicked: root.js("window.animStep(1)")
            }
            StepButton {
                iconName: "media-seek-forward"
                bar: 1
                tip: "Next picture from the forecast file (Page Down, Ctrl+Right)"
                onClicked: root.js("window.animStepFile(1)")
            }

            // Speed, one click to the next: 3 hours of weather in 1.5 s, 0.75 s, 0.5 s.
            QQC2.ToolButton {
                property int speed: 1
                focusPolicy: Qt.NoFocus
                text: speed + "x"
                font.bold: true
                onClicked: {
                    speed = speed % 3 + 1;
                    root.js("window.animSetStep(" + Math.round(1500 / speed) + ")");
                }
                QQC2.ToolTip.text: "Speed"
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }

            Item {
                Layout.fillWidth: true
                // As much room above the slider as the ticks take below it:
                // the track lines up with the buttons beside it (4 px more
                // above: measured, the icons and the speed sit 2 px lower).
                implicitHeight: slider.implicitHeight + 2 * ticks.height + 4

                QQC2.Slider {
                    id: slider
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: ticks.height + 4
                    from: 0
                    to: Math.max(1, root.count - 1)
                    stepSize: 1
                    snapMode: QQC2.Slider.SnapOnRelease
                    focusPolicy: Qt.NoFocus
                    enabled: root.count > 0
                    // The page's position, except while the hand is on it.
                    Binding on value {
                        when: !slider.pressed
                        value: root.state && root.state.index >= 0 ? root.state.index : (root.state ? root.state.now : 0)
                        restoreMode: Binding.RestoreNone
                    }
                    property int sent: -1          // the last frame asked for while dragging
                    // Green on a frame as read from its file, orange on one
                    // worked out between two.
                    handle: Rectangle {
                        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                        y: slider.topPadding + (slider.availableHeight - height) / 2
                        implicitWidth: Kirigami.Units.gridUnit
                        implicitHeight: Kirigami.Units.gridUnit
                        radius: width / 2
                        color: root.state && root.state.fromFile ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.neutralTextColor
                        border.color: Qt.darker(color, slider.pressed ? 1.6 : 1.3)
                        border.width: 1
                    }
                    onPressedChanged: {
                        if (pressed) { sent = -1; root.js("window.animPlay(false)"); }
                    }
                    // One call per new frame only: the mouse moves far more
                    // often than the frame under it changes.
                    onMoved: {
                        var i = Math.round(value);
                        if (i === sent) return;
                        sent = i;
                        root.js("window.animShow(" + i + ")");
                    }
                }

                // One mark per picture: lit once read, red when it failed;
                // longer at midnight, longest and in the text color for now.
                Row {
                    id: ticks
                    anchors.top: slider.bottom
                    x: slider.leftPadding + slider.handle.width / 2 - width / Math.max(1, root.count) / 2
                    width: slider.availableWidth - slider.handle.width + slider.availableWidth / Math.max(1, root.count)
                    height: 10
                    Repeater {
                        model: root.count
                        Item {
                            width: ticks.width / root.count
                            height: ticks.height
                            readonly property bool midnight: new Date(root.state.times[index]).getHours() < 3
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.max(1, Math.min(3, parent.width - 1))
                                height: index === root.state.now ? 10 : parent.midnight ? 8 : 4
                                radius: width > 2 ? 1 : 0
                                color: index === root.state.now ? Kirigami.Theme.textColor
                                     : root.state.failed[index] ? Kirigami.Theme.negativeTextColor
                                     : root.state.ready[index] ? Kirigami.Theme.highlightColor
                                     : Kirigami.Theme.disabledTextColor
                            }
                        }
                    }
                }
            }

            // Round again from the start at the end (loop-spike.js), or stop there.
            QQC2.ToolButton {
                icon.name: "media-repeat-all"
                checkable: true
                checked: !root.state || root.state.loop !== false
                focusPolicy: Qt.NoFocus
                enabled: root.count > 0
                onToggled: root.js("window.animSetLoop(" + checked + ")")
                QQC2.ToolTip.text: checked ? "Loop: on" : "Loop: off, stops at the end"
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            LayerGroup {
                LayerToggle {
                    id: windToggle
                    layerId: "wind"
                    iconFile: "wi-strong-wind.svg"
                    title: "Wind"
                }
                PickButton {
                    enabled: windToggle.checked
                    implicitHeight: 26
                    choices: root.windLevelChoices
                    current: 0
                    wheelPicks: true
                    tip: "Height of the wind"
                    onPicked: function (id) { root.js("window.windSetLevel('" + id + "')"); }
                }
            }
            LayerGroup {
                LayerToggle {
                    layerId: "temperature"
                    iconFile: "wi-thermometer.svg"
                    title: "Temperature"
                    opacityKey: "tempOpacity"
                    opacityCall: "setTempOpacity"
                }
            }
            LayerGroup {
                LayerToggle {
                    id: precipToggle
                    layerId: "precipitation"
                    iconFile: "wi-rain.svg"
                    title: "Precipitation (rain, snow)"
                    opacityKey: "precipOpacity"
                    opacityCall: "precipSetOpacity"
                }
                KindsButton {
                    enabled: precipToggle.checked
                    implicitHeight: 26
                    choices: root.precipChoices
                    tip: "Kinds of precipitation shown"
                    onPicked: function (values) { root.js("window.precipSetKinds(" + JSON.stringify(values) + ")"); }
                }
            }
            LayerGroup {
                LayerToggle {
                    id: cloudToggle
                    layerId: "clouds"
                    iconFile: "wi-cloudy.svg"
                    title: "Cloud cover"
                    opacityKey: "cloudOpacity"
                    opacityCall: "cloudSetOpacity"
                }
                KindsButton {
                    enabled: cloudToggle.checked
                    implicitHeight: 26
                    choices: root.cloudChoices
                    tip: "Cloud levels shown"
                    onPicked: function (values) { root.js("window.cloudSetLevels(" + JSON.stringify(values) + ")"); }
                }
            }
            LayerGroup {
                LayerToggle {
                    layerId: "pressure"
                    iconFile: "wi-barometer.svg"
                    title: "Sea level pressure (colors)"
                    opacityKey: "presOpacity"
                    opacityCall: "presSetOpacity"
                }
                LayerToggle {
                    layerId: "isobars"
                    iconFile: Qt.resolvedUrl("wi-isobars.svg")
                    title: "Isobars"
                }
            }
            LayerGroup {
                LayerToggle {
                    layerId: "humidity"
                    iconFile: "wi-humidity.svg"
                    title: "Relative humidity"
                    opacityKey: "humidityOpacity"
                    opacityCall: "humiditySetOpacity"
                }
            }
            LayerGroup {
                LayerToggle {
                    layerId: "dewpoint"
                    iconFile: "wi-dew-point.svg"
                    title: "Dew point"
                    opacityKey: "dewOpacity"
                    opacityCall: "dewpointSetOpacity"
                }
            }
            LayerGroup {
                LayerToggle {
                    id: aqToggle
                    layerId: "airquality"
                    iconFile: "wi-smoke.svg"
                    title: "Air quality (CAMS)"
                    opacityKey: "aqOpacity"
                    opacityCall: "aqSetOpacity"
                }
                // Always there, greyed while the layer is off: it belongs to it.
                PickButton {
                    enabled: aqToggle.checked
                    implicitHeight: 26
                    choices: root.aqChoices
                    current: 0
                    wheelPicks: true
                    tip: "Pollutant shown"
                    onPicked: function (id) { root.js("window.aqSetPollutant('" + id + "')"); }
                }
            }

            QQC2.Label {
                Layout.leftMargin: Kirigami.Units.largeSpacing
                opacity: 0.7
                text: root.readyCount + "/" + root.count + " at " + root.maxFps + " fps"
                HoverHandler { id: countHover }
                QQC2.ToolTip.text: "Pictures loaded / pictures in the range, one every 3 hours<br>Pictures per second at most, set in the settings menu"
                QQC2.ToolTip.visible: countHover.hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }

            Item { Layout.fillWidth: true }

            // How far back and how far ahead, each a button that opens its list.
            PickButton {
                prefix: "\u2212"
                choices: root.pastChoices
                current: 1
                tip: "How far back"
                onPicked: function (h) { root.pastH = h; root.setRange(); }
            }
            PickButton {
                prefix: "+"
                choices: root.futureChoices
                current: 2
                tip: "How far ahead"
                onPicked: function (h) { root.futureH = h; root.setRange(); }
            }
            // How to read the layers: a panel sliding in from the right (HelpPanel.qml).
            QQC2.ToolButton {
                text: "?"
                font.bold: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                focusPolicy: Qt.NoFocus
                checkable: true
                checked: helpPanel.opened
                onClicked: helpPanel.opened ? helpPanel.close() : helpPanel.open()
                QQC2.ToolTip.text: "How to read the animations"
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
            // The rest, set once: pictures per second at most, and the
            // resolution of the map while it plays (full again on pause).
            QQC2.ToolButton {
                icon.name: "configure"
                focusPolicy: Qt.NoFocus
                onClicked: settingsMenu.visible ? settingsMenu.close() : settingsMenu.open()
                QQC2.ToolTip.text: "Pictures per second, resolution while playing, coasts and borders"
                QQC2.ToolTip.visible: hovered && !settingsMenu.visible
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                QQC2.Menu {
                    id: settingsMenu
                    y: -implicitHeight
                    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent
                    QQC2.MenuItem { text: "Pictures per second"; enabled: false }
                    MenuPick { text: "4"; key: "maxFps"; value: 4; call: "animSetMaxFps" }
                    MenuPick { text: "8"; key: "maxFps"; value: 8; call: "animSetMaxFps" }
                    MenuPick { text: "15"; key: "maxFps"; value: 15; call: "animSetMaxFps" }
                    QQC2.MenuSeparator {}
                    QQC2.MenuItem { text: "Resolution while playing"; enabled: false }
                    MenuPick { text: "Full"; key: "resolution"; value: 1; call: "animSetResolution" }
                    MenuPick { text: "Half"; key: "resolution"; value: 2; call: "animSetResolution" }
                    MenuPick { text: "Quarter"; key: "resolution"; value: 4; call: "animSetResolution" }
                    QQC2.MenuSeparator {}
                    QQC2.MenuItem {
                        text: "Coasts and borders"
                        checkable: true
                        checked: root.mapLines
                        onTriggered: {
                            root.mapLines = !root.mapLines;
                            checked = Qt.binding(function () { return root.mapLines; });
                            root.js("window.setMapLines(" + root.mapLines + ")");
                        }
                    }
                }
            }
        }
    }
    HelpPanel {
        id: helpPanel
        iconsDir: root.iconsDir
        // The choices of each layer's list, at the end of its chapter.
        choices: ({ wind: root.windLevelChoices, precipitation: root.precipChoices, clouds: root.cloudChoices, airquality: root.aqChoices })
        layers: root.state && root.state.layers ? root.state.layers : root.layersOn
        // EXTRA=--help-open ./run-anim.sh: open from the start (for captures).
        Component.onCompleted: if (Qt.application.arguments.indexOf("--help-open") >= 0) open()
    }
}
