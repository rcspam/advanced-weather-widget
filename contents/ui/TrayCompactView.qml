/*
 * Copyright 2026  Petar Nedyalkov
 */

import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

import "js/weather.js" as W

Item {
    id: trayRoot

    property var weatherRoot

    readonly property bool _hasTemp: weatherRoot
        && weatherRoot.hasSelectedTown
        && !isNaN(weatherRoot.temperatureC)

    // Weather icon
    Kirigami.Icon {
        id: trayIcon
        anchors.fill: parent
        source: {
            if (!weatherRoot || weatherRoot.weatherCode < 0)
                return "weather-none-available";
            var style = Plasmoid.configuration.panelSimpleIconStyle || "symbolic";
            var isNight = weatherRoot.isNightTime();
            if (style === "symbolic")
                return W.weatherCodeToIcon(weatherRoot.weatherCode, isNight, true);
            return W.weatherCodeToIcon(weatherRoot.weatherCode, isNight, false);
        }
    }

    // Temperature badge (now scales nicely with larger icon)
    Rectangle {
        id: badgeRect
        visible: trayRoot._hasTemp

        readonly property string _pos: Plasmoid.configuration.compressedBadgePosition || "bottom-right"
        readonly property int _spacing: Plasmoid.configuration.compressedBadgeSpacing || 0

        x: {
            if (_pos === "bottom-right" || _pos === "top-right")
                return parent.width - width - _spacing;
            if (_pos === "bottom-left" || _pos === "top-left")
                return _spacing;
            return (parent.width - width) / 2;
        }
        y: {
            if (_pos.indexOf("bottom") === 0)
                return parent.height - height - _spacing;
            return _spacing;
        }

        width: badgeLabel.implicitWidth + 6
        height: badgeLabel.implicitHeight + 2
        radius: height / 2
        color: {
            var cc = Plasmoid.configuration.compressedBadgeColor || "";
            var op = Plasmoid.configuration.compressedBadgeOpacity !== undefined ? Plasmoid.configuration.compressedBadgeOpacity : 0.85;
            if (cc.length > 0) {
                var parsed = Qt.color(cc);
                return Qt.rgba(parsed.r, parsed.g, parsed.b, op);
            }
            return Qt.rgba(Kirigami.Theme.backgroundColor.r,
                           Kirigami.Theme.backgroundColor.g,
                           Kirigami.Theme.backgroundColor.b, op);
        }

        Label {
            id: badgeLabel
            anchors.centerIn: parent
            text: trayRoot.weatherRoot
                ? trayRoot.weatherRoot.tempValue(trayRoot.weatherRoot.temperatureC)
                : "--"
            font.pixelSize: Math.max(7, Math.round(trayRoot.height / 3))
            font.bold: false
            color: Kirigami.Theme.textColor
        }
    }
}