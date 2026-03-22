pragma ComponentBehavior: Bound

/**
 * WeatherIcon.qml — Unified weather icon renderer
 *
 * Renders a weather icon with automatic fallback:
 *   1. KDE system icon (if type === "kde")
 *   2. Bundled SVG fallback (if svgFallback is set and KDE icon missing)
 *   3. Wi-font glyph (if type === "wi", for compact panel display)
 *
 * Usage (new simplified API):
 *   WeatherIcon {
 *       iconType: "kde"              // "kde" | "svg" | "wi"
 *       iconSource: "thermometer"    // KDE icon name, SVG URL, or wi-font glyph
 *       svgFallback: "file:///..."   // optional bundled SVG fallback URL
 *       iconSize: 22
 *       isMask: false                // true for monochrome symbolic SVGs
 *   }
 *
 * Or with iconResolver.js:
 *   WeatherIcon {
 *       iconInfo: IconResolver.resolve("humidity", 22, iconsBaseDir, "symbolic")
 *       iconSize: 22
 *   }
 */

import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: weatherIcon

    // ── Shorthand: set from iconResolver.js result object ─────────────────
    /** Pass the result of IconResolver.resolve() directly */
    property var iconInfo: null

    // ── Derived properties — reactively track iconInfo ─────────────────
    // These are always in sync with iconInfo via QML bindings (no
    // imperative onChanged handler needed).  When iconInfo is null the
    // defaults produce an empty/invisible state.
    readonly property string _infoType:     iconInfo ? String(iconInfo.type     || "") : ""
    readonly property string _infoSource:   iconInfo ? String(iconInfo.source   || "") : ""
    readonly property string _infoFallback: iconInfo ? String(iconInfo.svgFallback || "") : ""
    readonly property bool   _infoMask:     iconInfo ? (iconInfo.isMask === true) : false

    // ── Individual properties (can also be set directly) ──────────────────
    /** Icon type: "kde" (system icon), "svg" (file URL), "wi" (wi-font glyph) */
    property string iconType: _infoType

    /** The icon source: KDE icon name, SVG file URL, or wi-font glyph char */
    property string iconSource: _infoSource

    /** Pixel size for the icon */
    property int iconSize: 22

    /** Bundled SVG fallback URL — used when KDE icon is not found */
    property string svgFallback: _infoFallback

    /** Whether to render the SVG as a monochrome mask (symbolic theme) */
    property bool isMask: _infoMask

    /** Optional icon colour override (defaults to theme text colour) */
    property color iconColor: Kirigami.Theme.textColor

    // ── Wi-font specific (only needed for "wi" type) ──────────────────────
    /** The loaded wi-font family name (from FontLoader.font.family) */
    property string wiFontFamily: ""

    /** Whether the wi-font FontLoader is ready */
    property bool wiFontReady: false

    // ── Size ──────────────────────────────────────────────────────────────
    implicitWidth: iconSize
    implicitHeight: iconSize
    width: iconSize
    height: iconSize
    clip: true

    visible: iconSource.length > 0

    // ── Wi-font glyph ─────────────────────────────────────────────────────
    Text {
        id: wiFontText
        anchors.centerIn: parent
        visible: weatherIcon.iconType === "wi" && weatherIcon.wiFontReady
        text: weatherIcon.iconSource
        font.family: weatherIcon.wiFontFamily
        font.pixelSize: weatherIcon.iconSize
        color: weatherIcon.iconColor
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
    }

    // ── KDE system icon (colorful — no mask, no color override) ──────────
    Kirigami.Icon {
        id: kdeIcon
        anchors.fill: parent
        visible: weatherIcon.iconType === "kde" && weatherIcon.iconSource.length > 0 && !weatherIcon.isMask
        source: weatherIcon.iconSource
        fallback: "dialog-question"
    }

    // ── KDE system icon (symbolic — monochrome mask) ──────────────────────
    Kirigami.Icon {
        id: kdeSymbolicIcon
        anchors.fill: parent
        visible: weatherIcon.iconType === "kde" && weatherIcon.iconSource.length > 0 && weatherIcon.isMask
        source: weatherIcon.iconSource
        isMask: true
        color: weatherIcon.iconColor
        fallback: "dialog-question-symbolic"
    }

    // ── SVG file icon ─────────────────────────────────────────────────────
    Kirigami.Icon {
        id: svgIcon
        anchors.fill: parent
        visible: weatherIcon.iconType === "svg" && weatherIcon.iconSource.length > 0
        source: weatherIcon.iconSource
        isMask: weatherIcon.isMask
        color: weatherIcon.isMask ? weatherIcon.iconColor : "transparent"
    }
}
