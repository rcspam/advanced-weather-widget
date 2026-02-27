/**
 * ForecastView.qml — "Forecast" tab
 *
 * Fix #3 — All hardcoded "white" / Qt.rgba(1,1,1,x) colours replaced with
 *          Kirigami.Theme.textColor so the forecast list is readable on both
 *          dark and light KDE colour schemes.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

import "js/weather.js" as W

Item {
    id: forecastRoot
    property var weatherRoot
    property int expandedIndex: -1

    // Resolved at load time so the path is correct in all rendering contexts
    readonly property url iconsBaseDir: Qt.resolvedUrl("../icons/")

    // Widget icon theme — needed to build correct SVG icon paths
    readonly property string widgetIconTheme: Plasmoid.configuration.widgetIconTheme || "symbolic"

    // ── empty state ───────────────────────────────────────────────────────
    Label {
        anchors.centerIn: parent
        visible: !weatherRoot || weatherRoot.dailyData.length === 0
        text: (weatherRoot && weatherRoot.loading) ? i18n("Loading forecast…") : i18n("No forecast data")
        // #3: theme-aware
        color: Kirigami.Theme.textColor; opacity: 0.4
        font:  weatherRoot ? weatherRoot.wf(12, false) : Qt.font({})
    }

    ScrollView {
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        visible: weatherRoot && weatherRoot.dailyData.length > 0

        Column {
            width: parent.width
            spacing: 0

            Repeater {
                model: weatherRoot && weatherRoot.dailyData.length > 0
                       ? Math.min(Plasmoid.configuration.forecastDays, weatherRoot.dailyData.length)
                       : 0

                delegate: Column {
                    required property int index
                    width: parent.width
                    spacing: 0

                    // ── day row ─────────────────────────────────────────
                    Rectangle {
                        id: dayRow
                        width: parent.width
                        height: 52
                        // #3: hover tint uses textColor
                        color: (rowMouse.containsMouse || forecastRoot.expandedIndex === index)
                               ? Qt.rgba(Kirigami.Theme.textColor.r,
                                         Kirigami.Theme.textColor.g,
                                         Kirigami.Theme.textColor.b, 0.08)
                               : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 14 }
                            spacing: 0

                            Kirigami.Icon {
                                source: forecastRoot.expandedIndex === index ? "arrow-down" : "arrow-right"
                                width: 14; height: 14; opacity: 0.45
                                Layout.alignment: Qt.AlignVCenter
                                Layout.rightMargin: 6
                            }

                            ColumnLayout {
                                Layout.preferredWidth: 72; spacing: 1
                                Label {
                                    text: index === 0 ? i18n("Today") : (weatherRoot.dailyData[index].day || "")
                                    // #3: textColor
                                    color: Kirigami.Theme.textColor
                                    font: weatherRoot.wf(12, true)
                                }
                                Label {
                                    text: {
                                        var ds = weatherRoot.dailyData[index].dateStr || ""
                                        if (!ds) return ""
                                        return Qt.formatDate(new Date(ds), "d MMM")
                                    }
                                    // #3: textColor at reduced opacity
                                    color: Kirigami.Theme.textColor; opacity: 0.42
                                    font: weatherRoot.wf(9, false)
                                }
                            }

                            Kirigami.Icon {
                                source: W.weatherCodeToIcon(weatherRoot.dailyData[index].code)
                                width: 28; height: 28
                                Layout.alignment: Qt.AlignVCenter
                                Layout.leftMargin: 6; Layout.rightMargin: 8
                            }

                            Label {
                                Layout.fillWidth: true
                                text:  weatherRoot.weatherCodeToText(weatherRoot.dailyData[index].code)
                                // #3
                                color: Kirigami.Theme.textColor; opacity: 0.48
                                font:  weatherRoot.wf(11, false)
                                elide: Text.ElideRight
                            }

                            Item { Layout.preferredWidth: 8 }

                            // Min temp
                            Label {
                                text: weatherRoot.tempValue(weatherRoot.dailyData[index].minC)
                                // #3
                                color: Kirigami.Theme.textColor; opacity: 0.48
                                font:  weatherRoot.wf(12, false)
                                Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight
                            }
                            Label {
                                text: "/"
                                // #3
                                color: Kirigami.Theme.textColor; opacity: 0.22
                                font:  weatherRoot.wf(12, false)
                                Layout.leftMargin: 3; Layout.rightMargin: 3
                            }
                            // Max temp
                            Label {
                                text: weatherRoot.tempValue(weatherRoot.dailyData[index].maxC)
                                // #3
                                color: Kirigami.Theme.textColor
                                font:  weatherRoot.wf(12, true)
                                Layout.preferredWidth: 46
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (forecastRoot.expandedIndex === index) {
                                    forecastRoot.expandedIndex = -1
                                } else {
                                    forecastRoot.expandedIndex = index
                                    if (weatherRoot) {
                                        weatherRoot.hourlyData = []
                                        weatherRoot.fetchHourlyForDate(weatherRoot.dailyData[index].dateStr || "")
                                    }
                                }
                            }
                        }
                    }

                    // ── inline hourly panel ─────────────────────────────
                    Rectangle {
                        width: parent.width
                        height: forecastRoot.expandedIndex === index ? 220 : 0
                        visible: height > 0; clip: true
                        // #3: panel background uses textColor tint
                        color: Qt.rgba(Kirigami.Theme.textColor.r,
                                       Kirigami.Theme.textColor.g,
                                       Kirigami.Theme.textColor.b, 0.04)
                        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                        Label {
                            anchors.centerIn: parent
                            visible: !weatherRoot || weatherRoot.hourlyData.length === 0
                            text: i18n("Loading hourly data…")
                            // #3
                            color: Kirigami.Theme.textColor; opacity: 0.32
                            font: weatherRoot ? weatherRoot.wf(11, false) : Qt.font({})
                        }

                        ScrollView {
                            anchors.fill: parent; anchors.margins: 8
                            visible: weatherRoot && weatherRoot.hourlyData.length > 0
                            clip: true
                            ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                            ScrollBar.horizontal.policy: ScrollBar.AsNeeded

                            Row {
                                spacing: 6
                                height: parent.height

                                Repeater {
                                    model: weatherRoot ? weatherRoot.hourlyData : []

                                    delegate: Rectangle {
                                        required property var modelData
                                        width: 76; height: 200
                                        radius: 8
                                        // #3: chip bg uses textColor tint
                                        color: Qt.rgba(Kirigami.Theme.textColor.r,
                                                       Kirigami.Theme.textColor.g,
                                                       Kirigami.Theme.textColor.b, 0.08)
                                        border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                                              Kirigami.Theme.textColor.g,
                                                              Kirigami.Theme.textColor.b, 0.12)
                                        border.width: 1

                                        ColumnLayout {
                                            anchors { fill: parent; margins: 6 }
                                            spacing: 4

                                            // Hour
                                            Label {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: modelData.hour || "--"
                                                // #3
                                                color: Kirigami.Theme.textColor; opacity: 0.52
                                                font: weatherRoot ? weatherRoot.wf(9, false) : Qt.font({})
                                            }

                                            // Condition icon
                                            Kirigami.Icon {
                                                Layout.alignment: Qt.AlignHCenter
                                                source: W.weatherCodeToIcon(modelData.code || 0)
                                                width: 28; height: 28
                                            }

                                            // Temperature
                                            Label {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: weatherRoot ? weatherRoot.tempValue(modelData.tempC) : "--"
                                                // #3: textColor for temperature
                                                color: Kirigami.Theme.textColor
                                                font: weatherRoot ? weatherRoot.wf(11, true) : Qt.font({bold:true})
                                            }

                                            // Wind
                                            Label {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: weatherRoot && modelData.windKmh !== undefined
                                                      ? weatherRoot.windValue(modelData.windKmh) : "--"
                                                // #3
                                                color: Kirigami.Theme.textColor; opacity: 0.55
                                                font: weatherRoot ? weatherRoot.wf(9, false) : Qt.font({})
                                            }

                                            // Precipitation probability
                                            RowLayout {
                                                Layout.alignment: Qt.AlignHCenter
                                                spacing: 3
                                                Kirigami.Icon {
                                                    // Path: icons/<theme>/16/wi-umbrella.svg
                                                    // Falls back to symbolic if theme has no SVG folder
                                                    source: {
                                                        var th = forecastRoot.widgetIconTheme
                                                        if (th === "kde" || th === "wi-font") th = "symbolic"
                                                        return forecastRoot.iconsBaseDir + th + "/16/wi-umbrella.svg"
                                                    }
                                                    isMask: true
                                                    color:  "#5ea8ff"
                                                    width: 14; height: 14
                                                    Layout.alignment: Qt.AlignVCenter
                                                }
                                                Label {
                                                    text: {
                                                        var pp = modelData.precipProb
                                                        if (pp !== undefined && pp !== null && !isNaN(pp))
                                                            return Math.round(pp) + "%"
                                                        var h = modelData.humidity
                                                        return (!isNaN(h) && h !== undefined) ? Math.round(h) + "%" : "--"
                                                    }
                                                    color: "#5ea8ff"
                                                    font: weatherRoot ? weatherRoot.wf(9, false) : Qt.font({})
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        width: parent.width; height: 1
                        // #3
                        color: Qt.rgba(Kirigami.Theme.textColor.r,
                                       Kirigami.Theme.textColor.g,
                                       Kirigami.Theme.textColor.b, 0.08)
                    }
                }
            }
        }
    }
}
