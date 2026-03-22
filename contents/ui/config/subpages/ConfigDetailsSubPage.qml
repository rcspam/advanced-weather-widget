/**
 * ConfigDetailsSubPage — extracted from configAppearance.qml
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

    id: detailsSubPageRoot
    spacing: 0
    property string _savedOrder: configRoot.cfg_widgetDetailsOrder
    Dialog {
        id: detailsLeaveDialog
        title: i18n("Apply Settings?")
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        standardButtons: Dialog.NoButton
        Label {
            text: i18n("Keep the changes you made to Details Items?")
            wrapMode: Text.WordWrap
        }
        footer: DialogButtonBox {
            Button {
                text: i18n("Keep Changes")
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
                onClicked: {
                    detailsLeaveDialog.accept();
                    stack.pop();
                }
            }
            Button {
                text: i18n("Discard")
                DialogButtonBox.buttonRole: DialogButtonBox.DestructiveRole
                onClicked: {
                    configRoot.cfg_widgetDetailsOrder = detailsSubPageRoot._savedOrder;
                    detailsLeaveDialog.close();
                    stack.pop();
                }
            }
            Button {
                text: i18n("Cancel")
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
                onClicked: detailsLeaveDialog.close()
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
                if (configRoot.cfg_widgetDetailsOrder !== detailsSubPageRoot._savedOrder)
                    detailsLeaveDialog.open();
                else
                    stack.pop();
            }
        }
        Label {
            Layout.fillWidth: true
            text: i18n("Details Items")
            font.bold: true
        }
    }
    Kirigami.Separator {
        Layout.fillWidth: true
    }
    // ── Per-item configure dialog (suntimes / moonphase) ─────────────
    Dialog {
        id: itemCfgDialog
        property string _itemId: ""
        title: _itemId === "suntimes" ? i18n("Sunrise/Sunset options") : i18n("Moon Phase options")
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(420, parent ? parent.width * 0.92 : 420)
        standardButtons: Dialog.Close

        ColumnLayout {
            width: parent.width
            spacing: Kirigami.Units.largeSpacing

            // ── Blue info banner ─────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                radius: 4
                color: Qt.rgba(0.18, 0.52, 1.0, 0.14)
                border.color: Qt.rgba(0.18, 0.52, 1.0, 0.40)
                border.width: 1
                implicitHeight: infoBannerRow.implicitHeight + 14
                RowLayout {
                    id: infoBannerRow
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: 10
                    }
                    spacing: 8
                    Kirigami.Icon {
                        source: "dialog-information"
                        implicitWidth: 16; implicitHeight: 16
                        color: "#4a8fe8"
                    }
                    Label {
                        Layout.fillWidth: true
                        text: i18n("This option affects the item when it's collapsed.")
                        color: "#4a8fe8"
                        wrapMode: Text.WordWrap
                        font: Kirigami.Theme.smallFont
                    }
                }
            }

            // ── Sunrise/Sunset options ───────────────────────────────
            ColumnLayout {
                visible: itemCfgDialog._itemId === "suntimes"
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Label { text: i18n("Show:"); opacity: 0.75 }
                ComboBox {
                    id: sunModeCfgCombo
                    Layout.fillWidth: true
                    textRole: "text"
                    model: [
                        { text: i18n("Both (sunrise & sunset)"), value: "both" },
                        { text: i18n("Sunrise only"),            value: "sunrise" },
                        { text: i18n("Sunset only"),             value: "sunset" },
                        { text: i18n("Upcoming (auto)"),         value: "upcoming" }
                    ]
                    currentIndex: {
                        for (var i = 0; i < model.length; ++i)
                            if (model[i].value === configRoot.cfg_widgetSunTimesMode) return i;
                        return 0;
                    }
                    onActivated: configRoot.cfg_widgetSunTimesMode = model[currentIndex].value
                }
            }

            // ── Moon Phase options ───────────────────────────────────
            ColumnLayout {
                visible: itemCfgDialog._itemId === "moonphase"
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Label { text: i18n("Show:"); opacity: 0.75 }
                ComboBox {
                    id: moonModeCfgCombo
                    Layout.fillWidth: true
                    textRole: "text"
                    model: [
                        { text: i18n("Phase + moonrise & moonset"), value: "full" },
                        { text: i18n("Phase + upcoming rise/set"),  value: "upcoming" },
                        { text: i18n("Moonrise & moonset only"),    value: "times" }
                    ]
                    currentIndex: {
                        for (var i = 0; i < model.length; ++i)
                            if (model[i].value === configRoot.cfg_widgetMoonMode) return i;
                        return 0;
                    }
                    onActivated: configRoot.cfg_widgetMoonMode = model[currentIndex].value
                }
            }
        }
    }

    ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: availableWidth
        ListView {
            id: detailsList
            width: parent.width
            implicitHeight: contentHeight
            clip: true
            spacing: 0
            model: detailsWorkingModel
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
                width: detailsList.width
                label: section === "true" ? i18n("Shown") : i18n("Hidden")
            }
            delegate: Item {
                id: detailsDelegateRoot
                width: detailsList.width
                implicitHeight: detailsDelegateCol.implicitHeight
                ColumnLayout {
                    id: detailsDelegateCol
                    spacing: 0
                    width: parent.width
                    ItemDelegate {
                        id: detailsRowDelegate
                        Layout.fillWidth: true
                        hoverEnabled: true
                        down: false
                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            // ── Drag handle (only active for enabled items) ──────
                            Kirigami.ListItemDragHandle {
                                listItem: detailsRowDelegate
                                listView: detailsList
                                enabled: model.itemEnabled
                                opacity: model.itemEnabled ? 1.0 : 0.0
                                onMoveRequested: function (oldIndex, newIndex) {
                                    var boundary = configRoot.firstDetailsDisabledIndex();
                                    var clamped = (boundary < 0) ? newIndex : Math.min(newIndex, boundary - 1);
                                    if (clamped !== oldIndex)
                                        detailsWorkingModel.move(oldIndex, clamped, 1);
                                }
                                onDropped: configRoot.applyDetailsItems()
                            }
                            // ── Item icon — mirrors the active widget icon theme ──
                            Item {
                                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                                implicitHeight: Kirigami.Units.iconSizes.smallMedium
                                opacity: model.itemEnabled ? 1.0 : 0.35
                                // wi-font glyph
                                Text {
                                    anchors.centerIn: parent
                                    text: model.itemWiChar
                                    font.family: configRoot.wiFontReady ? configRoot.wiFontFamily : ""
                                    font.pixelSize: Kirigami.Units.iconSizes.smallMedium - 2
                                    color: Kirigami.Theme.textColor
                                    visible: configRoot.cfg_widgetIconTheme === "wi-font" && model.itemWiChar.length > 0 && configRoot.wiFontReady
                                }
                                // KDE / wi-font fallback
                                Kirigami.Icon {
                                    anchors.fill: parent
                                    source: model.itemFallback
                                    visible: (configRoot.cfg_widgetIconTheme === "wi-font" && (model.itemWiChar.length === 0 || !configRoot.wiFontReady)) || configRoot.cfg_widgetIconTheme === "kde"
                                }
                                // SVG theme icon (symbolic / flat-color / 3d-oxygen)
                                Kirigami.Icon {
                                    anchors.fill: parent
                                    visible: configRoot.cfg_widgetIconTheme !== "wi-font" && configRoot.cfg_widgetIconTheme !== "kde" && configRoot.cfg_widgetIconTheme.length > 0
                                    source: {
                                        var th = configRoot.cfg_widgetIconTheme;
                                        if (!th || th === "wi-font" || th === "kde")
                                            return "";
                                        var b = configRoot.iconsBase + th + "/16/wi-";
                                        var id = model.itemId;
                                        if (id === "feelslike" || id === "dewpoint")
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
                                        if (id === "visibility")
                                            return b + "fog.svg";
                                        return "";
                                    }
                                    isMask: configRoot.cfg_widgetIconTheme === "symbolic"
                                    color: Kirigami.Theme.textColor
                                }
                            }
                            // ── Labels ───────────────────────────────────────────
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
                            // ── Configure button (suntimes / moonphase only) ─────
                            ToolButton {
                                visible: model.itemId === "suntimes" || model.itemId === "moonphase"
                                implicitWidth: Kirigami.Units.iconSizes.medium
                                implicitHeight: Kirigami.Units.iconSizes.medium
                                icon.name: "configure"
                                ToolTip.visible: hovered
                                ToolTip.text: i18n("Configure collapsed view")
                                onClicked: {
                                    itemCfgDialog._itemId = model.itemId;
                                    itemCfgDialog.open();
                                }
                            }
                            // ── Enable / disable toggle ───────────────────────────
                            ToolButton {
                                implicitWidth: Kirigami.Units.iconSizes.medium
                                implicitHeight: Kirigami.Units.iconSizes.medium
                                icon.name: model.itemEnabled ? "font-enable" : "font-disable"
                                ToolTip.visible: hovered
                                ToolTip.text: model.itemEnabled ? i18n("Hide from details") : i18n("Show in details")
                                onClicked: {
                                    var idx = model.index;
                                    var nowOn = !model.itemEnabled;
                                    detailsWorkingModel.setProperty(idx, "itemEnabled", nowOn);
                                    var boundary = configRoot.firstDetailsDisabledIndex();
                                    if (nowOn) {
                                        // Re-enabling: move from disabled zone to just before first disabled
                                        if (boundary > 0 && idx >= boundary)
                                            detailsWorkingModel.move(idx, boundary - 1, 1);
                                    } else {
                                        // Disabling: move to end of enabled group
                                        var lastEnabled = -1;
                                        for (var i = 0; i < detailsWorkingModel.count; ++i)
                                            if (detailsWorkingModel.get(i).itemEnabled)
                                                lastEnabled = i;
                                        if (lastEnabled >= 0 && idx <= lastEnabled)
                                            detailsWorkingModel.move(idx, lastEnabled, 1);
                                        else if (lastEnabled < 0 && idx > 0)
                                            detailsWorkingModel.move(idx, 0, 1);
                                    }
                                    configRoot.applyDetailsItems();
                                }
                            }
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
    // ── Button guide ──────────────────────────────────────────────────
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
            RowLayout {
                spacing: 4
                Kirigami.Icon {
                    source: "handle-sort"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                }
                Label {
                    text: i18n("Drag to reorder shown items")
                    font: Kirigami.Theme.smallFont
                    opacity: 0.75
                }
            }
            RowLayout {
                spacing: 4
                Kirigami.Icon {
                    source: "font-enable"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                }
                Label {
                    text: i18n("Show or hide this detail item")
                    font: Kirigami.Theme.smallFont
                    opacity: 0.75
                }
            }
        }
    }
}
