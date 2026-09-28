#pragma once

#include "config.h"

#include <QObject>
#include <QSettings>
#include <QStringList>

// Where everything the program remembers is kept: the profiles and the
// settings, under this program's own name.
//
// Modify it when settings should become intentionally incompatible.
class OcSettings : public QSettings {
public:
    OcSettings()
        : QSettings(QLatin1String(PRODUCT_NAME_COMPANY), QLatin1String(PRODUCT_NAME_SHORT)) {};
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
