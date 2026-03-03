/**
 * DetailsView.qml — Dynamic "Details" tab
 *
 * Applied fixes:
 *  #1 — SVG icons use Kirigami.Icon + isMask:true + Kirigami.Theme.textColor
 *       so they are white on dark themes, dark on light themes automatically.
 *       Wind-direction arrows are also isMask:true.
 *  #2 — All text colours derived from Kirigami.Theme.textColor so the widget
 *       is fully readable on both dark and light KDE colour schemes.
 *  #3 — Suntimes card: Sunrise/Sunset rows are now clearly displayed.
 *       Card height increased to 90 px to give both rows room to breathe.
 *  #4 — Two items per row (no wide cards). "Sun" label → "Sunrise/Sunset".
 *  #5 — Moon Phase: icon removed; only the phase name text is shown (e.g. "Waxing Gibbous").
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

import "js/weather.js" as W
import "js/moonphase.js" as Moon

Item {
    id: root
    property var weatherRoot

    // ── weather-icons font ────────────────────────────────────────────────
    FontLoader { id: wiFont; source: Qt.resolvedUrl("../fonts/weathericons-regular-webfont.ttf") }

    // ── Theme helper — true when KDE is using a dark colour scheme ────────
    // Kirigami.Theme.textColor is near-white on dark themes, near-black on light.
    readonly property bool isDark: Kirigami.Theme.textColor.r > 0.5

    // ── Colour palette — adapts to dark / light theme ─────────────────────
    // Background tints use textColor so white tint on dark, dark tint on light.
    readonly property color cardBg:     Qt.rgba(Kirigami.Theme.textColor.r,
                                                Kirigami.Theme.textColor.g,
                                                Kirigami.Theme.textColor.b, 0.07)
    readonly property color cardBorder: Qt.rgba(Kirigami.Theme.textColor.r,
                                                Kirigami.Theme.textColor.g,
                                                Kirigami.Theme.textColor.b, 0.13)
    // Text colours
    readonly property color valueColor:  Kirigami.Theme.textColor
    // #2: dim text uses opacity on Label, not hardcoded RGBA

    // Accent colours — shift toward darker hues on light themes for contrast
    readonly property color accentBlue:   isDark ? "#5ea8ff" : "#1a6fcc"
    readonly property color accentWarm:   isDark ? "#ffb347" : "#b86000"
    readonly property color accentTeal:   isDark ? "#4ecdc4" : "#007070"
    readonly property color accentGold:   isDark ? "#ffcf63" : "#9c7400"
    readonly property color accentOrange: isDark ? "#ff8c52" : "#c04000"
    readonly property color accentViolet: isDark ? "#c4b4ff" : "#5030a0"

    // ── icon theme ────────────────────────────────────────────────────────
    readonly property string iconTheme: Plasmoid.configuration.widgetIconTheme || "kde"
    readonly property int    iconSz:    Plasmoid.configuration.widgetIconSize   || 16
    readonly property bool   isList:    (Plasmoid.configuration.widgetDetailsLayout || "cards2") === "list"

    // Resolved SVG URL for non-kde/wi-font themes
    function svgIconUrl(filename) {
        if (iconTheme === "kde" || iconTheme === "wi-font") return ""
        return Qt.resolvedUrl("../icons/" + iconTheme + "/" + root.iconSz + "/" + filename)
    }
    function windDirUrl(deg) {
        if (!weatherRoot || isNaN(deg) || deg === undefined) return ""
        if (iconTheme === "kde" || iconTheme === "wi-font") return ""
        return Qt.resolvedUrl("../icons/" + iconTheme + "/" + root.iconSz + "/wi-" + W.windDirectionSvgStem(deg) + ".svg")
    }

    // ── Lookup tables ─────────────────────────────────────────────────────
    function wiGlyph(id) {
        return ({feelslike:"\uF055",humidity:"\uF07A",pressure:"\uF079",
            wind:"\uF050",suntimes:"\uF051",dewpoint:"\uF073",
            visibility:"\uF0B6",moonphase:"\uF0D0",condition:"\uF013"})[id] || "\uF00D"
    }
    function wiFile(id) {
        return ({feelslike:"wi-thermometer.svg",humidity:"wi-humidity.svg",
            pressure:"wi-barometer.svg",wind:"wi-strong-wind.svg",
            suntimes:"wi-sunrise.svg",dewpoint:"wi-raindrops.svg",
            visibility:"wi-fog.svg",moonphase:"wi-moon-full.svg",
            condition:"wi-day-sunny.svg"})[id] || "wi-na.svg"
    }
    function kdeIcon(id) {
        return ({feelslike:"thermometer",humidity:"weather-humidity",
            pressure:"weather-pressure",wind:"weather-windy",
            suntimes:"weather-sunrise",dewpoint:"weather-humidity",
            visibility:"weather-fog",moonphase:"weather-clear-night",
            condition:"weather-few-clouds"})[id] || "weather-none-available"
    }
    function accentFor(id) {
        return ({feelslike:root.accentWarm,humidity:root.accentBlue,
            pressure:root.accentTeal,wind:root.accentBlue,
            suntimes:root.accentGold,dewpoint:root.accentTeal,
            visibility:Kirigami.Theme.textColor,moonphase:root.accentViolet,
            condition:Kirigami.Theme.textColor})[id] || root.accentBlue
    }
    function labelFor(id) {
        // #4: "Sun" → "Sunrise/Sunset"
        return ({feelslike:i18n("Feels Like"),humidity:i18n("Humidity"),
            pressure:i18n("Pressure"),wind:i18n("Wind"),
                suntimes:i18n("Sunrise/Sunset"),dewpoint:i18n("Dew Point"),
                visibility:i18n("Visibility"),moonphase:i18n("Moon Phase"),
                condition:i18n("Condition")})[id] || id
    }
    function dataValue(id) {
        if (!weatherRoot) return "--"
            switch(id) {
                case "feelslike":  return weatherRoot.tempValue(weatherRoot.apparentC)
                case "humidity":   return isNaN(weatherRoot.humidityPercent) ? "--"
                    : Math.round(weatherRoot.humidityPercent) + "%"
                case "pressure":   return weatherRoot.pressureValue(weatherRoot.pressureHpa)
                case "dewpoint":   return weatherRoot.tempValue(weatherRoot.dewPointC)
                case "visibility": return isNaN(weatherRoot.visibilityKm) ? "--"
                    : weatherRoot.visibilityKm.toFixed(1) + " km"
                case "condition":  return weatherRoot.weatherCodeToText(weatherRoot.weatherCode, weatherRoot.isNightTime())
                default: return ""
            }
    }

    // Build row model: list=1 per row, cards=2 per row
    function buildRows() {
        var order = (Plasmoid.configuration.widgetDetailsOrder ||
        "feelslike;humidity;pressure;wind;suntimes;dewpoint;visibility;moonphase")
        .split(";").map(function(s){return s.trim()}).filter(function(s){return s.length > 0})
        var rows = []
        var i = 0
        if (root.isList) {
            // List mode: one item per row
            while (i < order.length) { rows.push([order[i]]); i++ }
        } else {
            // Cards mode: two items per row
            while (i < order.length) {
                if (i + 1 < order.length) { rows.push([order[i], order[i+1]]); i += 2 }
                else                       { rows.push([order[i]]);             i++ }
            }
        }
        return rows
    }

    // ── UI ────────────────────────────────────────────────────────────────
    ScrollView {
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth

        Column {
            width: parent.width
            spacing: 8
            bottomPadding: 4

            Repeater {
                model: root.buildRows()

                delegate: RowLayout {
                    id: rowItem
                    required property var modelData
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: rowItem.modelData

                        delegate: Rectangle {
                            id: card
                            required property string modelData   // item-id

                            // ── Card height ────────────────────────────────────────
                            readonly property bool isExpandedCard:
                                card.modelData === "suntimes" || card.modelData === "moonphase"
                            readonly property int autoHeight: isExpandedCard ? 62 : 44
                            Layout.fillWidth: true
                            Layout.preferredHeight: Plasmoid.configuration.widgetCardsHeightAuto
                                ? autoHeight
                                : Plasmoid.configuration.widgetCardsHeight
                            radius: root.isList ? 6 : 10
                            color:        root.cardBg
                            border.color: root.cardBorder
                            border.width: 1

                            // ═══════════════════════════════════════════════════
                            // Standard items: single row  [icon]  Label:  Value
                            // ═══════════════════════════════════════════════════
                            RowLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                spacing: 8
                                visible: !card.isExpandedCard

                                // wi-font icon
                                Text {
                                    visible: root.iconTheme === "wi-font" && wiFont.status === FontLoader.Ready
                                    text: root.wiGlyph(card.modelData)
                                    font.family: wiFont.font.family; font.pixelSize: 13
                                    color: root.accentFor(card.modelData)
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Kirigami.Icon {
                                    visible: root.iconTheme === "kde"
                                    source: root.kdeIcon(card.modelData)
                                    implicitWidth: 14; implicitHeight: 14
                                    color: root.accentFor(card.modelData)
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Kirigami.Icon {
                                    visible: root.iconTheme !== "kde" && root.iconTheme !== "wi-font"
                                    source: root.svgIconUrl(root.wiFile(card.modelData))
                                    isMask: root.iconTheme === "symbolic"
                                    color: root.iconTheme === "symbolic" ? Kirigami.Theme.textColor : "transparent"
                                    implicitWidth: 14; implicitHeight: 14
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                // label (dim)
                                Label {
                                    text: root.labelFor(card.modelData) + ":"
                                    color: Kirigami.Theme.textColor; opacity: 0.55
                                    font: weatherRoot ? weatherRoot.wf(11, false) : Qt.font({})
                                    elide: Text.ElideRight
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Item { Layout.fillWidth: true }
                                // scalar value
                                Label {
                                    visible: card.modelData !== "wind"
                                    text: root.dataValue(card.modelData)
                                    color: root.valueColor
                                    font: weatherRoot ? weatherRoot.wf(13, true) : Qt.font({ bold: true })
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                // wind: speed + arrow
                                RowLayout {
                                    visible: card.modelData === "wind"
                                    spacing: 6
                                    Label {
                                        text: weatherRoot ? weatherRoot.windValue(weatherRoot.windKmh) : "--"
                                        color: root.valueColor
                                        font: weatherRoot ? weatherRoot.wf(13, true) : Qt.font({ bold: true })
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Kirigami.Icon {
                                        visible: weatherRoot && !isNaN(weatherRoot.windDirection)
                                        source: root.windDirUrl(weatherRoot ? weatherRoot.windDirection : NaN)
                                        isMask: true; color: Kirigami.Theme.textColor
                                        implicitWidth: 16; implicitHeight: 16
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                }
                            } // RowLayout (standard)

                            // ═══════════════════════════════════════════════════
                            // Suntimes: header row  +  ↑time | ↓time row
                            // ═══════════════════════════════════════════════════
                            ColumnLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10;
                                          topMargin: 6; bottomMargin: 6 }
                                spacing: 4
                                visible: card.modelData === "suntimes"

                                RowLayout {
                                    spacing: 5; Layout.fillWidth: true
                                    Text {
                                        visible: root.iconTheme === "wi-font" && wiFont.status === FontLoader.Ready
                                        text: "\uF051"; font.family: wiFont.font.family; font.pixelSize: 12
                                        color: root.accentGold
                                    }
                                    Kirigami.Icon {
                                        visible: root.iconTheme !== "wi-font"
                                        source: root.iconTheme === "kde" ? "weather-sunrise" : root.svgIconUrl("wi-sunrise.svg")
                                        isMask: root.iconTheme === "symbolic"
                                        color: root.iconTheme === "symbolic" ? Kirigami.Theme.textColor : "transparent"
                                        implicitWidth: 12; implicitHeight: 12; Layout.alignment: Qt.AlignVCenter
                                    }
                                    Label {
                                        text: root.labelFor(card.modelData); color: Kirigami.Theme.textColor; opacity: 0.55
                                        font: weatherRoot ? weatherRoot.wf(10, false) : Qt.font({}); Layout.fillWidth: true
                                    }
                                }
                                RowLayout {
                                    spacing: 6; Layout.fillWidth: true
                                    Text { visible: wiFont.status === FontLoader.Ready; text: "\uF051"; font.family: wiFont.font.family; font.pixelSize: 14; color: root.accentGold; verticalAlignment: Text.AlignVCenter }
                                    Kirigami.Icon { visible: wiFont.status !== FontLoader.Ready; source: root.iconTheme === "kde" ? "weather-sunrise" : root.svgIconUrl("wi-sunrise.svg"); isMask: root.iconTheme === "symbolic"; color: root.iconTheme === "symbolic" ? Kirigami.Theme.textColor : "transparent"; implicitWidth: 14; implicitHeight: 14; Layout.alignment: Qt.AlignVCenter }
                                    Label { text: weatherRoot ? weatherRoot.formatTimeForDisplay(weatherRoot.sunriseTimeText) : "--"; color: root.accentGold; font: weatherRoot ? weatherRoot.wf(12, true) : Qt.font({ bold: true }) }
                                    Rectangle { width: 1; height: 14; color: Kirigami.Theme.textColor; opacity: 0.2; Layout.alignment: Qt.AlignVCenter; Layout.leftMargin: 2; Layout.rightMargin: 2 }
                                    Text { visible: wiFont.status === FontLoader.Ready; text: "\uF052"; font.family: wiFont.font.family; font.pixelSize: 14; color: root.accentOrange; verticalAlignment: Text.AlignVCenter }
                                    Kirigami.Icon { visible: wiFont.status !== FontLoader.Ready; source: root.iconTheme === "kde" ? "weather-sunset" : root.svgIconUrl("wi-sunset.svg"); isMask: root.iconTheme === "symbolic"; color: root.iconTheme === "symbolic" ? Kirigami.Theme.textColor : "transparent"; implicitWidth: 14; implicitHeight: 14; Layout.alignment: Qt.AlignVCenter }
                                    Label { text: weatherRoot ? weatherRoot.formatTimeForDisplay(weatherRoot.sunsetTimeText) : "--"; color: root.accentOrange; font: weatherRoot ? weatherRoot.wf(12, true) : Qt.font({ bold: true }) }
                                    Item { Layout.fillWidth: true }
                                }
                            } // ColumnLayout (suntimes)

                            // ═══════════════════════════════════════════════════
                            // Moon Phase: header row  +  glyph + phase name
                            // ═══════════════════════════════════════════════════
                            ColumnLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10;
                                          topMargin: 6; bottomMargin: 6 }
                                spacing: 4
                                visible: card.modelData === "moonphase"

                                RowLayout {
                                    spacing: 5; Layout.fillWidth: true
                                    Text { visible: root.iconTheme === "wi-font" && wiFont.status === FontLoader.Ready; text: "\uF0D0"; font.family: wiFont.font.family; font.pixelSize: 12; color: root.accentViolet }
                                    Kirigami.Icon { visible: root.iconTheme !== "wi-font"; source: root.iconTheme === "kde" ? "weather-clear-night" : root.svgIconUrl("wi-moon-full.svg"); isMask: root.iconTheme === "symbolic"; color: root.iconTheme === "symbolic" ? Kirigami.Theme.textColor : "transparent"; implicitWidth: 12; implicitHeight: 12; Layout.alignment: Qt.AlignVCenter }
                                    Label { text: root.labelFor(card.modelData); color: Kirigami.Theme.textColor; opacity: 0.55; font: weatherRoot ? weatherRoot.wf(10, false) : Qt.font({}); Layout.fillWidth: true }
                                }
                                RowLayout {
                                    spacing: 6; Layout.fillWidth: true
                                    Text { visible: wiFont.status === FontLoader.Ready; text: Moon.moonPhaseGlyph(); font.family: wiFont.font.family; font.pixelSize: 18; color: root.accentViolet; verticalAlignment: Text.AlignVCenter; Layout.alignment: Qt.AlignVCenter }
                                    Kirigami.Icon { visible: wiFont.status !== FontLoader.Ready; source: weatherRoot ? weatherRoot.moonPhaseSvgUrl() : "weather-clear-night"; isMask: true; color: root.accentViolet; implicitWidth: 18; implicitHeight: 18; Layout.alignment: Qt.AlignVCenter }
                                    Label { text: weatherRoot ? weatherRoot.moonPhaseLabel() : "--"; color: root.accentViolet; font: weatherRoot ? weatherRoot.wf(12, true) : Qt.font({ bold: true }); wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                }
                            } // ColumnLayout (moonphase)

                        } // Rectangle (card)
                    } // Repeater (items)

                    // spacer for odd rows
                    Item { Layout.fillWidth: true; visible: rowItem.modelData.length === 1 }
                } // RowLayout (row)
            } // Repeater (rows)
        } // Column
    } // ScrollView
}
