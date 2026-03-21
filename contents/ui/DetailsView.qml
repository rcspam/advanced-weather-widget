/**
 * DetailsView.qml — Dynamic "Details" tab content for the popup
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

import "js/weather.js" as W
import "js/moonphase.js" as Moon
import "js/moonpath.js" as MoonPath
import "js/sunpath.js" as SunPath
import "js/suncalc.js" as SC

Item {
    id: root
    property var weatherRoot

    // Helper: true if weatherRoot exists and has a valid (non-NaN) temperature
    readonly property bool hasData: weatherRoot && !isNaN(weatherRoot.temperatureC)

    // Implicit height based on content (ScrollView's contentHeight) or empty label
    implicitHeight: Math.max(hasData ? detailsScroll.contentHeight : (emptyLabel.implicitHeight + 40), 50)

    // Font for weather icons
    FontLoader {
        id: wiFont
        source: Qt.resolvedUrl("../fonts/weathericons-regular-webfont.ttf")
    }

    // ── Icon size from configuration ──────────────────────────────────────
    readonly property int iconSize: Plasmoid.configuration.widgetIconSize || 16
    // Smaller glyph size for decorative indicators inside arc card info rows
    // (sunrise ↑↓ and moonrise ↑↓ above the time label). Proportional to
    // iconSize but capped so they fit inside the 44 px bottom row.
    readonly property int glyphIconSize: Math.max(12, Math.round(iconSize * 0.55))

    // ── Theme helper — true when KDE is using a dark colour scheme ────────
    readonly property bool isDark: Kirigami.Theme.textColor.r > 0.5

    // ── Colour palette — adapts to dark / light theme ─────────────────────
    readonly property color cardBg: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.07)
    readonly property color cardBorder: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.13)
    readonly property color valueColor: Kirigami.Theme.textColor

    // Accent colours — shift toward darker hues on light themes for contrast
    readonly property color accentBlue: isDark ? "#5ea8ff" : "#1a6fcc"
    readonly property color accentWarm: isDark ? "#ffb347" : "#b86000"
    readonly property color accentTeal: isDark ? "#4ecdc4" : "#007070"
    readonly property color accentGold: isDark ? "#ffcf63" : "#9c7400"
    readonly property color accentOrange: isDark ? "#ff8c52" : "#c04000"
    readonly property color accentViolet: isDark ? "#c4b4ff" : "#5030a0"

    // ── icon theme ────────────────────────────────────────────────────────
    readonly property string iconTheme: Plasmoid.configuration.widgetIconTheme || "kde"
    readonly property int iconSz: iconSize
    readonly property bool isList: (Plasmoid.configuration.widgetDetailsLayout || "cards2") === "list"
    readonly property string sunTimesMode: Plasmoid.configuration.widgetSunTimesMode || "both"
    readonly property string moonMode: Plasmoid.configuration.widgetMoonMode || "full"

    // Collapse state for the two arc cards.
    // Plain bool properties so QML change detection works reliably.
    // (var/object mutation does not trigger re-evaluation of bindings.)
    property bool _sunExpanded: true
    property bool _moonExpanded: true

    // Height of regular (non-arc) cards — used as collapsed height for arc cards
    // so they visually match feelslike/humidity/etc. when collapsed.
    readonly property int regularCardHeight: Plasmoid.configuration.widgetCardsHeightAuto ? 30   // same as autoHeight for regular cards (line 259)
    : (Plasmoid.configuration.widgetCardsHeight || 30)

    // SVG icon base — wi-font falls back to symbolic so sun/moon icons always resolve
    readonly property string svgBase: {
        var th = iconTheme;
        if (th === "wi-font")
            th = "symbolic";
        if (th === "kde")
            return "";
        return Qt.resolvedUrl("../icons/" + th + "/" + iconSize + "/wi-");
    }

    // Resolved SVG URL for non-kde/wi-font themes
    function svgIconUrl(filename) {
        if (iconTheme === "kde" || iconTheme === "wi-font")
            return "";
        return Qt.resolvedUrl("../icons/" + iconTheme + "/" + iconSize + "/" + filename);
    }

    // ── Lookup tables ─────────────────────────────────────────────────────
    function wiGlyph(id) {
        return ({
                feelslike: "\uF055",
                humidity: "\uF07A",
                pressure: "\uF079",
                wind: "\uF050",
                suntimes: "\uF051",
                dewpoint: "\uF078",
                visibility: "\uF0B6",
                moonphase: "\uF0D0",
                condition: "\uF013"
            })[id] || "\uF00D";
    }
    function wiFile(id) {
        return ({
                feelslike: "wi-thermometer.svg",
                humidity: "wi-humidity.svg",
                pressure: "wi-barometer.svg",
                wind: "wi-strong-wind.svg",
                suntimes: "wi-sunrise.svg",
                dewpoint: "wi-raindrop.svg",
                visibility: "wi-fog.svg",
                moonphase: "wi-night-clear.svg",
                condition: "wi-day-sunny.svg"
            })[id] || "wi-na.svg";
    }
    function kdeIcon(id) {
        return ({
                feelslike: "thermometer",
                humidity: "weather-humidity",
                pressure: "weather-pressure",
                wind: "weather-windy",
                suntimes: "weather-sunrise",
                dewpoint: "weather-dew-point",
                visibility: "weather-fog",
                moonphase: "weather-clear-night",
                condition: "weather-few-clouds"
            })[id] || "weather-none-available";
    }
    function accentFor(id) {
        return ({
                feelslike: root.accentWarm,
                humidity: root.accentBlue,
                pressure: root.accentTeal,
                wind: root.accentBlue,
                suntimes: root.accentGold,
                dewpoint: root.accentTeal,
                visibility: Kirigami.Theme.textColor,
                moonphase: root.accentViolet,
                condition: Kirigami.Theme.textColor
            })[id] || root.accentBlue;
    }
    function labelFor(id) {
        return ({
                feelslike: i18n("Feels Like"),
                humidity: i18n("Humidity"),
                pressure: i18n("Pressure"),
                wind: i18n("Wind"),
                suntimes: i18n("Sunrise/Sunset"),
                dewpoint: i18n("Dew Point"),
                visibility: i18n("Visibility"),
                moonphase: i18n("Moon Phase"),
                condition: i18n("Condition")
            })[id] || id;
    }
    function dataValue(id) {
        if (!weatherRoot)
            return "--";
        switch (id) {
        case "feelslike":
            return weatherRoot.tempValue(weatherRoot.apparentC);
        case "humidity":
            return isNaN(weatherRoot.humidityPercent) ? "--" : Math.round(weatherRoot.humidityPercent) + "%";
        case "pressure":
            return weatherRoot.pressureValue(weatherRoot.pressureHpa);
        case "dewpoint":
            return weatherRoot.tempValue(weatherRoot.dewPointC);
        case "visibility":
            return isNaN(weatherRoot.visibilityKm) ? "--" : weatherRoot.visibilityKm.toFixed(1) + " km";
        case "condition":
            return weatherRoot.weatherCodeToText(weatherRoot.weatherCode, weatherRoot.isNightTime());
        case "wind":
            // Wind is handled specially in the card
            return "";
        case "suntimes":
            // Handled in expanded card
            return "";
        case "moonphase":
            // Handled in expanded card
            return "";
        default:
            return "";
        }
    }

    // List of detail IDs in configured order
    property var detailIds: (Plasmoid.configuration.widgetDetailsOrder || "feelslike;humidity;pressure;wind;suntimes;dewpoint;visibility;moonphase").split(";").map(s => s.trim()).filter(s => s.length > 0)

    // Build rows: each row is an array of 1 or 2 IDs
    function buildRows() {
        var order = (Plasmoid.configuration.widgetDetailsOrder || "feelslike;humidity;pressure;wind;suntimes;dewpoint;visibility;moonphase").split(";").map(function (s) {
            return s.trim();
        }).filter(function (s) {
            return s.length > 0;
        });
        var rows = [];
        var i = 0;
        if (root.isList) {
            while (i < detailIds.length) {
                rows.push([detailIds[i]]);
                i++;
            }
        } else {
            while (i < detailIds.length) {
                if (i + 1 < detailIds.length) {
                    rows.push([detailIds[i], detailIds[i + 1]]);
                    i += 2;
                } else {
                    rows.push([detailIds[i]]);
                    i++;
                }
            }
        }
        return rows;
    }

    // ── empty state ───────────────────────────────────────────────────────
    Label {
        id: emptyLabel
        anchors.centerIn: parent
        visible: !root.hasData
        text: (weatherRoot && weatherRoot.loading) ? i18n("Loading details…") : i18n("No details data")
        color: Kirigami.Theme.textColor
        opacity: 0.4
        font: weatherRoot ? weatherRoot.wf(12, false) : Qt.font({})
    }

    // ── UI when data exists ───────────────────────────────────────────────
    ScrollView {
        id: detailsScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        visible: root.hasData

        Column {
            id: detailsColumn
            width: parent.width
            spacing: root.isList ? 0 : 8
            bottomPadding: 4

            Repeater {
                model: root.buildRows()

                delegate: RowLayout {
                    id: rowItem
                    required property var modelData   // array of 1 or 2 IDs
                    width: parent.width
                    spacing: root.isList ? 0 : 8

                    Repeater {
                        model: rowItem.modelData

                        delegate: Rectangle {
                            id: card
                            required property string modelData   // the detail ID

                            // Card height
                            readonly property bool isExpandedCard: card.modelData === "suntimes" || card.modelData === "moonphase"
                            // suntimes and moonphase both get the tall arc height
                            readonly property int autoHeight: {
                                if (card.modelData === "suntimes")
                                    return 165;
                                if (card.modelData === "moonphase")
                                    return 165;
                                if (isExpandedCard)
                                    return 80;
                                return 30;  // ← adjust this value to change regular card height
                            }
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            // List mode: compact fixed height; Cards mode: auto or manual
                            // Arc cards animate between expanded (arc view) and
                            // collapsed (compact header-only row, ~44 px).
                            readonly property bool _isArcExpanded: {
                                if (!card.isExpandedCard)
                                    return true;
                                if (card.modelData === "suntimes")
                                    return root._sunExpanded;
                                if (card.modelData === "moonphase")
                                    return root._moonExpanded;
                                return true;
                            }
                            Layout.preferredHeight: root.isList ? (card.isExpandedCard ? 44 : 38) : (card.isExpandedCard ? (card._isArcExpanded ? autoHeight : root.regularCardHeight) : (Plasmoid.configuration.widgetCardsHeightAuto ? autoHeight : Plasmoid.configuration.widgetCardsHeight))
                            Behavior on Layout.preferredHeight {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.InOutQuad
                                }
                            }
                            radius: root.isList ? 0 : 10
                            // List mode: no card background — just a flat row
                            color: root.isList ? "transparent" : root.cardBg
                            border.color: root.isList ? "transparent" : root.cardBorder
                            border.width: root.isList ? 0 : 1

                            // ── Separator line shown in list mode ─────────────────
                            Rectangle {
                                visible: root.isList
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                height: 1
                                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10)
                            }

                            // Standard item: single row
                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 10
                                    rightMargin: 10
                                }
                                spacing: 8
                                visible: !card.isExpandedCard && card.modelData !== "wind"

                                // Icon — uses existing theme-aware helpers
                                Item {
                                    visible: root.iconTheme === "wi-font" && wiFont.status === FontLoader.Ready
                                    implicitWidth: root.iconSize
                                    implicitHeight: root.iconSize
                                    Layout.alignment: Qt.AlignVCenter
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.wiGlyph(card.modelData)
                                        font.family: wiFont.font.family
                                        font.pixelSize: root.iconSize
                                        color: root.accentFor(card.modelData)
                                    }
                                }
                                Kirigami.Icon {
                                    visible: root.iconTheme === "kde"
                                    source: root.kdeIcon(card.modelData)
                                    implicitWidth: root.iconSize
                                    implicitHeight: root.iconSize
                                    color: root.accentFor(card.modelData)
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Kirigami.Icon {
                                    visible: root.iconTheme !== "kde" && root.iconTheme !== "wi-font"
                                    source: root.svgIconUrl(root.wiFile(card.modelData))
                                    isMask: root.iconTheme === "symbolic"
                                    color: root.iconTheme === "symbolic" ? Kirigami.Theme.textColor : "transparent"
                                    implicitWidth: root.iconSize
                                    implicitHeight: root.iconSize
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                // label (dim)
                                Label {
                                    text: root.labelFor(card.modelData) + ":"
                                    color: Kirigami.Theme.textColor
                                    opacity: 0.55
                                    font: weatherRoot ? weatherRoot.wf(11, false) : Qt.font({})
                                    elide: Text.ElideRight
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                // scalar value
                                Label {
                                    visible: card.modelData !== "wind"
                                    text: root.dataValue(card.modelData)
                                    color: root.valueColor
                                    font: weatherRoot ? weatherRoot.wf(13, true) : Qt.font({
                                        bold: true
                                    })
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            // Wind special (icon + speed + arrow)
                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 10
                                    rightMargin: 10
                                }
                                spacing: 8
                                visible: card.modelData === "wind"

                                // Icon — uses existing theme-aware helpers
                                Item {
                                    visible: root.iconTheme === "wi-font" && wiFont.status === FontLoader.Ready
                                    implicitWidth: root.iconSize
                                    implicitHeight: root.iconSize
                                    Layout.alignment: Qt.AlignVCenter
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.wiGlyph("wind")
                                        font.family: wiFont.font.family
                                        font.pixelSize: root.iconSize
                                        color: root.accentFor("wind")
                                    }
                                }
                                Kirigami.Icon {
                                    visible: root.iconTheme === "kde"
                                    source: root.kdeIcon("wind")
                                    implicitWidth: root.iconSize
                                    implicitHeight: root.iconSize
                                    color: root.accentFor("wind")
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Kirigami.Icon {
                                    visible: root.iconTheme !== "kde" && root.iconTheme !== "wi-font"
                                    source: root.svgIconUrl(root.wiFile("wind"))
                                    isMask: root.iconTheme === "symbolic"
                                    color: root.iconTheme === "symbolic" ? Kirigami.Theme.textColor : "transparent"
                                    implicitWidth: root.iconSize
                                    implicitHeight: root.iconSize
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Label {
                                    text: root.labelFor("wind") + ":"
                                    color: Kirigami.Theme.textColor
                                    opacity: 0.55
                                    font: weatherRoot ? weatherRoot.wf(11, false) : Qt.font({})
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                // Speed and arrow
                                RowLayout {
                                    visible: card.modelData === "wind"
                                    spacing: 6
                                    Label {
                                        text: weatherRoot ? weatherRoot.windValue(weatherRoot.windKmh) : "--"
                                        color: root.valueColor
                                        font: weatherRoot ? weatherRoot.wf(13, true) : Qt.font({
                                            bold: true
                                        })
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Item {
                                        visible: weatherRoot && !isNaN(weatherRoot.windDirection)
                                        implicitWidth: root.iconSize
                                        implicitHeight: root.iconSize
                                        Layout.alignment: Qt.AlignVCenter
                                        Text {
                                            anchors.centerIn: parent
                                            text: W.windDirectionGlyph(weatherRoot.windDirection)
                                            font.family: wiFont.status === FontLoader.Ready ? wiFont.font.family : ""
                                            font.pixelSize: root.iconSize
                                            color: Kirigami.Theme.textColor
                                        }
                                    }
                                }
                            } // RowLayout (standard)

                            // ═══════════════════════════════════════════════════════════════
                            // Suntimes — animated sun/moon arc card
                            //
                            // DAY:   sun travels left→noon→right   (warm gold palette)
                            // NIGHT: moon travels right→midnight→left  (cool blue palette)
                            //        stars appear; bottom row flips: sunset left, sunrise right
                            //
                            // ═════════════════════════════════════════════════════════════════
                            // Suntimes — animated sun/moon arc card
                            //
                            // DAY:   sun travels left→noon→right   (warm gold palette)
                            // NIGHT: moon travels right→midnight→left (cool pink/violet palette)
                            //        stars appear in sky; bottom row flips labels
                            //
                            // _isNight is driven by an explicit _updateProg() function — NOT
                            // a QML binding — because QML bindings only re-evaluate when their
                            // declared QML dependencies change.  new Date() inside a JS call is
                            // NOT a QML dependency, so a binding would freeze at the value it
                            // had when sunrise/sunset strings last changed, making night mode
                            // never trigger after the widget first loads with daytime data.
                            // ═════════════════════════════════════════════════════════════════
                            Item {
                                id: suntimesCard
                                anchors.fill: parent
                                clip: true
                                // Arc card hidden in list mode (compact row used instead)
                                visible: card.modelData === "suntimes" && !root.isList

                                // ── Collapse / expand header ──────────────────────────
                                // Styled like a standard item row so it blends when collapsed.
                                RowLayout {
                                    id: sunHeader
                                    visible: !card._isArcExpanded
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    // height=0 when expanded so canvas anchors to parent.top
                                    height: card._isArcExpanded ? 0 : root.regularCardHeight
                                    spacing: 8

                                    // Leading icon — sunrise or sunset depending on day/night
                                    // Kirigami.Icon {
                                    //     source: {
                                    //         var stem = suntimesCard._isNight ? "sunset" : "sunrise";
                                    //         return root.svgBase.length > 0
                                    //             ? (root.svgBase + stem + ".svg")
                                    //             : Qt.resolvedUrl("../icons/symbolic/32/wi-" + stem + ".svg");
                                    //     }
                                    //     isMask: true
                                    //     color: root.accentFor("suntimes")
                                    //     implicitWidth: root.iconSize
                                    //     implicitHeight: root.iconSize
                                    //     Layout.alignment: Qt.AlignVCenter
                                    // }

                                    Kirigami.Icon {
                                        visible: root.iconTheme !== "kde" && root.iconTheme !== "wi-font"
                                        source: root.svgIconUrl(root.wiFile("suntimes"))
                                        isMask: root.iconTheme === "symbolic"
                                        color: root.iconTheme === "symbolic" ? Kirigami.Theme.textColor : "transparent"
                                        implicitWidth: root.iconSize
                                        implicitHeight: root.iconSize
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    // Dim label — matches standard row style
                                    Label {
                                        text: root.labelFor("suntimes") + ":"
                                        color: Kirigami.Theme.textColor
                                        opacity: 0.55
                                        font: root.weatherRoot ? root.weatherRoot.wf(11, false) : Qt.font({})
                                        elide: Text.ElideRight
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Item {
                                        Layout.fillWidth: true
                                    }
                                    // Bold value — sunrise / sunset times
                                    Label {
                                        text: {
                                            if (!root.weatherRoot) return "--";
                                            var m = root.sunTimesMode, r = root.weatherRoot;
                                            if (m === "sunrise") return r.formatTimeForDisplay(r.sunriseTimeText);
                                            if (m === "sunset")  return r.formatTimeForDisplay(r.sunsetTimeText);
                                            if (m === "upcoming") {
                                                var nowM = (new Date()).getHours()*60+(new Date()).getMinutes();
                                                var riseM = SunPath.parseMins(r.sunriseTimeText);
                                                var setM  = SunPath.parseMins(r.sunsetTimeText);
                                                if (riseM >= 0 && nowM < riseM) return r.formatTimeForDisplay(r.sunriseTimeText);
                                                if (setM  >= 0 && nowM < setM)  return r.formatTimeForDisplay(r.sunsetTimeText);
                                                return r.formatTimeForDisplay(r.sunriseTimeText);
                                            }
                                            return r.formatTimeForDisplay(r.sunriseTimeText) + " / " + r.formatTimeForDisplay(r.sunsetTimeText);
                                        }
                                        color: root.valueColor
                                        font: root.weatherRoot ? root.weatherRoot.wf(13, true) : Qt.font({
                                            bold: true
                                        })
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    // Chevron
                                    Kirigami.Icon {
                                        source: card._isArcExpanded ? "arrow-up" : "arrow-down"
                                        implicitWidth: 14
                                        implicitHeight: 14
                                        opacity: 0.45
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                }
                                // MouseArea must be a sibling of the RowLayout, not a child.
                                // Inside a RowLayout, anchors.fill is ignored so the area gets 0 size.
                                MouseArea {
                                    anchors.top: sunHeader.top
                                    anchors.left: sunHeader.left
                                    anchors.right: sunHeader.right
                                    height: sunHeader.height
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root._sunExpanded = !card._isArcExpanded;
                                    }
                                }

                                // ── Collapse button (expanded state only) ─────────
                                Item {
                                    visible: card._isArcExpanded
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.topMargin: 6
                                    anchors.rightMargin: 8
                                    width: 24
                                    height: 24
                                    Kirigami.Icon {
                                        anchors.fill: parent
                                        source: "arrow-up"
                                        opacity: 0.50
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root._sunExpanded = false
                                    }
                                }

                                // ── Day / night flag ──────────────────────────────────
                                // Use weatherRoot.isNightTime() which reads the API's own
                                // is_day field (0=night, 1=day).  This is correct for ANY
                                // location regardless of the machine's local timezone.
                                // All previous attempts computed this from sunrise/sunset vs
                                // new Date().getHours() — which is always machine-local time,
                                // not location-local time — and therefore always failed for
                                // users checking a location in a different timezone.
                                readonly property bool _isNight: root.weatherRoot ? root.weatherRoot.isNightTime() : false

                                // ── Arc position (_prog) ───────────────────────────────
                                // Uses UTC + location UTC-offset (from API) for reliable
                                // local-time computation in Qt's V4 engine.
                                // toLocaleTimeString/Intl with timeZone is NOT supported.
                                readonly property int _utcOffset: root.weatherRoot ? root.weatherRoot.locationUtcOffsetMins : 0
                                property real _prog: 0.5

                                // _now is updated every minute and on every weather refresh.
                                // The two centre Labels reference it so QML treats it as a
                                // dependency and re-evaluates their text: bindings automatically.
                                // Without this, SunPath helpers call new Date() internally which
                                // is NOT a QML property — bindings would freeze on first eval.
                                property int _now: 0
                                function _refreshNow() {
                                    _now = (new Date()).getTime(); // ms timestamp — just needs to change
                                }

                                function _updateProg() {
                                    _refreshNow();
                                    if (root.weatherRoot) {
                                        _prog = SunPath.sunProgress(root.weatherRoot.sunriseTimeText, root.weatherRoot.sunsetTimeText, suntimesCard._utcOffset);
                                    } else {
                                        _prog = 0.5;
                                    }
                                    sunCanvas.requestPaint();
                                }

                                Component.onCompleted: _updateProg()

                                Timer {
                                    interval: 60000
                                    running: suntimesCard.visible
                                    repeat: true
                                    triggeredOnStart: true
                                    onTriggered: suntimesCard._updateProg()
                                }

                                Connections {
                                    target: root.weatherRoot
                                    function onSunriseTimeTextChanged() {
                                        suntimesCard._updateProg();
                                    }
                                    function onSunsetTimeTextChanged() {
                                        suntimesCard._updateProg();
                                    }
                                    // Repaint when is_day flag changes
                                    function onIsDayChanged() {
                                        sunCanvas.requestPaint();
                                    }
                                    // Re-evaluate time labels on every weather refresh.
                                    // temperatureC changes on every provider response.
                                    function onTemperatureCChanged() {
                                        suntimesCard._updateProg();
                                    }
                                }

                                // ── Glow-pulse: 0→1→0 over 3 s, looping ──────────────
                                property real glowPulse: 0
                                SequentialAnimation on glowPulse {
                                    running: suntimesCard.visible
                                    loops: Animation.Infinite
                                    NumberAnimation {
                                        from: 0
                                        to: 1
                                        duration: 1500
                                        easing.type: Easing.InOutSine
                                    }
                                    NumberAnimation {
                                        from: 1
                                        to: 0
                                        duration: 1500
                                        easing.type: Easing.InOutSine
                                    }
                                }
                                onGlowPulseChanged: sunCanvas.requestPaint()

                                // ── Arc canvas ────────────────────────────────────────
                                Canvas {
                                    id: sunCanvas
                                    anchors.top: sunHeader.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: parent.height - sunHeader.height - 50
                                    antialiasing: true

                                    onPaint: {
                                        var ctx2d = getContext("2d");
                                        // _prog drives arc dot position (visual).
                                        // _isNight drives sun vs moon — from API is_day flag.
                                        SunPath.drawSunArc(ctx2d, width, height, suntimesCard._prog, root.isDark, suntimesCard.glowPulse, root.weatherRoot ? root.weatherRoot.sunriseTimeText : "--", root.weatherRoot ? root.weatherRoot.sunsetTimeText : "--", suntimesCard._utcOffset, suntimesCard._isNight);
                                    }
                                } // Canvas

                                // ── Night colour: soft pink/rose ──────────────────────
                                readonly property color _nightLeft: root.isDark ? "#f0a0c0" : "#c0406a"
                                readonly property color _nightRight: root.isDark ? "#c090f0" : "#8030b0"
                                readonly property color _nightCentre: root.isDark ? "#d8a0e0" : "#9040c0"

                                // ── Bottom info row ───────────────────────────────────
                                // DAY:   [↑ sunrise gold]  [day length / remaining]     [↓ sunset orange]
                                // NIGHT: [↓ sunset pink]   [night length / until dawn]  [↑ sunrise violet]
                                RowLayout {
                                    visible: card._isArcExpanded
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    anchors.bottomMargin: 6
                                    height: 44
                                    spacing: 4

                                    // ── Left column ───────────────────────────────────
                                    Column {
                                        spacing: 1
                                        Layout.alignment: Qt.AlignVCenter
                                        Kirigami.Icon {
                                            source: {
                                                var stem = suntimesCard._isNight ? "sunset" : "sunrise";
                                                return root.svgBase.length > 0 ? (root.svgBase + stem + ".svg") : Qt.resolvedUrl("../icons/symbolic/32/wi-" + stem + ".svg");
                                            }
                                            isMask: true
                                            color: suntimesCard._isNight ? suntimesCard._nightLeft : root.accentGold
                                            implicitWidth: root.glyphIconSize
                                            implicitHeight: root.glyphIconSize
                                        }
                                        Label {
                                            text: {
                                                if (!root.weatherRoot)
                                                    return "--";
                                                var t = suntimesCard._isNight ? root.weatherRoot.sunsetTimeText : root.weatherRoot.sunriseTimeText;
                                                return root.weatherRoot.formatTimeForDisplay(t);
                                            }
                                            color: suntimesCard._isNight ? suntimesCard._nightLeft : root.accentGold
                                            font: root.weatherRoot ? root.weatherRoot.wf(12, true) : Qt.font({
                                                bold: true
                                            })
                                        }
                                    }

                                    // ── Centre column ─────────────────────────────────
                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Layout.alignment: Qt.AlignVCenter

                                        Label {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            text: {
                                                void (suntimesCard._now); // reactive — re-evals every minute
                                                if (!root.weatherRoot)
                                                    return "--";
                                                if (suntimesCard._isNight) {
                                                    var nl = SunPath.nightLengthMins(root.weatherRoot.sunriseTimeText, root.weatherRoot.sunsetTimeText);
                                                    return i18n("Night") + ": " + SunPath.formatDuration(nl);
                                                }
                                                var dl = SunPath.dayLengthMins(root.weatherRoot.sunriseTimeText, root.weatherRoot.sunsetTimeText);
                                                return i18n("Day") + ": " + SunPath.formatDuration(dl);
                                            }
                                            color: Kirigami.Theme.textColor
                                            opacity: 0.65
                                            font: root.weatherRoot ? root.weatherRoot.wf(10, false) : Qt.font({})
                                            elide: Text.ElideRight
                                        }

                                        Label {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            text: {
                                                void (suntimesCard._now); // reactive — re-evals every minute
                                                if (!root.weatherRoot)
                                                    return "--";
                                                if (suntimesCard._isNight) {
                                                    var until = SunPath.minsUntilSunrise(root.weatherRoot.sunriseTimeText, root.weatherRoot.sunsetTimeText, suntimesCard._utcOffset);
                                                    var mp = SunPath.moonProgress(root.weatherRoot.sunriseTimeText, root.weatherRoot.sunsetTimeText, suntimesCard._utcOffset);
                                                    var phase = SunPath.nightPhaseLabel(mp, until);
                                                    if (phase === "approaching")
                                                        return i18n("Dawn approaching — ") + SunPath.formatDuration(until);
                                                    if (phase === "evening")
                                                        return i18n("Evening — ") + SunPath.formatDuration(until) + i18n(" until dawn");
                                                    if (phase === "midnight")
                                                        return i18n("Around midnight — ") + SunPath.formatDuration(until) + i18n(" until dawn");
                                                    return SunPath.formatDuration(until) + " " + i18n("until dawn");
                                                }
                                                var rem = SunPath.remainingMins(root.weatherRoot.sunriseTimeText, root.weatherRoot.sunsetTimeText, suntimesCard._utcOffset);
                                                return rem > 0 ? SunPath.formatDuration(rem) + " " + i18n("left") : i18n("Daylight over");
                                            }
                                            color: suntimesCard._isNight ? suntimesCard._nightCentre : root.accentOrange
                                            font: root.weatherRoot ? root.weatherRoot.wf(11, true) : Qt.font({
                                                bold: true
                                            })
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // ── Right column ──────────────────────────────────
                                    Column {
                                        spacing: 1
                                        Layout.alignment: Qt.AlignVCenter
                                        Kirigami.Icon {
                                            source: {
                                                var stem = suntimesCard._isNight ? "sunrise" : "sunset";
                                                return root.svgBase.length > 0 ? (root.svgBase + stem + ".svg") : Qt.resolvedUrl("../icons/symbolic/32/wi-" + stem + ".svg");
                                            }
                                            isMask: true
                                            color: suntimesCard._isNight ? suntimesCard._nightRight : root.accentOrange
                                            implicitWidth: root.glyphIconSize
                                            implicitHeight: root.glyphIconSize
                                            Layout.alignment: Qt.AlignRight
                                        }
                                        Label {
                                            text: {
                                                if (!root.weatherRoot)
                                                    return "--";
                                                var t = suntimesCard._isNight ? root.weatherRoot.sunriseTimeText : root.weatherRoot.sunsetTimeText;
                                                return root.weatherRoot.formatTimeForDisplay(t);
                                            }
                                            color: suntimesCard._isNight ? suntimesCard._nightRight : root.accentOrange
                                            font: root.weatherRoot ? root.weatherRoot.wf(12, true) : Qt.font({
                                                bold: true
                                            })
                                        }
                                    }
                                } // RowLayout (info row)

                            } // Item (suntimes)

                            // ── LIST MODE: compact sunrise/sunset row ─────────────
                            // Direct child of card Rectangle — never hidden by arc Item
                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 10
                                    rightMargin: 10
                                }
                                visible: card.modelData === "suntimes" && root.isList
                                spacing: 8

                                // Icon
                                Item {
                                    visible: root.iconTheme === "wi-font" && wiFont.status === FontLoader.Ready
                                    implicitWidth: root.iconSize
                                    implicitHeight: root.iconSize
                                    Layout.alignment: Qt.AlignVCenter
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.wiGlyph("suntimes")
                                        font.family: wiFont.font.family
                                        font.pixelSize: root.iconSize
                                        color: root.accentFor("suntimes")
                                    }
                                }
                                Kirigami.Icon {
                                    visible: root.iconTheme === "kde"
                                    source: root.kdeIcon("suntimes")
                                    implicitWidth: root.iconSize
                                    implicitHeight: root.iconSize
                                    color: root.accentFor("suntimes")
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Kirigami.Icon {
                                    visible: root.iconTheme !== "kde" && root.iconTheme !== "wi-font"
                                    source: root.svgIconUrl(root.wiFile("suntimes"))
                                    isMask: root.iconTheme === "symbolic"
                                    color: root.iconTheme === "symbolic" ? Kirigami.Theme.textColor : "transparent"
                                    implicitWidth: root.iconSize
                                    implicitHeight: root.iconSize
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Label {
                                    text: root.labelFor("suntimes") + ":"
                                    color: Kirigami.Theme.textColor
                                    opacity: 0.55
                                    font: weatherRoot ? weatherRoot.wf(11, false) : Qt.font({})
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                // Sunrise / Sunset — SVG icons
                                RowLayout {
                                    spacing: 6
                                    Layout.alignment: Qt.AlignVCenter
                                    Kirigami.Icon {
                                        source: root.svgBase.length > 0 ? (root.svgBase + "sunrise.svg") : "weather-sunrise"
                                        isMask: root.iconTheme !== "kde"
                                        color: root.accentGold
                                        implicitWidth: root.iconSize
                                        implicitHeight: root.iconSize
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Label {
                                        text: root.weatherRoot ? root.weatherRoot.formatTimeForDisplay(root.weatherRoot.sunriseTimeText) : "--"
                                        color: root.accentGold
                                        font: root.weatherRoot ? root.weatherRoot.wf(12, true) : Qt.font({
                                            bold: true
                                        })
                                    }
                                    Label {
                                        text: "/"
                                        color: Kirigami.Theme.textColor
                                        opacity: 0.30
                                        font: root.weatherRoot ? root.weatherRoot.wf(11, false) : Qt.font({})
                                    }
                                    Kirigami.Icon {
                                        source: root.svgBase.length > 0 ? (root.svgBase + "sunset.svg") : "weather-sunset"
                                        isMask: root.iconTheme !== "kde"
                                        color: root.accentOrange
                                        implicitWidth: root.iconSize
                                        implicitHeight: root.iconSize
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Label {
                                        text: root.weatherRoot ? root.weatherRoot.formatTimeForDisplay(root.weatherRoot.sunsetTimeText) : "--"
                                        color: root.accentOrange
                                        font: root.weatherRoot ? root.weatherRoot.wf(12, true) : Qt.font({
                                            bold: true
                                        })
                                    }
                                }
                            }

                            // ═══════════════════════════════════════════════════════════════
                            // Moon Phase — animated arc card
                            //
                            // The moon travels clockwise from left (moonrise) → top (transit)
                            // → right (moonset), exactly mirroring the sun arc architecture.
                            // The body is a phase-accurate crescent/full/new disc.
                            // Stars are always shown in the background.
                            // Bottom row: [↑ moonrise] [phase name · illumination%] [↓ moonset]
                            // ═══════════════════════════════════════════════════════════════
                            Item {
                                id: moonCard
                                anchors.fill: parent
                                clip: true
                                // Arc card hidden in list mode (compact row used instead)
                                visible: card.modelData === "moonphase" && !root.isList

                                // ── Collapse / expand header ──────────────────────────
                                RowLayout {
                                    id: moonHeader
                                    visible: !card._isArcExpanded
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    height: card._isArcExpanded ? 0 : root.regularCardHeight
                                    spacing: 8

                                    // Leading icon — phase-specific SVG
                                                   Kirigami.Icon {
                                    visible: root.iconTheme !== "kde" && root.iconTheme !== "wi-font"
                                    source: root.iconTheme === "kde"
                                        ? root.kdeIcon("moonphase")
                                        : (root.svgBase.length > 0
                                            ? (root.svgBase + Moon.moonPhaseSvgStem(Moon.moonAgeFromPhase(SC.getMoonIllumination(new Date()).phase)) + ".svg")
                                            : Qt.resolvedUrl("../icons/symbolic/32/wi-" + Moon.moonPhaseSvgStem(Moon.moonAgeFromPhase(SC.getMoonIllumination(new Date()).phase)) + ".svg"))
                                    isMask: root.iconTheme === "symbolic"
                                    color: root.iconTheme === "symbolic" ? Kirigami.Theme.textColor : "transparent"
                                    implicitWidth: root.iconSize
                                    implicitHeight: root.iconSize
                                    Layout.alignment: Qt.AlignVCenter
                                    }
                                    // Dim label
                                    Label {
                                        text: root.labelFor("moonphase") + ":"
                                        color: Kirigami.Theme.textColor
                                        opacity: 0.55
                                        font: root.weatherRoot ? root.weatherRoot.wf(11, false) : Qt.font({})
                                        elide: Text.ElideRight
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Item {
                                        Layout.fillWidth: true
                                    }
                                    Label {
                                        text: root.weatherRoot ? root.weatherRoot.moonPhaseLabel() : "--"
                                        color: root.accentViolet
                                        font: root.weatherRoot ? root.weatherRoot.wf(11, true) : Qt.font({
                                            bold: false
                                        })
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    // Chevron
                                    Kirigami.Icon {
                                        source: card._isArcExpanded ? "arrow-up" : "arrow-down"
                                        implicitWidth: 14
                                        implicitHeight: 14
                                        opacity: 0.45
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                }
                                MouseArea {
                                    anchors.top: moonHeader.top
                                    anchors.left: moonHeader.left
                                    anchors.right: moonHeader.right
                                    height: moonHeader.height
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root._moonExpanded = !card._isArcExpanded;
                                    }
                                }

                                // ── Collapse button (expanded state only) ─────────
                                Item {
                                    visible: card._isArcExpanded
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.topMargin: 6
                                    anchors.rightMargin: 8
                                    width: 24
                                    height: 24
                                    Kirigami.Icon {
                                        anchors.fill: parent
                                        source: "arrow-up"
                                        opacity: 0.50
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root._moonExpanded = false
                                    }
                                }

                                // ── Location UTC offset ───────────────────────────────
                                readonly property int _utcOffset: root.weatherRoot ? root.weatherRoot.locationUtcOffsetMins : 0

                                // ── Computed moonrise / moonset ───────────────────────
                                // Calculated astronomically from lat/lon — no API needed.
                                // Recomputed once on load and whenever weather data updates.
                                property string _moonriseText: "--"
                                property string _moonsetText: "--"

                                function _computeTimes() {
                                    var lat = Plasmoid.configuration.latitude;
                                    var lon = Plasmoid.configuration.longitude;
                                    if (isNaN(lat) || isNaN(lon) || (lat === 0 && lon === 0)) {
                                        _moonriseText = "--";
                                        _moonsetText = "--";
                                        return;
                                    }
                                    var t = SC.getMoonTimes(new Date(), lat, lon, moonCard._utcOffset);
                                    _moonriseText = t.rise;
                                    _moonsetText = t.set;
                                }

                                // ── Moon arc progress ─────────────────────────────────
                                property real _prog: 0.5

                                function _updateProg() {
                                    _prog = MoonPath.moonArcProgress(moonCard._moonriseText, moonCard._moonsetText, moonCard._utcOffset);
                                    moonCanvas.requestPaint();
                                }

                                Component.onCompleted: {
                                    _computeTimes();
                                    _updateProg();
                                }

                                // Recompute at midnight (times change each day)
                                Timer {
                                    interval: 60000
                                    running: moonCard.visible
                                    repeat: true
                                    triggeredOnStart: true
                                    onTriggered: {
                                        moonCard._computeTimes();
                                        moonCard._updateProg();
                                    }
                                }

                                // Also recompute when a new location is set
                                Connections {
                                    target: root.weatherRoot
                                    function onLocationUtcOffsetMinsChanged() {
                                        moonCard._computeTimes();
                                        moonCard._updateProg();
                                    }
                                }

                                // ── Glow pulse: 0→1→0 over 3.5 s ─────────────────────
                                property real glowPulse: 0
                                SequentialAnimation on glowPulse {
                                    running: moonCard.visible
                                    loops: Animation.Infinite
                                    NumberAnimation {
                                        from: 0
                                        to: 1
                                        duration: 1750
                                        easing.type: Easing.InOutSine
                                    }
                                    NumberAnimation {
                                        from: 1
                                        to: 0
                                        duration: 1750
                                        easing.type: Easing.InOutSine
                                    }
                                }
                                onGlowPulseChanged: moonCanvas.requestPaint()

                                // ── Arc canvas ────────────────────────────────────────
                                Canvas {
                                    id: moonCanvas
                                    anchors.top: moonHeader.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: parent.height - moonHeader.height - 50
                                    antialiasing: true

                                    onPaint: {
                                        var ctx2d = getContext("2d");
                                        MoonPath.drawMoonArc(ctx2d, width, height, moonCard._prog, root.isDark, moonCard.glowPulse, Moon.moonAgeFromPhase(SC.getMoonIllumination(new Date()).phase));
                                    }
                                } // Canvas

                                // ── Bottom info row ───────────────────────────────────
                                // [↑ moonrise]  [phase glyph + name]  [↓ moonset]
                                RowLayout {
                                    visible: card._isArcExpanded
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    anchors.bottomMargin: 6
                                    height: 44
                                    spacing: 4

                                    // ── Moonrise (left) ───────────────────────────────
                                    Column {
                                        spacing: 1
                                        Layout.alignment: Qt.AlignVCenter
                                        Kirigami.Icon {
                                            source: root.svgBase.length > 0
                                                ? (root.svgBase + "moonrise.svg")
                                                : Qt.resolvedUrl("../icons/symbolic/32/wi-moonrise.svg")
                                            isMask: true
                                            color: root.accentViolet
                                            implicitWidth: root.glyphIconSize
                                            implicitHeight: root.glyphIconSize
                                        }
                                        Label {
                                            text: root.weatherRoot ? root.weatherRoot.formatTimeForDisplay(moonCard._moonriseText) : "--"
                                            color: root.accentViolet
                                            font: root.weatherRoot ? root.weatherRoot.wf(11, true) : Qt.font({
                                                bold: false
                                            })
                                        }
                                    }

                                    // ── Phase glyph + name (centre) ───────────────────
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        Layout.alignment: Qt.AlignVCenter
                                        Item {
                                            Layout.fillWidth: true
                                        }
                                             Kirigami.Icon {
                                    visible: root.iconTheme !== "kde" && root.iconTheme !== "wi-font"
                                    source: root.iconTheme === "kde"
                                        ? root.kdeIcon("moonphase")
                                        : (root.svgBase.length > 0
                                            ? (root.svgBase + Moon.moonPhaseSvgStem(Moon.moonAgeFromPhase(SC.getMoonIllumination(new Date()).phase)) + ".svg")
                                            : Qt.resolvedUrl("../icons/symbolic/32/wi-" + Moon.moonPhaseSvgStem(Moon.moonAgeFromPhase(SC.getMoonIllumination(new Date()).phase)) + ".svg"))
                                    isMask: root.iconTheme === "symbolic"
                                    color: root.iconTheme === "symbolic" ? Kirigami.Theme.textColor : "transparent"
                                    implicitWidth: root.iconSize
                                    implicitHeight: root.iconSize
                                    Layout.alignment: Qt.AlignVCenter
                                    }
                                        Label {
                                            text: root.weatherRoot ? root.weatherRoot.moonPhaseLabel() : "--"
                                            color: root.accentViolet
                                            font: root.weatherRoot ? root.weatherRoot.wf(11, true) : Qt.font({
                                                bold: false
                                            })
                                            elide: Text.ElideRight
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                        Item {
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // ── Moonset (right) ───────────────────────────────
                                    Column {
                                        spacing: 1
                                        Layout.alignment: Qt.AlignVCenter
                                        Kirigami.Icon {
                                            source: root.svgBase.length > 0
                                                ? (root.svgBase + "moonset.svg")
                                                : Qt.resolvedUrl("../icons/symbolic/32/wi-moonset.svg")
                                            isMask: true
                                            color: root.accentViolet
                                            opacity: 0.70
                                            implicitWidth: root.glyphIconSize
                                            implicitHeight: root.glyphIconSize
                                            Layout.alignment: Qt.AlignRight
                                        }
                                        Label {
                                            text: root.weatherRoot ? root.weatherRoot.formatTimeForDisplay(moonCard._moonsetText) : "--"
                                            color: root.accentViolet
                                            opacity: 0.75
                                            font: root.weatherRoot ? root.weatherRoot.wf(12, true) : Qt.font({
                                                bold: true
                                            })
                                        }
                                    }
                                } // RowLayout (info row)

                            } // Item (moonphase)

                            // ── LIST MODE: compact moon phase row ─────────────────
                            // Direct child of card Rectangle — never hidden by arc Item
                            Item {
                                id: listMoonRow
                                anchors.fill: parent
                                visible: card.modelData === "moonphase" && root.isList

                                // Compute moon times directly here — moonCard.visible is
                                // false in list mode so its Timer never fires.
                                readonly property int _utcOffset: root.weatherRoot ? root.weatherRoot.locationUtcOffsetMins : 0
                                property string _riseText: "--"
                                property string _setText: "--"

                                function _compute() {
                                    var lat = Plasmoid.configuration.latitude;
                                    var lon = Plasmoid.configuration.longitude;
                                    if (isNaN(lat) || isNaN(lon) || (lat === 0 && lon === 0)) {
                                        _riseText = "--";
                                        _setText = "--";
                                        return;
                                    }
                                    var t = SC.getMoonTimes(new Date(), lat, lon, listMoonRow._utcOffset);
                                    _riseText = t.rise;
                                    _setText = t.set;
                                }

                                Component.onCompleted: _compute()
                                Timer {
                                    interval: 3600000   // refresh hourly
                                    running: listMoonRow.visible
                                    repeat: true
                                    onTriggered: listMoonRow._compute()
                                }
                                Connections {
                                    target: root.weatherRoot
                                    function onLocationUtcOffsetMinsChanged() {
                                        listMoonRow._compute();
                                    }
                                }

                                RowLayout {
                                    anchors {
                                        fill: parent
                                        leftMargin: 10
                                        rightMargin: 10
                                    }
                                    spacing: 8

                                    // ── Leading icon: moonPhaseSvgStem() SVG for all non-KDE themes
                                    Kirigami.Icon {
                                        visible: root.iconTheme === "kde"
                                        source: root.kdeIcon("moonphase")
                                        implicitWidth: root.iconSize
                                        implicitHeight: root.iconSize
                                        color: root.accentViolet
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Kirigami.Icon {
                                        visible: root.iconTheme !== "kde"
                                        // moonPhaseSvgStem gives e.g. "moon-alt-full" → wi-moon-alt-full.svg
                                        // svgBase already resolves to ../icons/<theme>/<size>/wi-
                                        source: root.iconTheme === "kde"
                                            ? root.kdeIcon("moonphase")
                                            : (root.svgBase.length > 0
                                                ? (root.svgBase + Moon.moonPhaseSvgStem(Moon.moonAgeFromPhase(SC.getMoonIllumination(new Date()).phase)) + ".svg")
                                                : Qt.resolvedUrl("../icons/symbolic/32/wi-" + Moon.moonPhaseSvgStem(Moon.moonAgeFromPhase(SC.getMoonIllumination(new Date()).phase)) + ".svg"))
                                        isMask: root.iconTheme === "symbolic"
                                        color: root.iconTheme === "symbolic" ? Kirigami.Theme.textColor : "transparent"
                                        implicitWidth: root.iconSize
                                        implicitHeight: root.iconSize
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    // Label
                                    Label {
                                        text: root.labelFor("moonphase") + ":"
                                        color: Kirigami.Theme.textColor
                                        opacity: 0.55
                                        font: weatherRoot ? weatherRoot.wf(11, false) : Qt.font({})
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    // ── Right side: phase name + moonrise / moonset ──────
                                    RowLayout {
                                        spacing: 8
                                        Layout.alignment: Qt.AlignVCenter

                                        // Phase icon + name
                                        Kirigami.Icon {
                                            visible: root.iconTheme === "kde"
                                            source: root.kdeIcon("moonphase")
                                            implicitWidth: root.iconSize
                                            implicitHeight: root.iconSize
                                            color: root.accentViolet
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                        Kirigami.Icon {
                                            visible: root.iconTheme !== "kde"
                                            source: root.svgBase.length > 0 ? (root.svgBase + Moon.moonPhaseSvgStem(Moon.moonAgeFromPhase(SC.getMoonIllumination(new Date()).phase)) + ".svg") : Qt.resolvedUrl("../icons/symbolic/32/wi-" + Moon.moonPhaseSvgStem(Moon.moonAgeFromPhase(SC.getMoonIllumination(new Date()).phase)) + ".svg")
                                            isMask: true
                                            color: root.accentViolet
                                            implicitWidth: root.iconSize
                                            implicitHeight: root.iconSize
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                        Label {
                                            text: root.weatherRoot ? root.weatherRoot.moonPhaseLabel() : "--"
                                            color: root.accentViolet
                                            font: root.weatherRoot ? root.weatherRoot.wf(12, true) : Qt.font({
                                                bold: true
                                            })
                                        }

                                        // Moonrise — SVG icon
                                        RowLayout {
                                            spacing: 3
                                            Layout.alignment: Qt.AlignVCenter
                                            Kirigami.Icon {
                                                source: root.svgBase.length > 0 ? (root.svgBase + "moonrise.svg") : Qt.resolvedUrl("../icons/symbolic/32/wi-moonrise.svg")
                                                isMask: root.iconTheme !== "kde"
                                                color: root.accentViolet
                                                implicitWidth: root.iconSize
                                                implicitHeight: root.iconSize
                                                Layout.alignment: Qt.AlignVCenter
                                            }
                                            Label {
                                                text: root.weatherRoot ? root.weatherRoot.formatTimeForDisplay(listMoonRow._riseText) : "--"
                                                color: root.accentViolet
                                                font: root.weatherRoot ? root.weatherRoot.wf(11, false) : Qt.font({})
                                            }
                                        }
                                        Label {
                                            text: "/"
                                            color: Kirigami.Theme.textColor
                                            opacity: 0.30
                                            font: root.weatherRoot ? root.weatherRoot.wf(11, false) : Qt.font({})
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        // Moonset — SVG icon
                                        RowLayout {
                                            spacing: 3
                                            Layout.alignment: Qt.AlignVCenter
                                            Kirigami.Icon {
                                                source: root.svgBase.length > 0 ? (root.svgBase + "moonset.svg") : Qt.resolvedUrl("../icons/symbolic/32/wi-moonset.svg")
                                                isMask: root.iconTheme !== "kde"
                                                color: root.accentViolet
                                                opacity: 0.75
                                                implicitWidth: root.iconSize
                                                implicitHeight: root.iconSize
                                                Layout.alignment: Qt.AlignVCenter
                                            }
                                            Label {
                                                text: root.weatherRoot ? root.weatherRoot.formatTimeForDisplay(listMoonRow._setText) : "--"
                                                color: root.accentViolet
                                                opacity: 0.75
                                                font: root.weatherRoot ? root.weatherRoot.wf(11, false) : Qt.font({})
                                            }
                                        }
                                    }
                                }
                            }
                        } // Rectangle (card)
                    } // Repeater (items)

                    // spacer for odd rows
                    Item {
                        Layout.fillWidth: true
                        visible: rowItem.modelData.length === 1 && !root.isList
                    }
                } // RowLayout (row)
            } // Repeater (rows)
        } // Column
    } // ScrollView
}
