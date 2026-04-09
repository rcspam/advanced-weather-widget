/*
 * Copyright 2026  Petar Nedyalkov
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
 * ConfigLocationSubPage — Location search, extracted from configLocation.qml
 * Requires: required property var configRoot
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: searchSubPageRoot
    required property var configRoot
    spacing: 0

    property var searchResults: []
    property bool searchBusy: false
    property int searchRequestId: 0
    property var selectedResult: null
    property int selectedIndex: -1

    // ── Set-as-default dialog state ─────────────────────────────────────
    property real _defaultDialogLat: NaN
    property real _defaultDialogLon: NaN
    property string _defaultDialogName: ""
    property var _pendingItemData: null

    function performSearch(query) {
        if (!query || query.trim().length < 2) {
            searchResults = [];
            selectedResult = null;
            selectedIndex = -1;
            resultsList.currentIndex = -1;
            searchBusy = false;
            return;
        }
        var q = query.trim();
        var requestId = ++searchRequestId;
        searchBusy = true;
        searchResults = [];
        selectedResult = null;
        selectedIndex = -1;
        resultsList.currentIndex = -1;
        var collected = [], pending = 0;

        function queueRequest() {
            pending += 1;
        }

        function done() {
            pending -= 1;
            if (pending > 0)
                return;
            if (requestId !== searchRequestId)
                return;
            var dedup = {}, finalList = [];
            for (var i = 0; i < collected.length; ++i) {
                var item = collected[i];
                var key = Number(item.latitude).toFixed(3) + "|" + Number(item.longitude).toFixed(3);
                if (!dedup[key]) {
                    dedup[key] = true;
                    finalList.push(item);
                }
            }
            searchResults = finalList;
            searchBusy = false;
            selectedResult = null;
            selectedIndex = -1;
            resultsList.currentIndex = -1;
        }

        function fetchNominatim() {
            queueRequest();
            var req = new XMLHttpRequest();
            var hasCyrillic = /[Ѐ-ӿ]/.test(q);
            var lang = hasCyrillic ? "bg,ru,uk,sr,mk,en;q=0.3" : (configRoot.preferredLanguage.length > 0 ? configRoot.preferredLanguage + ",en;q=0.8" : "en");
            var url = "https://nominatim.openstreetmap.org/search" + "?q=" + encodeURIComponent(q) + "&format=json" + "&limit=20" + "&addressdetails=1" + "&accept-language=" + lang;
            req.open("GET", url);
            req.setRequestHeader("User-Agent", "AdvancedWeatherWidget/1.0 (KDE Plasma plasmoid)");
            req.onreadystatechange = function () {
                if (req.readyState !== XMLHttpRequest.DONE)
                    return;
                if (requestId !== searchRequestId)
                    return;
                if (req.status === 200) {
                    JSON.parse(req.responseText).forEach(function (item) {
                        var a = item.address || {};
                        var city = a.city || a.town || a.village || a.hamlet || a.suburb || a.municipality || a.county || "";
                        var district = a.state_district || a.county || "";
                        var state = a.state || a.region || "";
                        var country = a.country || "";
                        collected.push({
                            name: city.length > 0 ? city : item.display_name,
                            admin1: state,
                            district: district,
                            country: country,
                            countryCode: (a.country_code || "").toUpperCase(),
                            latitude: parseFloat(item.lat),
                            longitude: parseFloat(item.lon),
                            timezone: "",
                            elevation: undefined,
                            provider: "OpenStreetMap",
                            providerKey: "nominatim",
                            localizedDisplayName: item.display_name
                        });
                    });
                }
                done();
            };
            req.send();
        }

        function fetchOpenMeteo() {
            queueRequest();
            var req = new XMLHttpRequest();
            req.open("GET", "https://geocoding-api.open-meteo.com/v1/search" + "?count=10&format=json&name=" + encodeURIComponent(q));
            req.onreadystatechange = function () {
                if (req.readyState !== XMLHttpRequest.DONE)
                    return;
                if (requestId !== searchRequestId)
                    return;
                if (req.status === 200) {
                    var list = JSON.parse(req.responseText).results || [];
                    list.forEach(function (it) {
                        collected.push({
                            name: it.name || "",
                            admin1: it.admin1 || "",
                            country: it.country || "",
                            countryCode: (it.country_code || "").toUpperCase(),
                            latitude: parseFloat(it.latitude),
                            longitude: parseFloat(it.longitude),
                            timezone: it.timezone || "",
                            elevation: it.elevation,
                            provider: "Open-Meteo",
                            providerKey: "open-meteo",
                            localizedDisplayName: (it.name || "") + (it.admin1 ? ", " + it.admin1 : "") + (it.country ? ", " + it.country : "")
                        });
                    });
                }
                done();
            };
            req.send();
        }

        fetchNominatim();
        fetchOpenMeteo();
    }

    Timer {
        id: searchDebounce
        interval: 120
        repeat: false
        onTriggered: searchSubPageRoot.performSearch(searchField.text)
    }

    // ── Set as default dialog ────────────────────────────────────────────
    Kirigami.Dialog {
        id: setDefaultDialog
        title: i18n("Set as default?")
        standardButtons: Kirigami.Dialog.NoButton
        leftPadding: Kirigami.Units.gridUnit * 2
        rightPadding: Kirigami.Units.gridUnit * 2
        topPadding: Kirigami.Units.gridUnit
        bottomPadding: Kirigami.Units.gridUnit

        contentItem: Item {
            implicitWidth: 360
            implicitHeight: setDefaultCol.implicitHeight

            ColumnLayout {
                id: setDefaultCol
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignHCenter
                    source: "starred-symbolic"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                    Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    textFormat: Text.RichText
                    text: i18n("Set <b>%1</b> as your default location?", searchSubPageRoot._defaultDialogName)
                }

                Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Kirigami.Units.mediumSpacing

                    Button {
                        text: i18n("Yes")
                        icon.name: "dialog-ok-apply"
                        onClicked: {
                            // Stage as active location
                            configRoot.applySearchResult(searchSubPageRoot._pendingItemData);

                            // Clear all stars, add starred entry at top of cfg_savedLocations
                            var locs;
                            try {
                                locs = JSON.parse(configRoot.cfg_savedLocations || "[]");
                                if (!Array.isArray(locs)) locs = [];
                            } catch (e) { locs = []; }
                            for (var i = 0; i < locs.length; i++)
                                delete locs[i].starred;
                            var item = searchSubPageRoot._pendingItemData;
                            locs.unshift({
                                name: searchSubPageRoot._defaultDialogName,
                                lat: searchSubPageRoot._defaultDialogLat,
                                lon: searchSubPageRoot._defaultDialogLon,
                                altitude: 0,
                                timezone: (item && item.timezone) ? item.timezone : "",
                                countryCode: (item && item.countryCode) ? item.countryCode.toUpperCase() : "",
                                starred: true
                            });
                            configRoot.cfg_savedLocations = JSON.stringify(locs);
                            searchSubPageRoot._pendingItemData = null;
                            setDefaultDialog.close();
                            stack.pop();
                        }
                    }

                    Button {
                        text: i18n("No")
                        icon.name: "dialog-cancel"
                        onClicked: {
                            // Save to list without starring — don't change active location
                            var locs;
                            try {
                                locs = JSON.parse(configRoot.cfg_savedLocations || "[]");
                                if (!Array.isArray(locs)) locs = [];
                            } catch (e) { locs = []; }
                            var item = searchSubPageRoot._pendingItemData;
                            locs.push({
                                name: searchSubPageRoot._defaultDialogName,
                                lat: searchSubPageRoot._defaultDialogLat,
                                lon: searchSubPageRoot._defaultDialogLon,
                                altitude: 0,
                                timezone: (item && item.timezone) ? item.timezone : "",
                                countryCode: (item && item.countryCode) ? item.countryCode.toUpperCase() : ""
                            });
                            configRoot.cfg_savedLocations = JSON.stringify(locs);
                            searchSubPageRoot._pendingItemData = null;
                            setDefaultDialog.close();
                            stack.pop();
                        }
                    }
                }

                Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
            }
        }
    }

    // ── Header ──────────────────────────────────────────────────────────
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
                if (searchSubPageRoot._pendingItemData !== null)
                    setDefaultDialog.open();
                else
                    stack.pop();
            }
        }
        Label {
            Layout.fillWidth: true
            text: i18n("Search Location")
            font.bold: true
        }
    }

    // ── Search content ──────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        spacing: 8

        Label {
            text: i18n("Location:") + "  " + configRoot.currentLocationDisplayName()
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: i18n("Enter Location")
                selectByMouse: true
                onTextChanged: {
                    searchSubPageRoot.selectedResult = null;
                    searchSubPageRoot.selectedIndex = -1;
                    resultsList.currentIndex = -1;
                    configRoot.locationCheckState = 0;
                    if (text.trim().length < 2) {
                        searchSubPageRoot.searchResults = [];
                        searchSubPageRoot.searchBusy = false;
                        return;
                    }
                    searchDebounce.restart();
                }
                onAccepted: searchSubPageRoot.performSearch(text)
            }
            ToolButton {
                text: "✕"
                visible: searchField.text.length > 0
                onClicked: {
                    searchField.clear();
                    searchSubPageRoot.searchResults = [];
                    searchSubPageRoot.searchBusy = false;
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ListView {
                id: resultsList
                anchors.fill: parent
                clip: true
                model: searchSubPageRoot.searchResults
                currentIndex: searchSubPageRoot.selectedIndex
                visible: searchSubPageRoot.searchResults.length > 0
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    active: resultsList.moving || hovered
                }
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 36
                    color: index === searchSubPageRoot.selectedIndex ? Kirigami.Theme.highlightColor : "transparent"
                    Label {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        text: configRoot.formatResultListItem(modelData)
                        color: index === searchSubPageRoot.selectedIndex ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            searchSubPageRoot.selectedIndex = index;
                            searchSubPageRoot.selectedResult = modelData;
                            resultsList.currentIndex = index;

                            var entryLat = parseFloat(modelData.latitude);
                            var entryLon = parseFloat(modelData.longitude);
                            var isNew = true;
                            var locs;
                            try {
                                locs = JSON.parse(configRoot.cfg_savedLocations || "[]");
                                if (!Array.isArray(locs)) locs = [];
                            } catch (e) { locs = []; }
                            for (var k = 0; k < locs.length; k++) {
                                if (Math.abs(locs[k].lat - entryLat) < 0.01 &&
                                    Math.abs(locs[k].lon - entryLon) < 0.01) {
                                    isNew = false;
                                    break;
                                }
                            }

                            // Always stage to cfg_* so KCM Apply becomes active
                            configRoot.applySearchResult(modelData);

                            if (isNew) {
                                // Store pending — dialog shown when user clicks Back
                                searchSubPageRoot._pendingItemData = modelData;
                                searchSubPageRoot._defaultDialogLat = entryLat;
                                searchSubPageRoot._defaultDialogLon = entryLon;
                                searchSubPageRoot._defaultDialogName = configRoot.formatResultTitle(modelData);
                            } else {
                                // Already saved — no dialog needed
                                searchSubPageRoot._pendingItemData = null;
                            }
                        }
                    }
                }
            }
            Column {
                anchors.centerIn: parent
                width: parent.width - 32
                spacing: 10
                visible: searchSubPageRoot.searchBusy || searchSubPageRoot.searchResults.length === 0
                BusyIndicator {
                    anchors.horizontalCenter: parent.horizontalCenter
                    running: searchSubPageRoot.searchBusy
                    visible: searchSubPageRoot.searchBusy
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    opacity: 0.9
                    font.pixelSize: searchSubPageRoot.searchBusy ? 18 : 30
                    font.bold: true
                    text: searchSubPageRoot.searchBusy ? i18n("Loading locations…") : (searchField.text.trim().length < 2 ? i18n("Search a weather station to set your location") : i18n("No weather stations found for '%1'", searchField.text.trim()))
                }
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: configRoot.locationCheckState === 2
            type: Kirigami.MessageType.Positive
            text: configRoot.locationCheckMessage
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: configRoot.locationCheckState === 3
            type: Kirigami.MessageType.Error
            text: configRoot.locationCheckMessage
        }
    }
}
