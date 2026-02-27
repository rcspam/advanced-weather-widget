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

    // Resolved SVG URL for non-kde/wi-font themes
    function svgIconUrl(filename) {
        if (iconTheme === "kde" || iconTheme === "wi-font") return ""
            return Qt.resolvedUrl("../icons/" + iconTheme + "/16/" + filename)
    }
    // Wind direction SVG — icons/<theme>/16/wi-direction-up.svg, wi-direction-up-right.svg, etc.
    function windDirUrl(deg) {
        if (!weatherRoot || isNaN(deg) || deg === undefined) return ""
        if (iconTheme === "kde" || iconTheme === "wi-font") return ""
        return Qt.resolvedUrl("../icons/" + iconTheme + "/16/wi-" + W.windDirectionSvgStem(deg) + ".svg")
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

    // #4: strict 2-per-row layout
    function buildRows() {
        var order = (Plasmoid.configuration.widgetDetailsOrder ||
        "feelslike;humidity;pressure;wind;suntimes;dewpoint;visibility;moonphase")
        .split(";").map(function(s){return s.trim()}).filter(function(s){return s.length > 0})
        var rows = []
        var i = 0
        while (i < order.length) {
            if (i + 1 < order.length) { rows.push([order[i], order[i+1]]); i += 2 }
            else                       { rows.push([order[i]]);             i++ }
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
                            Layout.fillWidth:  true
                            // suntimes is now a single line — same height as all other cards
                            Layout.preferredHeight: 78
                            radius: 10
                            color:        root.cardBg
                            border.color: root.cardBorder
                            border.width: 1

                            ColumnLayout {
                                anchors { fill: parent; leftMargin:11; rightMargin:11;
                                    topMargin:9; bottomMargin:9 }
                                    spacing: 4

                                    // ── Header row: icon + label ─────────────────────────
                                    RowLayout {
                                        spacing: 5
                                        Layout.fillWidth: true

                                        // wi-font glyph
                                        Text {
                                            visible: root.iconTheme === "wi-font"
                                            && wiFont.status === FontLoader.Ready
                                            text:  root.wiGlyph(card.modelData)
                                            font.family: wiFont.font.family; font.pixelSize: 12
                                            color: root.accentFor(card.modelData)
                                        }
                                        // KDE system icon
                                        Kirigami.Icon {
                                            visible: root.iconTheme === "kde"
                                            source:  root.kdeIcon(card.modelData)
                                            width: 13; height: 13
                                            color: root.accentFor(card.modelData)
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                        // #1: SVG icon via Kirigami.Icon with isMask for symbolic
                                        Kirigami.Icon {
                                            visible: root.iconTheme !== "kde"
                                            && root.iconTheme !== "wi-font"
                                            && root.svgIconUrl(root.wiFile(card.modelData)) !== ""
                                            source: root.svgIconUrl(root.wiFile(card.modelData))
                                            isMask: root.iconTheme === "symbolic"
                                            // #1: Kirigami.Theme.textColor → white on dark, dark on light
                                            color:  root.iconTheme === "symbolic"
                                            ? Kirigami.Theme.textColor
                                            : "transparent"
                                            width: 13; height: 13
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        Label {
                                            Layout.fillWidth: true
                                            text:    root.labelFor(card.modelData)
                                            // #2: use textColor at reduced opacity for dim labels
                                            color:   Kirigami.Theme.textColor
                                            opacity: 0.55
                                            font:    weatherRoot ? weatherRoot.wf(10,false) : Qt.font({})
                                            elide:   Text.ElideRight
                                        }
                                    }

                                    // ── Value area ────────────────────────────────────────
                                    Item {
                                        Layout.fillWidth:  true
                                        Layout.fillHeight: true

                                        // ── Standard scalar items ─────────────────────────
                                        Label {
                                            visible: card.modelData !== "wind"
                                            && card.modelData !== "suntimes"
                                            && card.modelData !== "moonphase"
                                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                            text:  root.dataValue(card.modelData)
                                            // #2: Kirigami.Theme.textColor adapts to scheme
                                            color: root.valueColor
                                            font:  weatherRoot ? weatherRoot.wf(18,true) : Qt.font({bold:true})
                                            fontSizeMode: Text.HorizontalFit
                                            minimumPixelSize: 11
                                            width: parent.width
                                        }

                                        // ── Wind: speed + direction arrow (no compass text) ──
                                        // #1: arrow uses isMask:true for dark/light compatibility
                                        // (no NE/ENE text per previous fix)
                                        RowLayout {
                                            visible: card.modelData === "wind"
                                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                            spacing: 8

                                            Label {
                                                text:  weatherRoot ? weatherRoot.windValue(weatherRoot.windKmh) : "--"
                                                color: root.valueColor
                                                font:  weatherRoot ? weatherRoot.wf(16,true) : Qt.font({bold:true})
                                            }
                                            Kirigami.Icon {
                                                visible: weatherRoot && !isNaN(weatherRoot.windDirection)
                                                source: root.windDirUrl(weatherRoot ? weatherRoot.windDirection : NaN)
                                                isMask: true
                                                color:  Kirigami.Theme.textColor
                                                width: 18; height: 18
                                                Layout.alignment: Qt.AlignVCenter
                                            }
                                        }

                                        // ── Suntimes: single line  ↑ icon  time  |  ↓ icon  time ──
                                        // No "Sunrise"/"Sunset" text — icons only, proper spacing
                                        RowLayout {
                                            visible: card.modelData === "suntimes"
                                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                            spacing: 6

                                            // ── Sunrise icon ──────────────────────────────
                                            // wi-font
                                            Text {
                                                visible: wiFont.status === FontLoader.Ready
                                                text: "\uF051"
                                                font.family: wiFont.font.family; font.pixelSize: 16
                                                color: root.accentGold
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            // KDE / SVG fallback
                                            Kirigami.Icon {
                                                visible: wiFont.status !== FontLoader.Ready
                                                source: root.iconTheme === "kde"
                                                ? "weather-sunrise"
                                                : root.svgIconUrl("wi-sunrise.svg")
                                                isMask: root.iconTheme === "symbolic"
                                                color:  root.iconTheme === "symbolic" ? Kirigami.Theme.textColor : "transparent"
                                                width: 16; height: 16; Layout.alignment: Qt.AlignVCenter
                                            }

                                            // Sunrise time
                                            Label {
                                                text: weatherRoot
                                                ? weatherRoot.formatTimeForDisplay(weatherRoot.sunriseTimeText)
                                                : "--"
                                                color: root.accentGold
                                                font: weatherRoot ? weatherRoot.wf(13, true) : Qt.font({bold:true})
                                            }

                                            // Thin vertical separator
                                            Rectangle {
                                                width: 1; height: 18
                                                color: Kirigami.Theme.textColor; opacity: 0.2
                                                Layout.alignment: Qt.AlignVCenter
                                                Layout.leftMargin: 2; Layout.rightMargin: 2
                                            }

                                            // ── Sunset icon ───────────────────────────────
                                            Text {
                                                visible: wiFont.status === FontLoader.Ready
                                                text: "\uF052"
                                                font.family: wiFont.font.family; font.pixelSize: 16
                                                color: root.accentOrange
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            Kirigami.Icon {
                                                visible: wiFont.status !== FontLoader.Ready
                                                source: root.iconTheme === "kde"
                                                ? "weather-sunset"
                                                : root.svgIconUrl("wi-sunset.svg")
                                                isMask: root.iconTheme === "symbolic"
                                                color:  root.iconTheme === "symbolic" ? Kirigami.Theme.textColor : "transparent"
                                                width: 16; height: 16; Layout.alignment: Qt.AlignVCenter
                                            }

                                            // Sunset time
                                            Label {
                                                text: weatherRoot
                                                ? weatherRoot.formatTimeForDisplay(weatherRoot.sunsetTimeText)
                                                : "--"
                                                color: root.accentOrange
                                                font: weatherRoot ? weatherRoot.wf(13, true) : Qt.font({bold:true})
                                            }

                                            Item { Layout.fillWidth: true }
                                        } // RowLayout (suntimes)

                                        // ── Moon Phase: dynamic wi-font glyph + phase name ──
                                        // Uses Moon.moonPhaseGlyph() — the same dynamic icon as
                                        // the panel and tooltip (waxing crescent, gibbous, etc.)
                                        RowLayout {
                                            visible: card.modelData === "moonphase"
                                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                            spacing: 6

                                            // Dynamic wi-font moon glyph (preferred)
                                            Text {
                                                visible: wiFont.status === FontLoader.Ready
                                                text: Moon.moonPhaseGlyph()
                                                font.family: wiFont.font.family
                                                font.pixelSize: 22
                                                color: root.accentViolet
                                                verticalAlignment: Text.AlignVCenter
                                                Layout.alignment: Qt.AlignVCenter
                                            }
                                            // Fallback: Kirigami.Icon with SVG if wi-font not loaded
                                            Kirigami.Icon {
                                                visible: wiFont.status !== FontLoader.Ready
                                                source: weatherRoot ? weatherRoot.moonPhaseSvgUrl() : "weather-clear-night"
                                                isMask: true
                                                color:  root.accentViolet
                                                width: 22; height: 22
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            Label {
                                                text: weatherRoot ? weatherRoot.moonPhaseLabel() : "--"
                                                color: root.accentViolet
                                                font: weatherRoot ? weatherRoot.wf(13, true) : Qt.font({bold:true})
                                                wrapMode: Text.WordWrap
                                                Layout.fillWidth: true
                                            }
                                        } // RowLayout (moonphase)

                                    } // Item (value area)
                            } // ColumnLayout (card body)
                        } // Rectangle (card)
                    } // Repeater (items)

                    // spacer for odd rows
                    Item { Layout.fillWidth: true; visible: rowItem.modelData.length === 1 }
                } // RowLayout (row)
            } // Repeater (rows)
        } // Column
    } // ScrollView
}
