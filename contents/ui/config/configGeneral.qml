import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: root

    // ── Config properties ─────────────────────────────────────────────────
    property string cfg_weatherProvider: "adaptive"
    property string cfg_owApiKey: ""
    property string cfg_waApiKey: ""
    property bool cfg_autoRefresh: true
    property int cfg_refreshIntervalMinutes: 15

    // ── Legacy props — keep bound so KCM doesn't lose them ────────────────
    property bool cfg_showScrollbox: true
    property int cfg_scrollboxLines: 2
    property string cfg_scrollboxItems: "Humidity;Wind;Pressure;Dew Point;Visibility"
    property bool cfg_animateTransitions: true

    // ── Derived state ─────────────────────────────────────────────────────
    readonly property bool isAdaptive: cfg_weatherProvider === "adaptive"
    readonly property bool isOpenWeather: cfg_weatherProvider === "openWeather"
    readonly property bool isWeatherApi: cfg_weatherProvider === "weatherApi"
    readonly property bool needsKeyUi: isOpenWeather || isWeatherApi

    // ── API key test state ────────────────────────────────────────────────
    // 0 = idle, 1 = testing, 2 = success, 3 = error
    property int apiTestState: 0
    property string apiTestMessage: ""

    // ── Provider location check state ───────────────────────────────────
    // 0 = idle, 1 = checking, 2 = ok, 3 = error
    property int locationCheckState: 0
    property string locationCheckMessage: ""

    function verifyProviderLocation() {
        var lat = Plasmoid.configuration.latitude;
        var lon = Plasmoid.configuration.longitude;
        if (!lat && !lon) {
            locationCheckState = 0;
            return;
        }
        var provider = cfg_weatherProvider;
        if (provider === "adaptive" || provider === "openMeteo") {
            locationCheckState = 0;
            return;  // Open-Meteo/adaptive always works
        }
        locationCheckState = 1;
        locationCheckMessage = i18n("Checking location availability…");

        var req = new XMLHttpRequest();
        var url;
        if (provider === "openWeather") {
            var owKey = (cfg_owApiKey || "").trim();
            if (!owKey) { locationCheckState = 0; return; }
            url = "https://api.openweathermap.org/data/2.5/weather?lat="
                + encodeURIComponent(lat) + "&lon=" + encodeURIComponent(lon)
                + "&units=metric&appid=" + encodeURIComponent(owKey);
        } else if (provider === "weatherApi") {
            var waKey = (cfg_waApiKey || "").trim();
            if (!waKey) { locationCheckState = 0; return; }
            url = "https://api.weatherapi.com/v1/current.json?key="
                + encodeURIComponent(waKey)
                + "&q=" + encodeURIComponent(lat + "," + lon);
        } else if (provider === "metno") {
            url = "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat="
                + encodeURIComponent(lat) + "&lon=" + encodeURIComponent(lon);
        } else {
            locationCheckState = 0;
            return;
        }
        req.open("GET", url);
        if (provider === "metno")
            req.setRequestHeader("User-Agent",
                "AdvancedWeatherWidget/1.0 github.com/pnedyalkov91/advanced-weather-widget");
        req.onreadystatechange = function () {
            if (req.readyState !== XMLHttpRequest.DONE)
                return;
            var pLabel = root.providerDisplayName(provider);
            if (req.status === 200) {
                locationCheckState = 2;
                locationCheckMessage = i18n("Location is available on %1.", pLabel);
            } else {
                locationCheckState = 3;
                locationCheckMessage = i18n("Location is not available on %1 (HTTP %2). Try a different provider or location.", pLabel, req.status);
            }
        };
        req.send();
    }

    function providerDisplayName(p) {
        if (p === "openWeather") return "OpenWeatherMap";
        if (p === "weatherApi") return "WeatherAPI.com";
        if (p === "metno") return "met.no";
        return "Open-Meteo";
    }

    function testApiKey() {
        var key = apiKeyField.text.trim();
        if (!key) {
            apiTestState = 3;
            apiTestMessage = i18n("API key is empty.");
            return;
        }
        apiTestState = 1;
        apiTestMessage = i18n("Testing connection…");

        var req = new XMLHttpRequest();
        var url;
        if (root.isOpenWeather) {
            url = "https://api.openweathermap.org/data/2.5/weather?lat=42.7&lon=23.3&units=metric&appid="
                + encodeURIComponent(key);
        } else {
            url = "https://api.weatherapi.com/v1/current.json?key="
                + encodeURIComponent(key) + "&q=42.7,23.3";
        }
        req.open("GET", url);
        req.onreadystatechange = function () {
            if (req.readyState !== XMLHttpRequest.DONE)
                return;
            if (req.status === 200) {
                apiTestState = 2;
                apiTestMessage = root.isOpenWeather
                    ? i18n("Connection successful! OpenWeatherMap key is valid.")
                    : i18n("Connection successful! WeatherAPI.com key is valid.");
                root.verifyProviderLocation();
            } else if (req.status === 401 || req.status === 403) {
                apiTestState = 3;
                apiTestMessage = i18n("Invalid API key. Please check and try again.");
            } else {
                apiTestState = 3;
                apiTestMessage = i18n("Connection failed (HTTP %1).", req.status);
            }
        };
        req.send();
    }

    // Providers without Adaptive — Adaptive is handled by the switch above
    readonly property var providerModel: [
        {
            text: i18n("Open-Meteo (recommended, free)"),
            value: "openMeteo"
        },
        {
            text: i18n("met.no (free)"),
            value: "metno"
        },
        {
            text: i18n("OpenWeatherMap (Key Required)"),
            value: "openWeather"
        },
        {
            text: i18n("WeatherAPI.com (Key Required)"),
            value: "weatherApi"
        }
    ]

    function providerIndexFor(val) {
        for (var i = 0; i < providerModel.length; ++i)
            if (providerModel[i].value === val)
                return i;
        return 0;
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 12

            // ══════════════════════════════════════════════════════════════
            // SECTION: Adaptive Mode
            // ══════════════════════════════════════════════════════════════
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                // Section header
                RowLayout {
                    Layout.fillWidth: true
                    Kirigami.Heading {
                        text: i18n("Weather Provider")
                        level: 4
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Kirigami.Theme.separatorColor
                        opacity: 0.5
                    }
                }

                Item {
                    Layout.preferredHeight: 8
                }

                // Adaptive toggle row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Switch {
                        id: adaptiveSwitch
                        checked: root.isAdaptive
                        onToggled: {
                            if (checked) {
                                root.cfg_weatherProvider = "adaptive";
                            } else {
                                // Fall back to Open-Meteo when disabling adaptive
                                root.cfg_weatherProvider = "openMeteo";
                                providerCombo.currentIndex = root.providerIndexFor("openMeteo");
                            }
                        }
                    }
                    Label {
                        text: i18n("Adaptive (auto-fallback)")
                        font.bold: true
                        verticalAlignment: Text.AlignVCenter
                        MouseArea {
                            anchors.fill: parent
                            onClicked: adaptiveSwitch.toggle()
                        }
                    }
                }

                // Adaptive description — shown only when Adaptive is ON
                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    visible: root.isAdaptive
                    type: Kirigami.MessageType.Information
                    text: i18n("Providers are tried in order until one succeeds:\nOpen-Meteo  →  met.no  →  OpenWeatherMap  →  WeatherAPI.com\nOpen-Meteo is always tried first — it is free and requires no API key.")
                }

                Item {
                    Layout.preferredHeight: 8
                }

                // Manual provider selector — hidden when Adaptive is ON
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: !root.isAdaptive

                    Label {
                        text: i18n("Provider:")
                        opacity: 0.75
                    }

                    ComboBox {
                        id: providerCombo
                        Layout.preferredWidth: 280
                        model: root.providerModel
                        textRole: "text"
                        currentIndex: root.providerIndexFor(root.cfg_weatherProvider)
                        onActivated: {
                            root.cfg_weatherProvider = root.providerModel[currentIndex].value;
                            root.apiTestState = 0;
                            root.locationCheckState = 0;
                            root.verifyProviderLocation();
                        }
                    }

                    // Provider sub-label
                    Label {
                        visible: root.isAdaptive === false
                        opacity: 0.6
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        textFormat: Text.RichText
                        onLinkActivated: function(link) { Qt.openUrlExternally(link) }
                        text: {
                            if (root.isOpenWeather)
                                return i18n("Standard provider. API key required below.") + "<br/>" + i18n("Provider website:") + " <a href='https://openweathermap.org'>openweathermap.org</a>";
                            if (root.isWeatherApi)
                                return i18n("Alternative provider. API key required below.") + "<br/>" + i18n("Provider website:") + " <a href='https://www.weatherapi.com'>weatherapi.com</a>";
                            if (root.cfg_weatherProvider === "metno")
                                return i18n("Free Norwegian Meteorological Institute service. No API key needed.") + "<br/>" + i18n("Provider website:") + " <a href='https://met.no'>met.no</a>";
                            return i18n("Free and open-source. No API key needed. Recommended.") + "<br/>" + i18n("Provider website:") + " <a href='https://open-meteo.com'>open-meteo.com</a>";
                        }
                        HoverHandler {
                            cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                        }
                    }

                    Kirigami.InlineMessage {
                        Layout.fillWidth: true
                        visible: root.locationCheckState === 2
                        type: Kirigami.MessageType.Positive
                        text: root.locationCheckMessage
                    }

                    Kirigami.InlineMessage {
                        Layout.fillWidth: true
                        visible: root.locationCheckState === 3
                        type: Kirigami.MessageType.Error
                        text: root.locationCheckMessage
                    }
                }

                // ── API Key section ───────────────────────────────────────
                // Shown only when OpenWeather or WeatherAPI is selected
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    spacing: 8
                    visible: root.needsKeyUi && !root.isAdaptive

                    Label {
                        text: root.isOpenWeather ? i18n("OpenWeatherMap API Key:") : i18n("WeatherAPI.com API Key:")
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            id: apiKeyField
                            Layout.fillWidth: true
                            placeholderText: root.isOpenWeather ? i18n("Enter your OpenWeatherMap API key") : i18n("Enter your WeatherAPI.com key")
                            text: root.isOpenWeather ? root.cfg_owApiKey : root.cfg_waApiKey
                            echoMode: TextInput.Password
                            selectByMouse: true
                            onTextEdited: {
                                root.apiTestState = 0;
                                if (root.isOpenWeather)
                                    root.cfg_owApiKey = text;
                                else
                                    root.cfg_waApiKey = text;
                            }
                            onEditingFinished: {
                                if (root.isOpenWeather)
                                    root.cfg_owApiKey = text.trim();
                                else
                                    root.cfg_waApiKey = text.trim();
                            }
                        }

                        ToolButton {
                            icon.name: "view-visible"
                            checkable: true
                            onCheckedChanged: apiKeyField.echoMode = checked ? TextInput.Normal : TextInput.Password
                            ToolTip.text: i18n("Show/hide key")
                            ToolTip.visible: hovered
                        }

                        Button {
                            text: i18n("Clear")
                            icon.name: "edit-clear"
                            visible: apiKeyField.text.length > 0
                            onClicked: {
                                apiKeyField.text = "";
                                root.apiTestState = 0;
                                if (root.isOpenWeather)
                                    root.cfg_owApiKey = "";
                                else
                                    root.cfg_waApiKey = "";
                            }
                        }

                        Button {
                            text: root.apiTestState === 1 ? i18n("Testing…") : i18n("Test API Key")
                            icon.name: "network-connect"
                            enabled: apiKeyField.text.trim().length > 0 && root.apiTestState !== 1
                            onClicked: root.testApiKey()
                        }
                    }

                    Kirigami.InlineMessage {
                        Layout.fillWidth: true
                        visible: root.needsKeyUi && !root.isAdaptive && apiKeyField.text.trim().length === 0
                        type: Kirigami.MessageType.Warning
                        text: root.isOpenWeather
                            ? i18n("An API key is required for OpenWeatherMap. Weather data cannot be retrieved without it.")
                            : i18n("An API key is required for WeatherAPI.com. Weather data cannot be retrieved without it.")
                    }

                    Kirigami.InlineMessage {
                        Layout.fillWidth: true
                        visible: root.apiTestState === 2
                        type: Kirigami.MessageType.Positive
                        text: root.apiTestMessage
                    }

                    Kirigami.InlineMessage {
                        Layout.fillWidth: true
                        visible: root.apiTestState === 3
                        type: Kirigami.MessageType.Error
                        text: root.apiTestMessage
                    }
                }
            }

            // ══════════════════════════════════════════════════════════════
            // SECTION: Data Refresh
            // ══════════════════════════════════════════════════════════════
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Kirigami.Heading {
                        text: i18n("Data Refresh")
                        level: 4
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Kirigami.Theme.textColor
                        opacity: 0.5
                    }
                }

                Item {
                    Layout.preferredHeight: 4
                }

                CheckBox {
                    text: i18n("Refresh weather automatically")
                    checked: root.cfg_autoRefresh
                    onToggled: root.cfg_autoRefresh = checked
                }

                RowLayout {
                    spacing: 8
                    enabled: root.cfg_autoRefresh
                    opacity: root.cfg_autoRefresh ? 1.0 : 0.5

                    Label {
                        text: i18n("Interval:")
                    }
                    SpinBox {
                        from: 5
                        to: 180
                        value: root.cfg_refreshIntervalMinutes
                        onValueModified: root.cfg_refreshIntervalMinutes = value
                    }
                    Label {
                        text: i18n("minutes")
                    }
                }
            }

            Item {
                Layout.preferredHeight: 16
            }
        }
    }
}
