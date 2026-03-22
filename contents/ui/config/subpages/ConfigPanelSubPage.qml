/**
 * ConfigPanelSubPage — extracted from configAppearance.qml
 * Requires: required property var configRoot
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform as Platform
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as KIconThemes

ColumnLayout {
    required property var configRoot

    id: panelSubPageRoot
    spacing: 0
    // Snapshot state captured when sub-page opens — used to restore on Discard
    property string _savedOrder: configRoot.cfg_panelItemOrder
    property string _savedIcons: configRoot.cfg_panelItemIcons

    Dialog {
        id: panelLeaveDialog
        title: i18n("Apply Settings?")
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        standardButtons: Dialog.NoButton
        Label {
            text: i18n("Keep the changes you made to Panel Items?")
            wrapMode: Text.WordWrap
        }
        footer: DialogButtonBox {
            Button {
                text: i18n("Keep Changes")
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
                onClicked: {
                    panelLeaveDialog.accept();
                    stack.pop();
                }
            }
            Button {
                text: i18n("Discard")
                DialogButtonBox.buttonRole: DialogButtonBox.DestructiveRole
                onClicked: {
                    configRoot.cfg_panelItemOrder = panelSubPageRoot._savedOrder;
                    configRoot.cfg_panelItemIcons = panelSubPageRoot._savedIcons;
                    panelLeaveDialog.close();
                    stack.pop();
                }
            }
            Button {
                text: i18n("Cancel")
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
                onClicked: panelLeaveDialog.close()
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        Layout.leftMargin: 4
        Layout.rightMargin: 8
        Layout.bottomMargin: 4
        spacing: 4
        Button {
            icon.name: "go-previous"
            text: i18n("Back")
            flat: true
            onClicked: {
                // Show confirm if anything changed from the snapshot
                if (configRoot.cfg_panelItemOrder !== panelSubPageRoot._savedOrder || configRoot.cfg_panelItemIcons !== panelSubPageRoot._savedIcons)
                    panelLeaveDialog.open();
                else
                    stack.pop();
            }
        }
        Label {
            Layout.fillWidth: true
            text: i18n("Panel Items")
            font.bold: true
        }
    }
    Kirigami.Separator {
        Layout.fillWidth: true
    }
    ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: availableWidth
        ListView {
            id: panelItemList
            width: parent.width
            implicitHeight: contentHeight
            clip: true
            spacing: 0
            model: panelWorkingModel
            highlightMoveDuration: Kirigami.Units.longDuration
            displaced: Transition {
                YAnimator {
                    duration: Kirigami.Units.longDuration
                }
            }
            section.property: "itemEnabled"
            section.criteria: ViewSection.FullString
            section.delegate: Kirigami.ListSectionHeader {
                required property string section
                width: panelItemList.width
                label: section === "true" ? i18n("Enabled") : i18n("Available")
            }
            delegate: Item {
                id: panelDelegateRoot
                property bool settingsExpanded: false
                width: panelItemList.width
                implicitHeight: panelDelegateCol.implicitHeight
                ColumnLayout {
                    id: panelDelegateCol
                    spacing: 0
                    width: parent.width
                    ItemDelegate {
                        id: panelRowDelegate
                        Layout.fillWidth: true
                        hoverEnabled: true
                        down: false
                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            Kirigami.ListItemDragHandle {
                                listItem: panelRowDelegate
                                listView: panelItemList
                                enabled: model.itemEnabled
                                opacity: model.itemEnabled ? 1.0 : 0.0
                                onMoveRequested: function (oldIndex, newIndex) {
                                    var boundary = configRoot.firstPanelDisabledIndex();
                                    var clamped = (boundary < 0) ? newIndex : Math.min(newIndex, boundary - 1);
                                    if (clamped !== oldIndex)
                                        panelWorkingModel.move(oldIndex, clamped, 1);
                                }
                                onDropped: configRoot.applyPanelItems()
                            }
                            // Icon — mirrors the active panel icon theme so
                            // the preview matches what appears on the panel.
                            Item {
                                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                                implicitHeight: Kirigami.Units.iconSizes.smallMedium
                                opacity: model.itemEnabled ? 1.0 : 0.35

                                // wi-font char (default theme)
                                Text {
                                    anchors.centerIn: parent
                                    text: model.itemWiChar
                                    font.family: configRoot.wiFontReady ? configRoot.wiFontFamily : ""
                                    font.pixelSize: Kirigami.Units.iconSizes.smallMedium - 2
                                    color: Kirigami.Theme.textColor
                                    visible: configRoot.cfg_panelIconTheme === "wi-font" && model.itemWiChar.length > 0 && configRoot.wiFontReady
                                }
                                // Kirigami fallback for wi-font (no char) or KDE theme
                                Kirigami.Icon {
                                    anchors.fill: parent
                                    source: model.itemFallback
                                    visible: (configRoot.cfg_panelIconTheme === "wi-font" && (model.itemWiChar.length === 0 || !configRoot.wiFontReady)) || configRoot.cfg_panelIconTheme === "kde"
                                    // "custom" has its own preview block below
                                }
                                // SVG theme icon (symbolic / flat-color / 3d-oxygen)
                                Kirigami.Icon {
                                    anchors.fill: parent
                                    visible: configRoot.cfg_panelIconTheme !== "wi-font" && configRoot.cfg_panelIconTheme !== "kde" && configRoot.cfg_panelIconTheme !== "custom" && configRoot.cfg_panelIconTheme.length > 0
                                    source: {
                                        var th = configRoot.cfg_panelIconTheme;
                                        if (!th || th === "wi-font" || th === "kde" || th === "custom")
                                            return "";
                                        var sz = configRoot.cfg_panelIconSize || 22;
                                        var b = configRoot.iconsBase + th + "/" + sz + "/wi-";
                                        var id = model.itemId;
                                        if (id === "temperature" || id === "feelslike")
                                            return b + "thermometer.svg";
                                        if (id === "humidity")
                                            return b + "humidity.svg";
                                        if (id === "pressure")
                                            return b + "barometer.svg";
                                        if (id === "wind")
                                            return b + "strong-wind.svg";
                                        if (id === "suntimes")
                                            return b + "sunrise.svg";
                                        if (id === "moonphase")
                                            return b + "moon-alt-full.svg";
                                        if (id === "condition")
                                            return b + "day-cloudy.svg";
                                        if (id === "location")
                                            return b + "wind-deg.svg";
                                        return "";
                                    }
                                    isMask: configRoot.cfg_panelIconTheme === "symbolic"
                                    color: Kirigami.Theme.textColor
                                }
                                // Custom theme: show the saved custom icon (falls back to KDE default)
                                // For condition: always show weather-clear (or saved condition-clear) as preview
                                Kirigami.Icon {
                                    anchors.fill: parent
                                    visible: configRoot.cfg_panelIconTheme === "custom"
                                    source: {
                                        var _w = configRoot.cfg_panelCustomIcons;
                                        if (model.itemId === "condition") {
                                            var m = configRoot.parseCustomIcons(configRoot.cfg_panelCustomIcons);
                                            return ("condition-clear" in m && m["condition-clear"].length > 0) ? m["condition-clear"] : "weather-clear";
                                        }
                                        var saved = configRoot.getCustomIcon(model.itemId);
                                        return saved.length > 0 ? saved : model.itemFallback;
                                    }
                                }
                            }
                            // Labels
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Label {
                                    Layout.fillWidth: true
                                    text: model.itemLabel
                                    elide: Text.ElideRight
                                    opacity: model.itemEnabled ? 1.0 : 0.55
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: model.itemDesc
                                    font: Kirigami.Theme.smallFont
                                    elide: Text.ElideRight
                                    opacity: 0.55
                                }
                            }
                            // Sun times gear (only in non-custom themes — custom uses the configure dialog)
                            ToolButton {
                                visible: model.itemId === "suntimes" && configRoot.cfg_panelIconTheme !== "custom"
                                enabled: model.itemEnabled
                                opacity: model.itemEnabled ? 1.0 : 0.3
                                implicitWidth: Kirigami.Units.iconSizes.medium
                                implicitHeight: Kirigami.Units.iconSizes.medium
                                icon.name: "configure"
                                checkable: true
                                checked: panelDelegateRoot.settingsExpanded
                                ToolTip.visible: hovered
                                ToolTip.text: i18n("Sun times options")
                                onClicked: panelDelegateRoot.settingsExpanded = !panelDelegateRoot.settingsExpanded
                            }
                            // Configure icon button (custom theme only) — opens the icon-config dialog
                            ToolButton {
                                visible: configRoot.cfg_panelIconTheme === "custom"
                                enabled: model.itemEnabled
                                opacity: model.itemEnabled ? 1.0 : 0.3
                                implicitWidth: Kirigami.Units.iconSizes.medium
                                implicitHeight: Kirigami.Units.iconSizes.medium
                                icon.name: "color-picker"
                                ToolTip.visible: hovered
                                ToolTip.text: i18n("Configure icon…")
                                onClicked: {
                                    if (model.itemId === "condition") {
                                        conditionIconDialog.openWithContext("panel");
                                    } else {
                                        iconConfigDialog.context = "panel";
                                        iconConfigDialog.itemId = model.itemId;
                                        iconConfigDialog.itemLabel = model.itemLabel;
                                        iconConfigDialog.itemFallback = model.itemFallback;
                                        iconConfigDialog.isSuntimes = (model.itemId === "suntimes");
                                        for (var i = 0; i < sunModeDialogCombo.model.length; ++i)
                                            if (sunModeDialogCombo.model[i].value === configRoot.cfg_panelSunTimesMode) {
                                                sunModeDialogCombo.currentIndex = i;
                                                break;
                                            }
                                        iconConfigDialog.open();
                                    }
                                }
                            }
                            // Eye toggle
                            ToolButton {
                                implicitWidth: Kirigami.Units.iconSizes.medium
                                implicitHeight: Kirigami.Units.iconSizes.medium
                                enabled: model.itemEnabled
                                opacity: model.itemEnabled ? 1.0 : 0.25
                                icon.name: model.itemShowIcon ? "view-visible" : "view-hidden"
                                ToolTip.visible: hovered
                                ToolTip.text: model.itemShowIcon ? i18n("Hide prefix icon") : i18n("Show prefix icon")
                                onClicked: {
                                    panelWorkingModel.setProperty(model.index, "itemShowIcon", !model.itemShowIcon);
                                    configRoot.applyPanelItems();
                                }
                            }
                            // Enable/disable (font-enable / font-disable)
                            ToolButton {
                                implicitWidth: Kirigami.Units.iconSizes.medium
                                implicitHeight: Kirigami.Units.iconSizes.medium
                                icon.name: model.itemEnabled ? "font-enable" : "font-disable"
                                ToolTip.visible: hovered
                                ToolTip.text: model.itemEnabled ? i18n("Disable item") : i18n("Enable item")
                                onClicked: {
                                    var idx = model.index;
                                    var nowOn = !model.itemEnabled;
                                    if (!nowOn)
                                        panelDelegateRoot.settingsExpanded = false;
                                    panelWorkingModel.setProperty(idx, "itemEnabled", nowOn);
                                    var boundary = configRoot.firstPanelDisabledIndex();
                                    if (nowOn) {
                                        if (boundary > 0 && idx >= boundary)
                                            panelWorkingModel.move(idx, boundary - 1, 1);
                                    } else {
                                        var lastEnabled = -1;
                                        for (var i = 0; i < panelWorkingModel.count; ++i)
                                            if (panelWorkingModel.get(i).itemEnabled)
                                                lastEnabled = i;
                                        if (lastEnabled >= 0 && idx <= lastEnabled)
                                            panelWorkingModel.move(idx, lastEnabled, 1);
                                        else if (lastEnabled < 0 && idx > 0)
                                            panelWorkingModel.move(idx, 0, 1);
                                    }
                                    configRoot.applyPanelItems();
                                }
                            }
                        }
                    }
                    // Inline sun times options (only for non-custom themes)
                    RowLayout {
                        visible: model.itemId === "suntimes" && panelDelegateRoot.settingsExpanded && configRoot.cfg_panelIconTheme !== "custom"
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.iconSizes.smallMedium * 2 + Kirigami.Units.largeSpacing * 2
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        Layout.bottomMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.largeSpacing
                        Label {
                            text: i18n("Sun times mode:")
                            font: Kirigami.Theme.smallFont
                            opacity: 0.8
                        }
                        ComboBox {
                            id: sunTimesInlineCombo
                            Layout.fillWidth: true
                            model: [
                                {
                                    text: i18n("Upcoming (next sunrise or sunset)"),
                                    value: "upcoming"
                                },
                                {
                                    text: i18n("Both  07:17 / 18:03"),
                                    value: "both"
                                },
                                {
                                    text: i18n("Sunrise only  07:17"),
                                    value: "sunrise"
                                },
                                {
                                    text: i18n("Sunset only   18:03"),
                                    value: "sunset"
                                }
                            ]
                            textRole: "text"
                            Component.onCompleted: {
                                for (var i = 0; i < model.length; ++i)
                                    if (model[i].value === configRoot.cfg_panelSunTimesMode) {
                                        currentIndex = i;
                                        break;
                                    }
                            }
                            onActivated: configRoot.cfg_panelSunTimesMode = model[currentIndex].value
                        }
                    }

                    Kirigami.Separator {
                        Layout.fillWidth: true
                        opacity: 0.4
                    }
                }
            }
        }
    }
    // ── Button guide ─────────────────────────────────────────────────
    // Explains what each toolbar button on each row does.
    Kirigami.Separator {
        Layout.fillWidth: true
    }
    ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        Label {
            text: i18n("Button guide")
            font.bold: true
            opacity: 0.85
        }

        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            // Drag handle
            RowLayout {
                spacing: 4
                Kirigami.Icon {
                    source: "handle-sort"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                }
                Label {
                    text: i18n("Drag to reorder enabled items")
                    font: Kirigami.Theme.smallFont
                    opacity: 0.75
                }
            }

            // Configure icon (custom theme only)
            RowLayout {
                visible: configRoot.cfg_panelIconTheme === "custom"
                spacing: 4
                Kirigami.Icon {
                    source: "color-picker"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                }
                Label {
                    text: i18n("Choose a custom icon for this item")
                    font: Kirigami.Theme.smallFont
                    opacity: 0.75
                }
            }

            // Eye toggle
            RowLayout {
                spacing: 4
                Kirigami.Icon {
                    source: "view-visible"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                }
                Label {
                    text: i18n("Show / hide the prefix icon on the panel")
                    font: Kirigami.Theme.smallFont
                    opacity: 0.75
                }
            }

            // Enable / disable
            RowLayout {
                spacing: 4
                Kirigami.Icon {
                    source: "font-enable"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                }
                Label {
                    text: i18n("Enable or disable this item on the panel")
                    font: Kirigami.Theme.smallFont
                    opacity: 0.75
                }
            }
        }
    }
}
