#pragma once

#include "Portable.h"
#include "config.h"

#include <QObject>
#include <QSettings>
#include <QStringList>

// Where everything the program remembers is kept: the profiles and the
// settings, under this program's own name.
//
// A portable copy keeps them in a file beside itself instead of where the system
// keeps settings; that is the only difference, and Portable::prepare() has
// already said where that file is.
//
// Modify it when settings should become intentionally incompatible.
class OcSettings : public QSettings {
public:
    OcSettings()
        : QSettings(Portable::isActive() ? QSettings::IniFormat : QSettings::NativeFormat,
            QSettings::UserScope,
            QLatin1String(PRODUCT_NAME_COMPANY), QLatin1String(PRODUCT_NAME_SHORT)) {};
};

// The program used to keep all of this under the name of the project it grew
// out of. Renaming it would lose every profile a person already had, so the old
// place is read once and copied across.
//
// Nothing is deleted: the old program, if it is still installed, keeps working
// from its own keys, and a copy of a password sealed by Windows is still only
// readable by the account that saved it.
inline void ocMigrateSettings()
{
    // Not into a portable copy: it may be running on someone else's computer,
    // and it would be carrying that person's profiles away on the stick.
    if (Portable::isActive() == true) {
        return;
    }

    OcSettings current;
    if (current.allKeys().isEmpty() == false) {
        return;
    }

    QSettings previous(QStringLiteral("OpenConnect-GUI Team"), QStringLiteral("OpenConnect-GUI"));
    const QStringList keys = previous.allKeys();
    if (keys.isEmpty() == true) {
        return;
    }

    for (const QString& key : keys) {
        current.setValue(key, previous.value(key));
    }
    current.sync();
}
