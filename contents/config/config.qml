import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Location")
        icon: "mark-location"
        source: "configLocation.qml"
    }
    ConfigCategory {
        name: i18n("General")
        icon: "settings-configure"
        source: "configGeneral.qml"
    }
    // Issue #8: "Units" category removed — units are now in the Appearance > Units tab
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-theme"
        source: "configAppearance.qml"
    }
}
