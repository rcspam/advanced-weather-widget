import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// How to read the animation's layers, in a panel that slides in from the
// right. The layers shown now come first and are marked; the others follow
// in the order of the bar.
QQC2.Drawer {
    id: panel
    property string iconsDir          // the flat-color icons of the bar
    property var layers: ({})         // window.animState().layers
    property var choices: ({})        // layer id: the [value, text] pairs of its list

    edge: Qt.RightEdge
    width: Math.min(400, parent ? parent.width * 0.85 : 400)
    height: parent ? parent.height : 600
    dim: false
    modal: false
    closePolicy: QQC2.Popup.CloseOnEscape

    // id: the page's layer (several for a group), icon: in iconsDir or a file: URL.
    readonly property var sections: [
        { ids: ["wind"], icon: "wi-strong-wind.svg", title: "Wind",
          range: "Up to 6 days ahead and about 7 days back (Open-Meteo deletes older forecast files).",
          text: "The lines flow with the wind. Their color is the speed, from your wind palette: by default white when calm, green and blue for a breeze, yellow and orange for a strong wind, red and violet for a storm. The list next to the button picks the height: 10 m is the wind you feel, shaped by the relief; 700 hPa (about 3000 m) is the flow that carries the clouds and the rain, stronger and smoother. Watch where the lines bunch up and turn: that is where the weather changes." },
        { ids: ["temperature"], icon: "wi-thermometer.svg", title: "Temperature",
          range: "Up to 6 days ahead and about 7 days back (Open-Meteo deletes older forecast files).",
          text: "Air temperature at 2 m, in the bands of the legend. Play a whole day to see the land warm up in the afternoon and cool down at night, while the sea hardly changes. A sharp edge that moves is a front." },
        { ids: ["precipitation"], icon: "wi-rain.svg", title: "Precipitation",
          range: "Up to 6 days ahead and about 7 days back (Open-Meteo deletes older forecast files).",
          text: "What falls in the three hours around the time shown, in mm per hour. Each kind has its colors: rain from blue to green, yellow, red and magenta as it gets heavier; snow in lilac and violet; the dangerous ones (freezing rain, freezing drizzle, ice pellets) in colors of their own. Pick the kinds in the list next to the button. Under 0.05 mm/h nothing is drawn." },
        { ids: ["clouds"], icon: "wi-cloudy.svg", title: "Clouds",
          range: "Up to 6 days ahead and about 7 days back (Open-Meteo deletes older forecast files).",
          text: "White is cloud: the whiter, the more of the sky it covers. Low clouds (under about 2 km) make grey days, fog and drizzle. Mid clouds (2 to 6 km) often come before rain. High clouds (above 6 km) are thin veils of ice: the sun still gets through. With all three levels ticked you see the total cover as the model counts it, without counting twice the clouds that sit over each other." },
        { ids: ["pressure", "isobars"], icon: "wi-barometer.svg", title: "Pressure and isobars",
          range: "Up to 6 days ahead and about 7 days back (Open-Meteo deletes older forecast files).",
          text: "Air pressure brought to sea level, in hPa. Blue and purple are lows: clouds, rain and wind. Orange and red are highs: settled weather, fog in winter. The isobars join the points of equal pressure, every 4 hPa. The wind blows almost along them, counterclockwise around a low in the northern hemisphere. The closer the lines, the stronger the wind." },
        { ids: ["humidity"], icon: "wi-humidity.svg", title: "Humidity",
          range: "Up to 6 days ahead and about 7 days back (Open-Meteo deletes older forecast files).",
          text: "Relative humidity at 2 m: how close the air is to being saturated with water. Brown is dry (under 30 %: dry skin, fire risk), sand and green are usual, blue is near 100 % (fog, low clouds, rain). It goes up at night and down in the afternoon even when the air keeps the same water, because warm air can hold more: for the water itself, look at the dew point." },
        { ids: ["dewpoint"], icon: "wi-dew-point.svg", title: "Dew point",
          range: "Up to 6 days ahead and about 7 days back (Open-Meteo deletes older forecast files).",
          text: "The temperature the air would have to cool to for dew to form. It tells how much water the air really holds, and how muggy it feels. Under 10 °C the air feels dry, 13 to 16 °C you notice it, from 18 °C it is muggy, from 21 °C oppressive, and from 24 °C tropical. When the night temperature falls to the dew point, dew or fog forms." },
        { ids: ["airquality"], icon: "wi-smoke.svg", title: "Air quality",
          range: "Up to 5 days ahead only: the CAMS forecast stops there, later pictures stay empty. About 7 days back.",
          text: "The CAMS forecast for the pollutant chosen in the list. The colors follow the bands of the European Air Quality Index: cyan good, green fair, yellow moderate, red poor, dark red very poor, purple extremely poor. Dust shows Saharan dust, AOD how hazy the air is (smoke, dust), UV the UV index of the day. The scale is logarithmic: each band covers a wider range than the one before." }
    ]
    function isOn(s) { return s.ids.some(function (id) { return !!panel.layers[id]; }); }
    readonly property var ordered: sections.filter(isOn).concat(sections.filter(function (s) { return !isOn(s); }))

    background: Rectangle {
        color: Kirigami.Theme.backgroundColor
        Rectangle { width: 1; height: parent.height; color: Kirigami.Theme.disabledTextColor; opacity: 0.4 }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            Kirigami.Heading {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                level: 3
                text: "Reading the animation"
            }
            QQC2.ToolButton {
                icon.name: "window-close"
                focusPolicy: Qt.NoFocus
                onClicked: panel.close()
            }
        }
        QQC2.ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            ColumnLayout {
                width: scroll.availableWidth
                spacing: Kirigami.Units.largeSpacing
                Repeater {
                    model: panel.ordered
                    ColumnLayout {
                        required property var modelData
                        readonly property bool on: panel.isOn(modelData)
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing
                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            Kirigami.Icon {
                                implicitWidth: 22
                                implicitHeight: 22
                                roundToIconSize: false
                                source: panel.iconsDir + modelData.icon
                            }
                            QQC2.Label {
                                text: modelData.title
                                font.bold: true
                            }
                            QQC2.Label {
                                visible: on
                                text: "shown"
                                color: Kirigami.Theme.highlightColor
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                            }
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            opacity: on ? 1.0 : 0.75
                            text: modelData.text
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            opacity: 0.7
                            font.italic: true
                            text: modelData.range
                        }
                        // The choices of the layer's list, in the order of the list.
                        QQC2.Label {
                            readonly property var list: panel.choices[modelData.ids[0]] || []
                            visible: list.length > 0
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: Kirigami.Theme.linkColor
                            font.italic: true
                            text: list.map(function (c) { return c[1]; }).join(", ")
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    Layout.bottomMargin: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.smallSpacing
                    QQC2.Label { text: "Time bar and keys"; font.bold: true }
                    QQC2.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: "The range lists (back and ahead) apply to every layer; a layer stops where its data stops. A green dot is a picture straight from a forecast file, an orange one is worked out between two of them. Space plays or pauses, the arrows move one hour, Page Up and Page Down jump to the previous or next file. Hold Ctrl over the map to read the values under the pointer. The wheel over the button of a layer that is on sets its opacity. The loop button at the end of the time bar plays round again from the start, or stops on the last picture. Esc closes this panel."
                    }
                }
            }
        }
    }
}
