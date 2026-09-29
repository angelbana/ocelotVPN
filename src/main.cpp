/*
 * Copyright (C) 2014 Red Hat
 *
 * This file is part of Ocelot.
 *
 * Ocelot is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "Autostart.h"
#include "LogModel.h"
#include "Portable.h"
#include "VpnController.h"
#include "common.h"
#include "config.h"
#include "ocelot.h"

#include "FileLogger.h"
#include "logger.h"

extern "C" {
#include <gnutls/pkcs11.h>
}

#include <QApplication>
#if !defined(_WIN32) && !defined(PROJ_GNUTLS_DEBUG)
#include <QMessageBox>
#endif
#include <QCommandLineParser>
#include <QFontDatabase>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QSystemTrayIcon>
#include <QTimer>
#include <OcSettings.h>
#include <QtSingleApplication>

#include <csignal>
#include <cstdio>
#include <memory>

static void log_callback(int level, const char* str)
{
    Logger::instance().addMessage(QString(str).trimmed(),
        Logger::MessageType::DEBUG,
        Logger::ComponentType::GNUTLS);
}


int pin_callback(void* userdata, int attempt, const char* token_url,
    const char* token_label, unsigned flags, char* pin,
    size_t pin_max)
{
    QString type = QObject::tr("user");
    if (flags & GNUTLS_PIN_SO) {
        type = QObject::tr("security officer");
    }

    QString outtext = QObject::tr("Please enter the %1 PIN for %2.").arg(type).arg(token_label);
    if (flags & GNUTLS_PKCS11_PIN_FINAL_TRY) {
        outtext += QObject::tr(" This is the FINAL try!");
    }
    if (flags & GNUTLS_PKCS11_PIN_COUNT_LOW) {
        outtext += QObject::tr(" Only few tries before token lock!");
    }

    VpnController* controller = static_cast<VpnController*>(userdata);

    QVariantMap request;
    request["title"] = QString::fromUtf8(token_url);
    request["label"] = outtext;

    QString text;
    if (controller->askPrompt(VpnController::PromptPassword, request, text) == false) {
        return -1;
    }

    snprintf(pin, pin_max, "%s", text.toUtf8().data());
    return 0;
}

int main(int argc, char* argv[])
{
    bool haveTray = false;

    qputenv("LOG2FILE", "1");

    qRegisterMetaType<Logger::Message>();

    QCoreApplication::setApplicationName(APP_NAME);
    QCoreApplication::setApplicationVersion(PROJECT_VERSION);
    QCoreApplication::setOrganizationName(PRODUCT_NAME_COMPANY);
    QCoreApplication::setOrganizationDomain(PRODUCT_NAME_COMPANY_DOMAIN);

    QtSingleApplication app(argc, argv);

    // Which of the two lives this copy leads - carried around in its own folder,
    // or installed - has to be settled before anything reads a setting, because
    // it says where the settings are.
    Portable::prepare();

    // Installing and removing are answered here, at the top, and without a
    // window. A copy that is already running must not simply be raised: the
    // point of such a run is the copy on disk, not the one on screen.
    if (app.arguments().contains(QLatin1String(Portable::installFlag())) == true) {
        QString error;
        if (Portable::install(error) == false) {
            fprintf(stderr, "%s\n", qPrintable(error));
            return 1;
        }
        return 0;
    }

    if (app.arguments().contains(QLatin1String(Portable::uninstallFlag())) == true) {
        if (app.isRunning() == true) {
            app.sendMessage(QStringLiteral("quit"));
        }

        QString error;
        if (Portable::uninstall(error) == false) {
            fprintf(stderr, "%s\n", qPrintable(error));
            return 1;
        }
        return 0;
    }

    // What the program kept under its former name is brought across the first
    // time this one runs.
    ocMigrateSettings();
    if (app.isRunning()) {
        OcSettings settings;
        if (settings.value("Settings/singleInstanceMode", true).toBool()) {
            app.sendMessage("Wake up!");
            return 0;
        }
    }
    app.setApplicationDisplayName(APP_NAME);
    app.setQuitOnLastWindowClosed(false);

    if (QSystemTrayIcon::isSystemTrayAvailable()) {
        haveTray = true;
    }


    // A portable copy writes its log beside itself, next to the settings it also
    // keeps there; an installed one writes where the system keeps such things.
    auto fileLog = Portable::isActive()
        ? std::make_unique<FileLogger>(nullptr, Portable::dataDirectory() + QStringLiteral("/logs"))
        : std::make_unique<FileLogger>();
    Logger::instance().addMessage(QString("%1 (%2) logging started...").arg(app.applicationDisplayName()).arg(app.applicationVersion()));

    gnutls_global_init();
#ifndef _WIN32
    signal(SIGPIPE, SIG_IGN);
#endif
    openconnect_init_ssl();

    QCommandLineParser parser;
    parser.setApplicationDescription(
        QObject::tr("OpenConnect is a VPN client, that utilizes TLS and DTLS "
                    "for secure session establishment, and is compatible "
                    "with many VPN protocols."));
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addOption({ { "s", "server" },
        QObject::tr("auto-connect to existing profile <name>"),
        QObject::tr("name")

    });
    // Passed by the scheduled task that starts the program when the user signs
    // in, so that "connect when I sign in" can be a separate setting from
    // "connect when the program starts".
    parser.addOption({ QStringLiteral("logon"),
        QObject::tr("started by the sign-in task") });
    // Both are handled long before this, and named here so that --help lists them.
    parser.addOption({ QStringLiteral("install"),
        QObject::tr("install this copy and exit") });
    parser.addOption({ QStringLiteral("uninstall"),
        QObject::tr("remove an installed copy of Ocelot") });

    parser.process(app);

    // The interface is drawn in a rounded face, and the only way to be sure it
    // is there is to carry it. Without it Qt falls back to the system sans
    // serif, which is legible but not the same program.
    if (QFontDatabase::addApplicationFont(QStringLiteral(":/fonts/Nunito.ttf")) < 0) {
        Logger::instance().addMessage(
            QObject::tr("The bundled font could not be loaded; falling back to the system one"));
    } else {
        QFont font(QStringLiteral("Nunito"));
        font.setPixelSize(app.font().pixelSize() > 0 ? app.font().pixelSize() : 13);
        app.setFont(font);
    }

    VpnController controller(haveTray);
    LogModel logModel;

    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QQmlApplicationEngine engine;
    // Given before the interface is loaded, so a change of language can re-read
    // what is on screen rather than wait for the next start.
    controller.setQmlEngine(&engine);
    engine.rootContext()->setContextProperty(QStringLiteral("controller"), &controller);
    engine.rootContext()->setContextProperty(QStringLiteral("logModel"), &logModel);
    engine.loadFromModule("Ocelot", "Main");

    if (engine.rootObjects().isEmpty()) {
        Logger::instance().addMessage(QObject::tr("Could not load the user interface"));
        return -1;
    }

#ifdef PROJ_PKCS11
    gnutls_pkcs11_set_pin_function(pin_callback, &controller);
#endif
    gnutls_global_set_log_function(log_callback);
#ifdef PROJ_GNUTLS_DEBUG
    gnutls_global_set_log_level(3);
#endif

    QObject::connect(&app, &QtSingleApplication::messageReceived,
        [&controller](const QString& message) {
            Logger::instance().addMessage(message);
            // Sent by a copy that is being uninstalled: this one is in the way,
            // and leaves rather than coming forward.
            if (message == QStringLiteral("quit")) {
                controller.quit();
                return;
            }
            controller.showWindow();
        });

    const QString profileName{ parser.value(QLatin1String("server")) };
    const bool launchedByLogonTask = parser.isSet(QLatin1String("logon"));

    if (profileName.isEmpty() == false) {
        QTimer::singleShot(0, &controller, [&controller, profileName]() {
            controller.connectToProfile(profileName);
        });
    } else {
        // A moment after the window exists, so the server's questions have
        // somewhere to be asked.
        QTimer::singleShot(600, &controller, [&controller, launchedByLogonTask]() {
            controller.applyStartupActions(launchedByLogonTask);
        });
    }

    return app.exec();
}
