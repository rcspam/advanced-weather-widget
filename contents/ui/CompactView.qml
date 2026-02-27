/**
 * CompactView.qml — Panel / compact representation
 *
 * Renders the thin panel bar: wi-font icon + value chips separated by a bullet.
 * Also hosts the custom tooltip popup (TooltipContent).
 *
 * Display modes (Plasmoid.configuration.panelInfoMode):
 *   "single"    — all items in one row (original behaviour)
 *   "multiline" — large weather icon on the left, item rows scrolling on right;
 *                 fills the full panel height set by the user in KDE settings
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

import "js/weather.js"   as W
import "js/moonphase.js" as Moon


PlasmaCore.ToolTipArea {
    id: compactRoot

    // ── Interface — bound from main.qml ──────────────────────────────────
    /** Reference to the PlasmoidItem root */
    property var weatherRoot

    // ── Layout ───────────────────────────────────────────────────────────
    readonly property int leftRightMargin: 4
    readonly property int itemSpacing:  Plasmoid.configuration.panelItemSpacing !== undefined
    ? Plasmoid.configuration.panelItemSpacing : 5
    // When panelUseSystemFont is true (Automatic) always use the theme default size.
    // Checking panelUseSystemFont here is the key: without it, switching back to
    // Automatic while a saved panelFontSize > 0 existed would keep the old size.
    // panelFontPx — pixels used for glyph sizing and layout.
    // FontDialog stores pointSize; convert pt→px (96 dpi: 1pt = 4/3 px).
    readonly property int panelFontPx: {
        if (!Plasmoid.configuration.panelUseSystemFont
                && Plasmoid.configuration.panelFontSize > 0)
            return Math.round(Plasmoid.configuration.panelFontSize * 4 / 3);
        return Kirigami.Theme.defaultFont.pixelSize;
    }
    // Glyphs rendered 30 % larger than text so the icon visual weight
    // matches the label weight (Weather Icon glyphs have inner whitespace).
    readonly property int glyphSize: Math.max(12, Math.round(panelFontPx * 1.3))

    // svgIconPx — display size for SVG panel icons (user-configurable).
    // wi-font glyphs always scale with the font; SVG/KDE icons use this.
    readonly property int svgIconPx: {
        var theme = Plasmoid.configuration.panelIconTheme || "wi-font";
        if (theme === "wi-font") return glyphSize;
        return Plasmoid.configuration.panelIconSize || 22;
    }

    // ── Mode helpers ──────────────────────────────────────────────────────
    readonly property bool isMultiLine: Plasmoid.configuration.panelInfoMode === "multiline"
    readonly property int  multiLines:  Math.max(1, Plasmoid.configuration.panelMultiLines || 2)
    readonly property bool multiAnimate: Plasmoid.configuration.panelMultiAnimate !== false

    // mlIconSize: large weather icon on the left of the multiline layout.
    // Based on panelFontPx so it never reads compactRoot.height (circular binding).
    readonly property int mlIconSize: Math.min(Math.max(multiLines * (panelFontPx + 8), 32) - 4, 64)

    implicitHeight: isMultiLine ? Math.max(multiLines * (panelFontPx + 8), 32)
                                : Math.max(22, Kirigami.Units.gridUnit + 4)
    implicitWidth:  isMultiLine ? mlIconSize + 6 + 110 + 2 * leftRightMargin
                                : compactRow.implicitWidth + 2 * leftRightMargin

    // fillHeight:true so the widget fills whatever height KDE allocates.
    // If the user sets a manual panelHeight > 0, we use that as the preferred
    // height instead, which lets the widget grow taller than the default panel
    // slot (useful for multiline + large font where text would otherwise be clipped).
    readonly property int manualWidth: Plasmoid.configuration.panelWidth || 0
    readonly property int textColWidth: (Plasmoid.configuration.panelWidth || 0) > 0 ? Plasmoid.configuration.panelWidth : 110
    Layout.fillHeight:      isMultiLine
    Layout.fillWidth:       Plasmoid.configuration.panelFillWidth
    Layout.preferredWidth:  Plasmoid.configuration.panelFillWidth ? -1
                                : (isMultiLine ? mlIconSize + 6 + textColWidth + 2 * leftRightMargin
                                               : implicitWidth)
    Layout.minimumWidth:    isMultiLine ? mlIconSize + 6 + 60 : implicitWidth
    Layout.preferredHeight: isMultiLine
                                ? (manualWidth > 0 ? manualWidth : -1)
                                : implicitHeight
    Layout.minimumHeight:   implicitHeight

    // ── Wi-font (panel glyphs) ────────────────────────────────────────────
    FontLoader {
        id: wiFontPanel
        source: Qt.resolvedUrl("../fonts/weathericons-regular-webfont.ttf")
    }

    // ── Icon theme ────────────────────────────────────────────────────────
    readonly property string iconTheme: Plasmoid.configuration.panelIconTheme || "wi-font"

    // ── Reactive panel items ──────────────────────────────────────────────
    property var panelItemsData: {
        // Dependencies — any change triggers rebuild
        if (!weatherRoot) return [];
        var _ = weatherRoot.temperatureC + weatherRoot.windKmh
        + weatherRoot.windDirection + weatherRoot.humidityPercent
        + weatherRoot.pressureHpa + weatherRoot.weatherCode
        + weatherRoot.panelScrollIndex
        + weatherRoot.sunriseTimeText.length + weatherRoot.sunsetTimeText.length
        + Plasmoid.configuration.panelItemOrder
        + Plasmoid.configuration.panelItemIcons
        + Plasmoid.configuration.panelInfoMode
        + Plasmoid.configuration.panelSeparator
        + Plasmoid.configuration.panelSunTimesMode
        + compactRoot.iconTheme
        + Plasmoid.configuration.panelIconSize;
        return _buildItems();
    }

    // Items without separator entries — used by the multiline view so each
    // real item gets its own row without bullet clutter.
    property var multiLineItemsData: {
        var all = panelItemsData;
        var result = [];
        for (var i = 0; i < all.length; ++i)
            if (!all[i].isSep) result.push(all[i]);
            return result;
    }

    // ── Row height for multiline mode ─────────────────────────────────────
    // Each row fills (panel_height / multiLines).  We derive it from the
    // actual rendered height of this item so it reacts to panel resizes.
    readonly property real multiLineRowH: height > 0
    ? Math.max(14, height / multiLines)
    : Math.max(14, panelFontPx + 8)

    // ── Multiline scroll state ────────────────────────────────────────────
    property int mlScrollOffset: 0   // current top row index (0 = first row visible)

    // Advance the scroll offset by one row each tick, wrapping when we
    // reach the end of the list.  The NumberAnimation in scrollCol provides
    // the smooth slide between ticks.
    Timer {
        id: mlScrollTimer
        interval: Math.max(1, Plasmoid.configuration.panelScrollSeconds || 4) * 1000
        // Always scroll when there are more items than visible rows.
        // multiAnimate only controls whether the slide is animated — not whether scrolling happens.
        running:  compactRoot.isMultiLine
        && compactRoot.multiLineItemsData.length > compactRoot.multiLines
        repeat:   true
        onTriggered: {
            var total = compactRoot.multiLineItemsData.length;
            compactRoot.mlScrollOffset = (compactRoot.mlScrollOffset + 1) % total;
        }
    }

    // Reset scroll to top whenever the mode or items change
    onIsMultiLineChanged:        mlScrollOffset = 0
    onMultiLineItemsDataChanged: mlScrollOffset = 0

    // ── Custom tooltip popup ──────────────────────────────────────────────
    mainItem: TooltipContent {
        weatherRoot: compactRoot.weatherRoot
    }

    // ══════════════════════════════════════════════════════════════════════
    // SINGLE / SCROLL MODE  — original row layout
    // ══════════════════════════════════════════════════════════════════════
    RowLayout {
        id: compactRow
        visible: !compactRoot.isMultiLine
        anchors.fill: parent
        anchors.leftMargin:  compactRoot.leftRightMargin
        anchors.rightMargin: compactRoot.leftRightMargin
        spacing: compactRoot.itemSpacing
        clip: true  // prevent overflow when font is large

        Repeater {
            model: compactRoot.panelItemsData
            delegate: RowLayout {
                required property var modelData
                spacing: modelData.isSep ? 0 : 5  // space between wi-font icon and value

                // wi-font glyph
                Text {
                    visible: modelData.glyphVis && modelData.glyphType === "wi"
                    text:    modelData.glyph
                    font.family:    wiFontPanel.status === FontLoader.Ready ? wiFontPanel.font.family : ""
                    font.pixelSize: compactRoot.glyphSize
                    color: Kirigami.Theme.textColor
                    verticalAlignment: Text.AlignVCenter
                }
                // Kirigami icon (KDE system theme) — explicit size from svgIconPx
                Kirigami.Icon {
                    visible: modelData.glyphVis && modelData.glyphType === "kde"
                             && modelData.glyph.length > 0
                    source:  modelData.glyph
                    width:          compactRoot.svgIconPx
                    height:         compactRoot.svgIconPx
                    implicitWidth:  compactRoot.svgIconPx
                    implicitHeight: compactRoot.svgIconPx
                }
                // Kirigami icon (fallback type, e.g. mark-location)
                Kirigami.Icon {
                    visible: modelData.glyphVis && modelData.glyphType === "kirigami"
                             && modelData.glyph.length > 0
                    source:  modelData.glyph
                    implicitWidth:  compactRoot.glyphSize
                    implicitHeight: compactRoot.glyphSize
                }
                // SVG icon — shows the SVG file if it exists; KDE fallback renders
                // beneath it so that missing SVG files (e.g. wi-sunset.svg) still show.
                Item {
                    visible: modelData.glyphVis && modelData.glyphType === "svg"
                             && modelData.glyph.length > 0
                    implicitWidth:  compactRoot.svgIconPx
                    implicitHeight: compactRoot.svgIconPx
                    // KDE fallback — always present behind the SVG layer
                    Kirigami.Icon {
                        anchors.fill: parent
                        source: modelData.glyphKdeFallback || ""
                        visible: (modelData.glyphKdeFallback || "").length > 0
                    }
                    // SVG icon on top — opaque when file loads, invisible when missing
                    Kirigami.Icon {
                        anchors.fill: parent
                        source: modelData.glyph
                        isMask: compactRoot.iconTheme === "symbolic"
                        color:  Kirigami.Theme.textColor
                    }
                }
                // Value text — use wpf() so panel font family/bold/size are applied
                Label {
                    text: modelData.text
                    font: modelData.isSep
                    ? Qt.font({ pixelSize: compactRoot.panelFontPx, bold: false })
                    : weatherRoot ? weatherRoot.wpf(compactRoot.panelFontPx, false)
                    : Qt.font({ pixelSize: compactRoot.panelFontPx })
                    color: Kirigami.Theme.textColor
                    verticalAlignment: Text.AlignVCenter
                    opacity: modelData.isSep ? 0.5 : 1.0
                    elide: Text.ElideRight
                    // Each chip gets at most 120px so long text never pushes
                    // other items off the panel edge when font size is large.
                    Layout.maximumWidth: {
                        if (modelData.isSep) return implicitWidth
                        var w = Plasmoid.configuration.panelWidth || 0
                        return w > 0 ? w : 120
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // MULTILINE MODE  — icon on left, scrolling rows on right
    // ══════════════════════════════════════════════════════════════════════
    RowLayout {
        id: multiLineRow
        visible: compactRoot.isMultiLine
        anchors.fill: parent
        anchors.leftMargin:  compactRoot.leftRightMargin
        anchors.rightMargin: compactRoot.leftRightMargin
        spacing: 6

        // ── Weather icon — sized to actual panel height (set by KDE) ─────────
        // compactRoot.height is the real height allocated by the panel manager;
        // this read does NOT create a circular binding because we only read it,
        // we never use it as the basis for implicitHeight.
        Kirigami.Icon {
            id: weatherIconLarge
            readonly property int iconSz: compactRoot.height > 8
            ? Math.min(compactRoot.height - 4, 64)
            : compactRoot.mlIconSize
            source: weatherRoot
            ? W.weatherCodeToIcon(weatherRoot.weatherCode, weatherRoot.isNightTime())
            : "weather-none-available"
            Layout.preferredWidth:  iconSz
            Layout.preferredHeight: iconSz
            Layout.alignment: Qt.AlignVCenter
            smooth: true
        }

        // ── Scrolling item rows ────────────────────────────────────────────
        Item {
            id: rowsClip
            Layout.fillWidth:  true
            Layout.fillHeight: true
            clip: true    // hide rows that have scrolled out of the visible slot

            // Inner column — slides vertically to reveal successive rows.
            Column {
                id: scrollCol
                width: parent.width

                // rowH: height of one item slot = panel height / number of rows.
                // Reading compactRoot.height (not rowsClip.height) gives the
                // true allocated panel height before layout subtracts margins.
                readonly property real rowH: compactRoot.height > 0
                    ? Math.max(12, compactRoot.height / compactRoot.multiLines)
                    : Math.max(12, compactRoot.panelFontPx + 8)

                // rowFontPx: font size that fits within the row.
                // In manual mode we use the configured size (pt→px converted),
                // but always CAP it to 72 % of rowH so text never overflows the
                // slot — if the panel is too short the text scales down gracefully.
                // In auto mode we always derive from rowH (65 % is a good fill).
                readonly property int rowFontPx: {
                    var useSystem = Plasmoid.configuration.panelUseSystemFont;
                    var savedPt   = Plasmoid.configuration.panelFontSize || 0;
                    var maxFromRow = Math.max(8, Math.floor(rowH * 0.72));
                    if (!useSystem && savedPt > 0)
                        return Math.min(maxFromRow, Math.round(savedPt * 4 / 3));
                    return Math.max(8, Math.floor(rowH * 0.65));
                }

                // Smooth slide on offset change; instant snap back to 0
                // so the loop appears seamless.
                Behavior on y {
                    enabled: compactRoot.multiAnimate && compactRoot.mlScrollOffset !== 0
                    NumberAnimation { duration: 350; easing.type: Easing.InOutCubic }
                }
                y: -(compactRoot.mlScrollOffset * scrollCol.rowH)

                Repeater {
                    model: compactRoot.multiLineItemsData
                    delegate: RowLayout {
                        required property var modelData
                        required property int index
                        width:   scrollCol.width
                        height:  scrollCol.rowH   // exact slot — no overlap
                        spacing: 6  // space between wi-font icon and value
                        clip:    true             // belt-and-suspenders safety

                        // wi-font weather glyph — rendered 30 % larger than label text
                        // so the icon visual weight matches (WI glyphs have internal whitespace).
                        Text {
                            visible: modelData.glyphVis && modelData.glyphType === "wi"
                            text:    modelData.glyph
                            font.family:    wiFontPanel.status === FontLoader.Ready
                            ? wiFontPanel.font.family : ""
                            font.pixelSize: Math.round(scrollCol.rowFontPx * 1.3)
                            color: Kirigami.Theme.textColor
                            verticalAlignment: Text.AlignVCenter
                        }
                        // Kirigami icon (KDE system theme) — explicit size from svgIconPx
                        Kirigami.Icon {
                            visible: modelData.glyphVis && modelData.glyphType === "kde"
                                     && modelData.glyph.length > 0
                            source:  modelData.glyph
                            width:          compactRoot.svgIconPx
                            height:         compactRoot.svgIconPx
                            implicitWidth:  compactRoot.svgIconPx
                            implicitHeight: compactRoot.svgIconPx
                            Layout.alignment: Qt.AlignVCenter
                        }
                        // Kirigami icon (fallback, e.g. mark-location)
                        Kirigami.Icon {
                            visible: modelData.glyphVis && modelData.glyphType === "kirigami"
                                     && modelData.glyph.length > 0
                            source:  modelData.glyph
                            implicitWidth:  scrollCol.rowFontPx
                            implicitHeight: scrollCol.rowFontPx
                            Layout.alignment: Qt.AlignVCenter
                        }
                        // SVG icon — layered: KDE fallback beneath, SVG on top.
                        // If the SVG file is missing (e.g. wi-sunset.svg), the KDE
                        // fallback icon shows through instead of blank space.
                        Item {
                            visible: modelData.glyphVis && modelData.glyphType === "svg"
                                     && modelData.glyph.length > 0
                            implicitWidth:  compactRoot.svgIconPx
                            implicitHeight: compactRoot.svgIconPx
                            Layout.alignment: Qt.AlignVCenter
                            Kirigami.Icon {
                                anchors.fill: parent
                                source: modelData.glyphKdeFallback || ""
                                visible: (modelData.glyphKdeFallback || "").length > 0
                            }
                            Kirigami.Icon {
                                anchors.fill: parent
                                source: modelData.glyph
                                isMask: compactRoot.iconTheme === "symbolic"
                                color:  Kirigami.Theme.textColor
                            }
                        }
                        // Value label — font sized to row; apply custom family/bold via wpf()
                        Label {
                            text: modelData.text
                            // wpf() respects panelFontFamily and panelFontBold while
                            // using the row-derived pixel size so the text fills each slot.
                            font: weatherRoot
                            ? weatherRoot.wpf(scrollCol.rowFontPx, false)
                            : Qt.font({ pixelSize: scrollCol.rowFontPx })
                            color: Kirigami.Theme.textColor
                            verticalAlignment: Text.AlignVCenter
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }

    // ── Tap to expand ─────────────────────────────────────────────────────
    TapHandler {
        acceptedButtons: Qt.LeftButton
        grabPermissions: PointerHandler.CanTakeOverFromAnything
        onTapped: if (weatherRoot) weatherRoot.expanded = !weatherRoot.expanded
    }

    // ── Private: build panel items array ─────────────────────────────────

    function _buildItems() {
        var r = weatherRoot;
        if (!r) return [];
        if (!r.hasSelectedTown)
            return [{ glyph: "\uF041", glyphVis: true, glyphType: "wi",
                text: i18n("Add a location"), isSep: false }];

                var iconMap = r.parsePanelItemIcons();
                var sep     = Plasmoid.configuration.panelSeparator || " \u2022 ";
                var order   = (Plasmoid.configuration.panelItemOrder || "condition;temperature")
                .split(";").filter(function(t){ return t.trim().length > 0; });
                var tokens  = order;
                // In multiline mode: show all tokens (separators stripped later in multiLineItemsData)
                // Single mode shows all tokens at once in one row.

                var theme = Plasmoid.configuration.panelIconTheme || "wi-font";

                var result = [];
                tokens.forEach(function(tok) {
                    tok = tok.trim();
                    var show = (tok in iconMap) ? iconMap[tok] : true;

                    // Get icon info from the active theme via panelItemIconInfo()
                    var iconInfo = r.panelItemIconInfo(tok);   // { type, source }

                    if (tok === "suntimes") {
                        var sunMode = Plasmoid.configuration.panelSunTimesMode || "upcoming";
                        if (sunMode === "both" && theme === "wi-font") {
                            // Both mode: two items with a space separator between them
                            if (result.length > 0)
                                result.push({ glyph: "", glyphVis: false, glyphType: "wi", glyphKdeFallback: "", text: sep, isSep: true });
                            result.push({ glyph: "\uF051", glyphVis: show, glyphType: "wi", glyphKdeFallback: "", text: r.sunriseTimeText, isSep: false });
                            result.push({ glyph: "", glyphVis: false, glyphType: "wi", glyphKdeFallback: "", text: " ", isSep: true });
                            result.push({ glyph: "\uF052", glyphVis: show, glyphType: "wi", glyphKdeFallback: "", text: r.sunsetTimeText,  isSep: false });
                            return;
                        }
                        if (sunMode === "both" && theme !== "wi-font") {
                            // SVG/KDE both mode: two separate rows, each with its own correct icon
                            var riseInfo2, setInfo2;
                            if (theme === "kde") {
                                riseInfo2 = { type: "kde", source: "weather-sunrise",  kdeFallback: "" };
                                setInfo2  = { type: "kde", source: "weather-sunset",   kdeFallback: "" };
                            } else if (theme === "custom") {
                                var rawC2 = Plasmoid.configuration.panelCustomIcons || "", cmap2 = {};
                                rawC2.split(";").forEach(function(p){ var kv=p.split("="); if(kv.length===2) cmap2[kv[0].trim()]=kv[1].trim(); });
                                riseInfo2 = { type: "kde", source: cmap2["suntimes-sunrise"] || "weather-sunrise", kdeFallback: "" };
                                setInfo2  = { type: "kde", source: cmap2["suntimes-sunset"]  || "weather-sunset",  kdeFallback: "" };
                            } else {
                                // All SVG themes: wi-sunrise.svg and wi-sunset.svg exist — no kdeFallback needed
                                var iconSz2 = Plasmoid.configuration.panelIconSize || 22;
                                var rt2 = (theme === "symbolic" && Plasmoid.configuration.panelSymbolicVariant === "light") ? "symbolic-light" : theme;
                                var base2 = Qt.resolvedUrl("../icons/" + rt2 + "/" + iconSz2 + "/wi-");
                                riseInfo2 = { type: "svg", source: base2 + "sunrise.svg", kdeFallback: "" };
                                setInfo2  = { type: "svg", source: base2 + "sunset.svg",  kdeFallback: "" };
                            }
                            if (result.length > 0) result.push({ glyph: "", glyphVis: false, glyphType: "wi", glyphKdeFallback: "", text: sep, isSep: true });
                            result.push({ glyph: riseInfo2.source, glyphVis: show, glyphType: riseInfo2.type, glyphKdeFallback: "", text: r.sunriseTimeText, isSep: false });
                            result.push({ glyph: "",               glyphVis: false, glyphType: "wi",           glyphKdeFallback: "", text: " ", isSep: true });
                            result.push({ glyph: setInfo2.source,  glyphVis: show, glyphType: setInfo2.type,  glyphKdeFallback: "", text: r.sunsetTimeText,  isSep: false });
                            return;
                        }
                        var stx = r.panelItemTextOnly(tok);
                        if (!stx || stx.length === 0) return;
                        if (result.length > 0) result.push({ glyph: "", glyphVis: false, glyphType: "wi", glyphKdeFallback: "", text: sep, isSep: true });
                        result.push({ glyph: iconInfo.source, glyphVis: show && iconInfo.source.length > 0,
                            glyphType: iconInfo.type, glyphKdeFallback: iconInfo.kdeFallback || "", text: stx, isSep: false });
                        return;
                    }

                    var txt = r.panelItemTextOnly(tok);
                    if (!txt || txt.length === 0) return;
                    if (result.length > 0) result.push({ glyph: "", glyphVis: false, glyphType: "wi", glyphKdeFallback: "", text: sep, isSep: true });
                    result.push({ glyph: iconInfo.source, glyphVis: show && iconInfo.source.length > 0,
                        glyphType: iconInfo.type, glyphKdeFallback: iconInfo.kdeFallback || "", text: txt, isSep: false });
                });
                return result;
    }
}
