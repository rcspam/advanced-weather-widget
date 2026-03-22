import QtQuick
import org.kde.plasma.configuration

/**
 * config.qml — KDE Plasma plasmoid configuration model
 *
 * All three config pages live in the config/ subdirectory.
 * KDE resolves the source path relative to the plasmoid's ui/ root,
 * so the prefix "config/" points to ui/config/*.qml.
 */
ConfigModel {
    ConfigCategory {
        name: i18n("Location")
        icon: "mark-location"
        source: "config/configLocation.qml"
    }
    ConfigCategory {
        name: i18n("General")
        icon: "settings-configure"
        source: "config/configGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-theme"
        source: "config/configAppearance.qml"
    }
}
