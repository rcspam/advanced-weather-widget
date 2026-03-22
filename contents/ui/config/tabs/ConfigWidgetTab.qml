/**
 * ConfigWidgetTab.qml — Widget (details) tab content
 *
 * Extracted from configAppearance.qml for readability.
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: widgetTab

    /** Reference to the root KCM (configAppearance) for cfg_* properties */
    required property var configRoot

    /** Emitted when the user clicks Configure… to push the details sub-page */
    signal pushSubPage()

    Kirigami.Separator {
        Kirigami.FormData.label: i18n("Widget settings")
        Kirigami.FormData.isSection: true
    }
    SpinBox {
        Kirigami.FormData.label: i18n("Forecast days:")
        from: 3
        to: 7
        value: widgetTab.configRoot.cfg_forecastDays
        onValueModified: widgetTab.configRoot.cfg_forecastDays = value
    }
    CheckBox {
        Kirigami.FormData.label: i18n("Footer:")
        text: i18n("Show update time and provider")
        checked: widgetTab.configRoot.cfg_showUpdateText
        onToggled: widgetTab.configRoot.cfg_showUpdateText = checked
    }

    // ── Widget items ──────────────────────────────────────
    Kirigami.Separator {
        Kirigami.FormData.label: i18n("Widget items")
        Kirigami.FormData.isSection: true
    }

    // ── Widget icon theme selector ────────────────────────
    RowLayout {
        Kirigami.FormData.label: i18n("Icon theme:")
        spacing: Kirigami.Units.largeSpacing
        ComboBox {
            id: widgetIconThemeCombo
            Layout.preferredWidth: 200
            textRole: "text"
            model: [
                {
                    text: i18n("Symbolic (SVG)"),
                    value: "symbolic"
                },
                {
                    text: i18n("Flat Color (SVG)"),
                    value: "flat-color"
                },
                {
                    text: i18n("3D Oxygen (SVG)"),
                    value: "3d-oxygen"
                }
            ]
            Component.onCompleted: {
                var theme = widgetTab.configRoot.cfg_widgetIconTheme;
                if (theme === "kde" || theme === "wi-font") {
                    theme = "symbolic";
                    widgetTab.configRoot.cfg_widgetIconTheme = "symbolic";
                }
                for (var i = 0; i < model.length; ++i)
                    if (model[i].value === theme) {
                        currentIndex = i;
                        break;
                    }
                if (currentIndex < 0)
                    currentIndex = 0;
            }
            onActivated: widgetTab.configRoot.cfg_widgetIconTheme = model[currentIndex].value
        }
    }

    // ── Widget icon size (shown for SVG themes) ───────────
    RowLayout {
        Kirigami.FormData.label: i18n("Icon size:")
        spacing: Kirigami.Units.largeSpacing
        ComboBox {
            id: widgetIconSizeCombo
            Layout.preferredWidth: 120
            textRole: "text"
            model: [
                {
                    text: "16 px",
                    value: 16
                },
                {
                    text: "22 px",
                    value: 22
                },
                {
                    text: "24 px",
                    value: 24
                },
                {
                    text: "32 px",
                    value: 32
                }
            ]
            Component.onCompleted: {
                for (var i = 0; i < model.length; ++i)
                    if (model[i].value === widgetTab.configRoot.cfg_widgetIconSize) {
                        currentIndex = i;
                        break;
                    }
                if (currentIndex < 0)
                    currentIndex = 0;
            }
            onActivated: widgetTab.configRoot.cfg_widgetIconSize = model[currentIndex].value
        }
    }

    // ── Details layout: Cards (2-col) or List (1-col flat) ──
    RowLayout {
        Kirigami.FormData.label: i18n("Details layout:")
        ComboBox {
            id: detailsLayoutCombo
            Layout.preferredWidth: 160
            textRole: "text"
            model: [
                { text: i18n("Cards (2 columns)"), value: "cards2" },
                { text: i18n("List"),              value: "list"   }
            ]
            currentIndex: widgetTab.configRoot.cfg_widgetDetailsLayout === "list" ? 1 : 0
            onActivated: widgetTab.configRoot.cfg_widgetDetailsLayout = model[currentIndex].value
        }
    }

    // ── Cards height (hidden in list mode) ────────────────
    RowLayout {
        visible: widgetTab.configRoot.cfg_widgetDetailsLayout !== "list"
        Kirigami.FormData.label: i18n("Cards height:")
        spacing: Kirigami.Units.largeSpacing
        ComboBox {
            id: cardsHeightModeCombo
            Layout.preferredWidth: 130
            textRole: "text"
            model: [
                {
                    text: i18n("Auto"),
                    value: true
                },
                {
                    text: i18n("Manual"),
                    value: false
                }
            ]
            currentIndex: widgetTab.configRoot.cfg_widgetCardsHeightAuto ? 0 : 1
            onActivated: {
                var newMode = model[currentIndex].value;
                if (widgetTab.configRoot.cfg_widgetCardsHeightAuto !== newMode) {
                    widgetTab.configRoot.cfg_widgetCardsHeightAuto = newMode;
                }
            }
        }
        SpinBox {
            enabled: !widgetTab.configRoot.cfg_widgetCardsHeightAuto
            from: 30
            to: 120
            value: widgetTab.configRoot.cfg_widgetCardsHeight
            onValueModified: widgetTab.configRoot.cfg_widgetCardsHeight = value
        }
        Label {
            visible: !widgetTab.configRoot.cfg_widgetCardsHeightAuto
            text: "px"
            opacity: 0.65
        }
    }

    // Details items configurator (enable/disable, no drag)
    Item {
        Kirigami.FormData.label: i18n("Details items:")
        implicitWidth: detailsPreviewRow.implicitWidth
        implicitHeight: detailsPreviewRow.implicitHeight
        RowLayout {
            id: detailsPreviewRow
            spacing: 10
            Flow {
                spacing: 4
                Layout.maximumWidth: 260
                Repeater {
                    model: widgetTab.configRoot.cfg_widgetDetailsOrder.split(";").filter(function (t) {
                        return t.length > 0;
                    })
                    delegate: Rectangle {
                        radius: 3
                        color: Qt.rgba(1, 1, 1, 0.10)
                        border.color: Qt.rgba(1, 1, 1, 0.22)
                        border.width: 1
                        implicitWidth: detailChipLbl.implicitWidth + 10
                        implicitHeight: detailChipLbl.implicitHeight + 6
                        Label {
                            id: detailChipLbl
                            anchors.centerIn: parent
                            text: {
                                var d = modelData.trim();
                                for (var i = 0; i < widgetTab.configRoot.allDetailsDefs.length; ++i)
                                    if (widgetTab.configRoot.allDetailsDefs[i].itemId === d)
                                        return widgetTab.configRoot.allDetailsDefs[i].label;
                                return d;
                            }
                        }
                    }
                }
            }
            Button {
                text: i18n("Configure\u2026")
                icon.name: "configure"
                onClicked: {
                    widgetTab.configRoot.initDetailsModel();
                    widgetTab.pushSubPage();
                }
            }
        }
    }
}
