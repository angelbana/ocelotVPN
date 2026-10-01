/*
 * Copyright (C) 2014, 2015 Red Hat
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

#include "VpnController.h"
#include "Autostart.h"
#include "Portable.h"
#include "Updater.h"
#include "config.h"
#include "logger.h"
#include "server_storage.h"
#include "timestamp.h"
#include "vpninfo.h"

extern "C" {
#include <gnutls/gnutls.h>
}
#ifdef USE_SYSTEM_KEYS
extern "C" {
#include <gnutls/system-keys.h>
}
#endif

#include <spdlog/spdlog.h>

#include <QAction>
#include <QApplication>
#include <QClipboard>
#include <QDateTime>
#include <QEvent>
#include <QEventLoop>
#include <QFileSelector>
#include <QIcon>
#include <QLocale>
#include <QMenu>
#include <QNetworkAccessManager>
#include <QNetworkProxyFactory>
#include <QNetworkProxyQuery>
#include <QNetworkReply>
#include <QCryptographicHash>
#include <QDir>
#include <QFileDialog>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QTextStream>
#include <QVersionNumber>
#include <QFile>
#include <QFileInfo>
#include <QNetworkRequest>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QSysInfo>
#include <QQmlEngine>
#include <QSystemTrayIcon>
#include <QTranslator>
#include <QThread>
#include <QTimer>
#include <QUrl>
#include <QtConcurrent/QtConcurrentRun>
#include <OcSettings.h>

#include <algorithm>
#include <cmath>

#ifdef _WIN32
#define pipe_write(x, y, z) send(x, y, z, 0)
#else
#define pipe_write(x, y, z) write(x, y, z)
#endif

// LCA: drop this define from whole project...
#define PREFIX "server:"

static QString normalize_byte_size(uint64_t bytes)
{
    const unsigned unit = 1024;
    if (bytes < unit) {
        return QString("%1 B").arg(QString::number(bytes));
    }
    const int exp = static_cast<int>(std::log(bytes) / std::log(unit));
    static const char suffixChar[] = "KMGTPE";
    return QString("%1 %2B").arg(QString::number(bytes / std::pow(unit, exp), 'f', 1)).arg(suffixChar[exp - 1]);
}

static void main_loop(VpnInfo* vpninfo, VpnController* controller)
{
    controller->setStatus(VpnController::StatusConnecting);

    bool pass_was_empty;
    bool reset_password = false;
    pass_was_empty = vpninfo->ss->get_password().isEmpty();

    QString ip, ip6, dns, cstp, dtls, domains;

    int ret = 0;
    bool retry = false;
    int retries = 2;
    do {
        retry = false;
        ret = vpninfo->connect();
        if (ret != 0) {
            if (retries-- <= 0)
                goto fail;

            QString oldpass, oldgroup;
            if (pass_was_empty != true) {
                /* authentication failed in batch mode? switch to non
                 * batch and retry */
                oldpass = vpninfo->ss->get_password();
                oldgroup = vpninfo->ss->get_groupname();
                vpninfo->ss->clear_password();
                vpninfo->ss->clear_groupname();
                retry = true;
                reset_password = true;
                Logger::instance().addMessage(QObject::tr("Authentication failed in batch mode, retrying with batch mode disabled"));
                vpninfo->reset_vpn();
                continue;
            }

            /* if we didn't manage to connect on a retry, the failure reason
             * may not have been a changed password, reset it */
            if (reset_password == true) {
                vpninfo->ss->set_password(oldpass);
                vpninfo->ss->set_groupname(oldgroup);
            }

            Logger::instance().addMessage(vpninfo->last_err);
            goto fail;
        }

    } while (retry == true);

    vpninfo->get_info(dns, ip, ip6, domains);
    vpninfo->get_cipher_info(cstp, dtls);
    controller->setTunnelInfo(dns, ip, ip6, cstp, dtls, domains);
    vpninfo->logServerOptions();
    controller->setStatus(VpnController::StatusConnected);

    vpninfo->ss->save();
    vpninfo->mainloop();

fail:
    controller->setStatus(VpnController::StatusDisconnected);

    delete vpninfo;
}

void VpnController::cleanupNrptRules(bool flushCache)
{
#ifdef Q_OS_WIN
    // Only rules carrying this comment are removed: an administrator's own rule
    // for the same domain has to survive us. The vpnc script writes the same
    // tag when it creates them - keep the two in step, see
    // contrib/vpnc-script-win.js.
    const QString script = QStringLiteral(
        "Get-DnsClientNrptRule | Where-Object { $_.Comment -eq 'ocelot' } |"
        " ForEach-Object { Remove-DnsClientNrptRule -Name $_.Name -Force }");

    // Removing a rule needs administrator rights, which the program already has:
    // it asks for them at every start, to create the tun device.
    QProcess* process = new QProcess(this);
    connect(process, &QProcess::finished, this,
        [this, process, flushCache](int exitCode, QProcess::ExitStatus status) {
            if (status != QProcess::NormalExit || exitCode != 0) {
                Logger::instance().addMessage(
                    tr("Could not clear the split DNS rules (exit code %1)").arg(exitCode));
            } else if (flushCache == true) {
                // Whatever is cached for those domains was answered through the
                // tunnel, so it outlives the rules unless the cache is dropped.
                QProcess::startDetached(QStringLiteral("ipconfig"),
                    QStringList() << QStringLiteral("/flushdns"));
            }
            process->deleteLater();
        });

    process->start(QStringLiteral("powershell"), QStringList()
            << QStringLiteral("-NoProfile")
            << QStringLiteral("-NonInteractive")
            << QStringLiteral("-ExecutionPolicy") << QStringLiteral("Bypass")
            << QStringLiteral("-Command") << script);
#else
    Q_UNUSED(flushCache);
#endif
}

void VpnController::repairDns()
{
    Logger::instance().addMessage(tr("Clearing the split DNS rules left behind by the program"));
    cleanupNrptRules(true);
}

bool VpnController::portableMode() const
{
    return Portable::isActive();
}

bool VpnController::installSupported() const
{
    return Portable::canInstall();
}

bool VpnController::installedCopy() const
{
    return Portable::isInstalledCopy();
}

QString VpnController::installLocation() const
{
    return QDir::toNativeSeparators(Portable::isInstalledCopy() == true
            ? QCoreApplication::applicationDirPath()
            : Portable::installDirectory());
}

QString VpnController::dataLocation() const
{
    return QDir::toNativeSeparators(Portable::isActive() == true
            ? Portable::dataDirectory()
            : QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation));
}

void VpnController::installProgram()
{
    QString error;
    if (Portable::install(error) == false) {
        emit errorOccurred(tr("Install Ocelot"), error);
        return;
    }

    emit installFinished();
}

void VpnController::uninstallProgram()
{
    QString error;
    if (Portable::uninstall(error) == false) {
        emit errorOccurred(tr("Remove Ocelot"), error);
        return;
    }

    quit();
}

void VpnController::launchInstalledCopy()
{
    QString error;
    if (Portable::launchInstalledAfterExit(error) == false) {
        emit errorOccurred(tr("Install Ocelot"), error);
        return;
    }

    quit();
}

VpnController::VpnController(bool useTray, QObject* parent)
    : QObject(parent)
    , m_status(StatusDisconnected)
    , m_cmd_fd(INVALID_SOCKET)
    , m_minimizeOnConnect(false)
    , m_quitWhenDisconnected(false)
    , m_statsTimer(new QTimer(this))
    , m_rxRate(0)
    , m_txRate(0)
    , m_lastRxBytes(0)
    , m_lastTxBytes(0)
    , m_lastSampleTime(0)
    , m_connectedSince(0)
    , m_checkingForUpdates(false)
    , m_lastCheckTime(0)
    , m_network(new QNetworkAccessManager(this))
    , m_updater(new Updater(this))
    , m_trayIcon(nullptr)
    , m_theme(ThemeOcelot)
    , m_windowStyle(WindowStyleOcelot)
    , m_language(LanguageSystem)
    , m_translator(nullptr)
    , m_qmlEngine(nullptr)
    , m_logLevel(PRG_INFO)
    , m_minimizeToTray(true)
    , m_minimizeInsteadOfClose(true)
    , m_startMinimized(false)
    , m_singleInstance(true)
    , m_connectOnStart(false)
    , m_connectOnLogon(false)
    , m_reconnectOnDrop(true)
    , m_notifyOnChange(true)
    , m_checkUpdates(true)
    , m_userAskedToDisconnect(false)
    , m_wasConnected(false)
    , m_reconnectAttempts(0)
    , m_reconnectTimer(new QTimer(this))
    , m_promptLoop(nullptr)
    , m_promptRemember(false)
    , m_promptAccepted(false)
    , m_promptAnswered(false)
{
    QNetworkProxyFactory::setUseSystemConfiguration(true);

    connect(m_statsTimer, &QTimer::timeout,
        this, &VpnController::requestStats);

    m_reconnectTimer->setSingleShot(true);
    connect(m_reconnectTimer, &QTimer::timeout, this, [this]() {
        emit reconnectPendingChanged();
        if (m_status == StatusDisconnected) {
            Logger::instance().addMessage(
                tr("Dialling again after the connection was lost (attempt %1)")
                    .arg(m_reconnectAttempts));
            connectVpn();
        }
    });
    connect(m_network, &QNetworkAccessManager::finished,
        this, &VpnController::gotLatestVersion);

    readSettings();
    reloadProfiles();

    // A connection that ended without a disconnect - a crash, a kill, a reboot
    // while connected - leaves its split DNS rules behind, and the domains they
    // name stop resolving. Starting the program is enough to undo that; the
    // resolver cache is left alone, since clearing it at every start would be a
    // visible thing to do without being asked.
    cleanupNrptRules(false);

    if (useTray) {
        createTrayIcon();
    } else {
        Logger::instance().addMessage(QLatin1String("System doesn't support tray icon"));
    }

    QTimer::singleShot(4000, this, &VpnController::tryCheckLatestVersion);

    connect(m_updater, &Updater::progressChanged, this, &VpnController::updateProgressChanged);
    connect(m_updater, &Updater::ready, this, &VpnController::updateReady);
    connect(m_updater, &Updater::failed, this, [this](const QString& message) {
        emit errorOccurred(tr("Update Ocelot"), message);
    });
}

VpnController::~VpnController()
{
    int counter = 10;
    m_statsTimer->stop();

    if (m_futureWatcher.isRunning() == true) {
        terminateConnection();
    }
    while (m_futureWatcher.isRunning() == true && counter > 0) {
        ms_sleep(200);
        counter--;
    }

    writeSettings();
}

int VpnController::status() const
{
    return m_status;
}

QStringList VpnController::profiles() const
{
    return m_profiles;
}

QString VpnController::currentProfile() const
{
    return m_currentProfile;
}

void VpnController::setCurrentProfile(const QString& name)
{
    if (m_currentProfile == name) {
        return;
    }

    m_currentProfile = name;
    loadCurrentProfileInfo();

    emit currentProfileChanged();
}

void VpnController::loadCurrentProfileInfo()
{
    m_gateway.clear();
    m_protocolName.clear();
    m_protocolShortName.clear();
    m_profileEmoji.clear();

    if (m_currentProfile.isEmpty() == true) {
        return;
    }

    OcSettings settings;
    settings.beginGroup(PREFIX + m_currentProfile);
    m_gateway = settings.value("server").toString();
    m_profileEmoji = settings.value("emoji", defaultProfileEmoji()).toString();
    const QString protocol = settings.value("protocol-name").toString();
    settings.endGroup();

    for (const auto& item : protocols()) {
        const QVariantMap entry = item.toMap();
        if (entry.value("name").toString() == protocol) {
            m_protocolName = entry.value("label").toString();
            m_protocolShortName = entry.value("short").toString();
            break;
        }
    }
}

QString VpnController::gateway() const
{
    return m_gateway;
}

QString VpnController::protocolName() const
{
    return m_protocolName;
}

QString VpnController::protocolShortName() const
{
    return m_protocolShortName;
}

QString VpnController::profileEmoji() const
{
    return m_profileEmoji;
}

// Read out of the settings rather than by loading each profile: loading one
// decodes its certificates and its password, which is far too much work for
// drawing a list.
QVariantList VpnController::profileEntries() const
{
    QVariantList entries;
    OcSettings settings;

    for (const QString& name : m_profiles) {
        settings.beginGroup(PREFIX + name);
        QVariantMap entry;
        entry["name"] = name;
        entry["gateway"] = settings.value("server").toString();
        entry["lastConnected"] = settings.value("last-connected", 0).toLongLong();
        entry["emoji"] = settings.value("emoji", defaultProfileEmoji()).toString();
        settings.endGroup();
        entries.append(entry);
    }

    return entries;
}

QStringList VpnController::emojiChoices() const
{
    // Chosen to cover what people actually name a VPN after - an office, a
    // home, a laboratory, a customer - and to stay legible at the size the
    // lists draw them.
    return QStringList{
        QStringLiteral("🐾"), QStringLiteral("🏢"), QStringLiteral("🏠"), QStringLiteral("🔬"),
        QStringLiteral("🧪"), QStringLiteral("🚀"), QStringLiteral("🌍"), QStringLiteral("🔐"),
        QStringLiteral("💼"), QStringLiteral("☁️"), QStringLiteral("🐟"), QStringLiteral("🌱"),
        QStringLiteral("⚡"), QStringLiteral("🎓"), QStringLiteral("🛰️"), QStringLiteral("🏭")
    };
}

QString VpnController::ip() const
{
    return m_ip;
}

QString VpnController::ip6() const
{
    return m_ip6;
}

QString VpnController::searchDomains() const
{
    return m_searchDomains;
}

QString VpnController::dns() const
{
    return m_dns;
}

QString VpnController::cstpCipher() const
{
    return m_cstpCipher;
}

QString VpnController::dtlsCipher() const
{
    return m_dtlsCipher;
}

QString VpnController::received() const
{
    return m_received;
}

QString VpnController::sent() const
{
    return m_sent;
}

double VpnController::rxRate() const
{
    return m_rxRate;
}

double VpnController::txRate() const
{
    return m_txRate;
}

QString VpnController::uptime() const
{
    if (m_connectedSince == 0) {
        return QString();
    }

    const qint64 seconds = qMax<qint64>(0, QDateTime::currentSecsSinceEpoch() - m_connectedSince);
    const qint64 hours = seconds / 3600;
    const qint64 minutes = (seconds % 3600) / 60;

    if (hours > 0) {
        return QStringLiteral("%1:%2:%3")
            .arg(hours)
            .arg(minutes, 2, 10, QLatin1Char('0'))
            .arg(seconds % 60, 2, 10, QLatin1Char('0'));
    }
    return QStringLiteral("%1:%2")
        .arg(minutes, 2, 10, QLatin1Char('0'))
        .arg(seconds % 60, 2, 10, QLatin1Char('0'));
}

QString VpnController::appVersion() const
{
    return QLatin1String(PROJECT_VERSION);
}

QString VpnController::releaseVersion() const
{
    return QLatin1String(INTERNAL_PROJECT_VERSION);
}

QString VpnController::repoUrl() const
{
    return QLatin1String(APP_REPO_URL);
}

QString VpnController::issuesUrl() const
{
    return QLatin1String(APP_ISSUES_URL);
}

QString VpnController::latestVersion() const
{
    return m_latestVersion;
}

bool VpnController::updateAvailable() const
{
    // Compared as numbers: read as text, 1.0.10 looks older than 1.0.9, and a
    // build made here that runs ahead of the published one would be told to
    // downgrade itself.
    return QVersionNumber::fromString(m_latestVersion)
        > QVersionNumber::fromString(QLatin1String(INTERNAL_PROJECT_VERSION));
}

bool VpnController::checkingForUpdates() const
{
    return m_checkingForUpdates;
}

bool VpnController::hasTray() const
{
    return m_trayIcon != nullptr;
}

int VpnController::theme() const
{
    return m_theme;
}

void VpnController::setTheme(int mode)
{
    if (m_theme == mode) {
        return;
    }
    m_theme = mode;
    emit settingsChanged();
}

int VpnController::logLevel() const
{
    return m_logLevel;
}

void VpnController::setLogLevel(int level)
{
    if (m_logLevel == level) {
        return;
    }
    m_logLevel = level;
    emit settingsChanged();
}

bool VpnController::minimizeToTray() const
{
    return m_minimizeToTray;
}

void VpnController::setMinimizeToTray(bool value)
{
    if (m_minimizeToTray == value) {
        return;
    }
    m_minimizeToTray = value;
    emit settingsChanged();
}

bool VpnController::minimizeInsteadOfClose() const
{
    return m_minimizeInsteadOfClose;
}

void VpnController::setMinimizeInsteadOfClose(bool value)
{
    if (m_minimizeInsteadOfClose == value) {
        return;
    }
    m_minimizeInsteadOfClose = value;
    emit settingsChanged();
}

bool VpnController::startMinimized() const
{
    return m_startMinimized;
}

void VpnController::setStartMinimized(bool value)
{
    if (m_startMinimized == value) {
        return;
    }
    m_startMinimized = value;
    emit settingsChanged();
}

bool VpnController::singleInstance() const
{
    return m_singleInstance;
}

void VpnController::setSingleInstance(bool value)
{
    if (m_singleInstance == value) {
        return;
    }
    m_singleInstance = value;
    OcSettings settings;
    settings.setValue("Settings/singleInstanceMode", value);
    emit settingsChanged();
}

int VpnController::windowStyle() const
{
    return m_windowStyle;
}

void VpnController::setWindowStyle(int style)
{
    if (style < WindowStyleOcelot || style > WindowStyleSystem || m_windowStyle == style) {
        return;
    }

    m_windowStyle = style;
    OcSettings settings;
    settings.setValue("Settings/windowStyle", m_windowStyle);
    emit settingsChanged();
}

int VpnController::language() const
{
    return m_language;
}

void VpnController::setLanguage(int language)
{
    if (language < LanguageSystem || language > LanguageRussian || m_language == language) {
        return;
    }

    m_language = language;
    OcSettings settings;
    settings.setValue("Settings/language", m_language);
    applyLanguage();
    emit settingsChanged();

    // Everything already on screen is re-read here; without this the new
    // language would only show on the next start.
    if (m_qmlEngine != nullptr) {
        m_qmlEngine->retranslate();
    }
    updateTrayIcon();
}

QVariantList VpnController::languages() const
{
    // Each language is named in itself: someone looking for Russian is looking
    // for the word "Русский", not for "Russian".
    QVariantList list;

    QVariantMap system;
    system["value"] = LanguageSystem;
    system["label"] = tr("Same as Windows");
    list.append(system);

    QVariantMap english;
    english["value"] = LanguageEnglish;
    english["label"] = QStringLiteral("English");
    list.append(english);

    QVariantMap russian;
    russian["value"] = LanguageRussian;
    russian["label"] = QStringLiteral("Русский");
    list.append(russian);

    return list;
}

// English is what the interface is written in, so it needs no translation file;
// every other language is a compiled translation carried inside the program.
void VpnController::applyLanguage()
{
    if (m_translator != nullptr) {
        QCoreApplication::removeTranslator(m_translator);
        delete m_translator;
        m_translator = nullptr;
    }

    bool wantRussian = (m_language == LanguageRussian);
    if (m_language == LanguageSystem) {
        wantRussian = QLocale::system().language() == QLocale::Russian;
    }

    if (wantRussian == false) {
        return;
    }

    m_translator = new QTranslator(this);
    if (m_translator->load(QStringLiteral(":/i18n/ocelot_ru.qm")) == false) {
        Logger::instance().addMessage(
            QStringLiteral("The Russian translation could not be loaded"));
        delete m_translator;
        m_translator = nullptr;
        return;
    }

    QCoreApplication::installTranslator(m_translator);
}

void VpnController::setQmlEngine(QQmlEngine* engine)
{
    m_qmlEngine = engine;
}

bool VpnController::autostartSupported() const
{
    return Autostart::isSupported();
}

// Asked of the system every time rather than kept in the settings: the task can
// be removed in the scheduler or by another installation, and a switch that
// claims to be on while nothing is registered is worse than no switch.
bool VpnController::autostart() const
{
    return Autostart::isEnabled();
}

void VpnController::setAutostart(bool value)
{
    if (Autostart::isEnabled() == value) {
        return;
    }

    QString error;
    if (Autostart::setEnabled(value, error) == false) {
        emit errorOccurred(tr("Starting with Windows"),
            error.isEmpty() ? tr("The scheduled task could not be changed.") : error);
    }

    // Connecting at sign-in cannot happen if the program is not started then.
    if (value == false && m_connectOnLogon == true) {
        m_connectOnLogon = false;
        OcSettings settings;
        settings.setValue("Settings/connectOnLogon", false);
    }

    emit settingsChanged();
}

bool VpnController::connectOnStart() const
{
    return m_connectOnStart;
}

void VpnController::setConnectOnStart(bool value)
{
    if (m_connectOnStart == value) {
        return;
    }
    m_connectOnStart = value;
    OcSettings settings;
    settings.setValue("Settings/connectOnStart", value);
    emit settingsChanged();
}

bool VpnController::connectOnLogon() const
{
    return m_connectOnLogon;
}

void VpnController::setConnectOnLogon(bool value)
{
    if (m_connectOnLogon == value) {
        return;
    }

    // The program has to be started at sign-in before it can connect then, so
    // turning this on turns that on as well rather than quietly doing nothing.
    if (value == true && Autostart::isSupported() == true
        && Autostart::isEnabled() == false) {
        QString error;
        if (Autostart::setEnabled(true, error) == false) {
            emit errorOccurred(tr("Connecting when you sign in"),
                error.isEmpty() ? tr("The scheduled task could not be created.") : error);
            return;
        }
    }

    m_connectOnLogon = value;
    OcSettings settings;
    settings.setValue("Settings/connectOnLogon", value);
    emit settingsChanged();
}

bool VpnController::reconnectOnDrop() const
{
    return m_reconnectOnDrop;
}

void VpnController::setReconnectOnDrop(bool value)
{
    if (m_reconnectOnDrop == value) {
        return;
    }
    m_reconnectOnDrop = value;
    if (value == false) {
        cancelReconnect();
    }
    OcSettings settings;
    settings.setValue("Settings/reconnectOnDrop", value);
    emit settingsChanged();
}

QString VpnController::autoConnectProfile() const
{
    return m_autoConnectProfile;
}

void VpnController::setAutoConnectProfile(const QString& name)
{
    if (m_autoConnectProfile == name) {
        return;
    }
    m_autoConnectProfile = name;
    OcSettings settings;
    settings.setValue("Settings/autoConnectProfile", name);
    emit settingsChanged();
}

bool VpnController::notifyOnChange() const
{
    return m_notifyOnChange;
}

void VpnController::setNotifyOnChange(bool value)
{
    if (m_notifyOnChange == value) {
        return;
    }
    m_notifyOnChange = value;
    OcSettings settings;
    settings.setValue("Settings/notifyOnChange", value);
    emit settingsChanged();
}

bool VpnController::checkUpdates() const
{
    return m_checkUpdates;
}

void VpnController::setCheckUpdates(bool value)
{
    if (m_checkUpdates == value) {
        return;
    }
    m_checkUpdates = value;
    OcSettings settings;
    settings.setValue("Settings/checkUpdates", value);
    emit settingsChanged();
}

bool VpnController::reconnectPending() const
{
    return m_reconnectTimer->isActive();
}

// The waits grow with each attempt: a server that is down stays down for a
// while, and dialling it every five seconds for an hour helps nobody. After the
// last attempt the program stops and leaves it to the person.
void VpnController::scheduleReconnect()
{
    static const int delays[] = { 5, 10, 20, 30, 60, 60, 120 };
    const int attempts = int(sizeof(delays) / sizeof(delays[0]));

    if (m_reconnectAttempts >= attempts) {
        Logger::instance().addMessage(
            tr("Giving up on dialling again; connect by hand when the server is back"));
        m_reconnectAttempts = 0;
        return;
    }

    const int delay = delays[m_reconnectAttempts];
    m_reconnectAttempts++;

    Logger::instance().addMessage(
        tr("The connection was lost; dialling again in %1 seconds").arg(delay));
    m_reconnectTimer->start(delay * 1000);
    emit reconnectPendingChanged();
}

void VpnController::cancelReconnect()
{
    if (m_reconnectTimer->isActive() == true) {
        m_reconnectTimer->stop();
        emit reconnectPendingChanged();
    }
}

// Called once the interface exists. Connecting before that would leave the
// server's questions - a password, a group, a certificate to trust - with
// nowhere to be asked.
void VpnController::applyStartupActions(bool launchedByLogonTask)
{
    const bool wanted = launchedByLogonTask ? m_connectOnLogon : m_connectOnStart;
    if (wanted == false) {
        return;
    }

    const QString name = m_autoConnectProfile.isEmpty() ? m_currentProfile : m_autoConnectProfile;
    if (name.isEmpty() == true || m_profiles.contains(name) == false) {
        Logger::instance().addMessage(
            tr("Nothing was connected at start: no profile is named for it"));
        return;
    }

    Logger::instance().addMessage(tr("Connecting to %1 at start").arg(name));
    connectToProfile(name);
}

QRect VpnController::trayIconGeometry() const
{
    return m_trayIcon != nullptr ? m_trayIcon->geometry() : QRect();
}

int VpnController::appLogLevel() const
{
    return m_logLevel;
}

void VpnController::connectVpn()
{
    cancelReconnect();
    m_userAskedToDisconnect = false;

    if (m_cmd_fd != INVALID_SOCKET || m_futureWatcher.isRunning() == true) {
        emit errorOccurred(tr("Connection failed"),
            tr("A previous VPN instance is still running."));
        return;
    }

    if (m_currentProfile.isEmpty() == true) {
        emit errorOccurred(tr("Connection failed"),
            tr("Select a VPN profile to connect to."));
        return;
    }

    QString name = m_currentProfile;
    StoredServer* ss = new StoredServer();
    if (ss->load(name) == 0) {
        delete ss;
        emit errorOccurred(tr("Connection failed"),
            tr("Selected VPN profile '%1' does not exist.").arg(name));
        return;
    }

    QUrl url;
    const QString gateway = ss->get_server_gateway();
    if (gateway.contains(QLatin1String("https://"), Qt::CaseInsensitive)) {
        url.setUrl(gateway);
    } else {
        url.setUrl(QLatin1String("https://") + gateway);
    }

    VpnInfo* vpninfo = nullptr;
    /* ss is now deallocated by vpninfo */
    try {
        vpninfo = new VpnInfo(QStringLiteral("AnyConnect-compatible OpenConnect GUI VPN Agent"), ss, this);
    } catch (std::exception& ex) {
        emit errorOccurred(tr("Connection failed"),
            tr("There was an issue initializing the VPN (%1).").arg(ex.what()));
        return;
    }

    m_minimizeOnConnect = vpninfo->get_minimize();
    vpninfo->setUrl(url);

    m_cmd_fd = vpninfo->get_cmd_fd();
    if (m_cmd_fd == INVALID_SOCKET) {
        delete vpninfo;
        emit errorOccurred(tr("Connection failed"),
            tr("There was an issue establishing IPC with openconnect; try restarting the application."));
        return;
    }

    if (ss->get_proxy()) {
        QNetworkProxyQuery query;
        query.setUrl(url);

        const QList<QNetworkProxy> proxies = QNetworkProxyFactory::systemProxyForQuery(query);
        if (proxies.size() > 0 && proxies.at(0).type() != QNetworkProxy::NoProxy) {
            QString scheme;
            if (proxies.at(0).type() == QNetworkProxy::Socks5Proxy) {
                scheme = QLatin1String("socks5://");
            } else if (proxies.at(0).type() == QNetworkProxy::HttpCachingProxy
                || proxies.at(0).type() == QNetworkProxy::HttpProxy) {
                scheme = QLatin1String("http://");
            }

            if (scheme.isEmpty() == false) {
                QString str;
                if (proxies.at(0).user().isEmpty() != true) {
                    str = proxies.at(0).user() + ":" + proxies.at(0).password() + "@";
                }
                str += proxies.at(0).hostName();
                if (proxies.at(0).port() != 0) {
                    str += ":" + QString::number(proxies.at(0).port());
                }

                Logger::instance().addMessage(tr("Setting proxy to: %1").arg(str));

                if (openconnect_set_http_proxy(vpninfo->vpninfo, (scheme + str).toUtf8().data()) != 0) {
                    Logger::instance().addMessage(tr("Unexpected error setting proxy"));
                }
            }
        }
    }

    // Read by the vpnc script when it sets up name resolution. An environment
    // variable, because that is the only channel between this program and a
    // script openconnect runs on its own.
    qputenv("OC_DNS_MODE", ss->get_dns_mode() == 1 ? "all" : "auto");

    m_futureWatcher.setFuture(QtConcurrent::run(main_loop, vpninfo, this));
}

void VpnController::disconnectVpn()
{
    // Asked for by a person, so the connection is not one to dial again.
    m_userAskedToDisconnect = true;
    m_reconnectAttempts = 0;
    cancelReconnect();

    m_statsTimer->stop();
    Logger::instance().addMessage(QObject::tr("Disconnecting..."));
    terminateConnection();
}

void VpnController::connectToProfile(const QString& name)
{
    setCurrentProfile(name);
    connectVpn();
}

void VpnController::terminateConnection()
{
    char cmd = OC_CMD_CANCEL;

    if (m_cmd_fd != INVALID_SOCKET) {
        setStatus(StatusDisconnecting);
        int ret = pipe_write(m_cmd_fd, &cmd, 1);
        if (ret < 0) {
            Logger::instance().addMessage(QObject::tr("term_thread: IPC error: %1").arg(net_errno));
        }
        m_cmd_fd = INVALID_SOCKET;
        ms_sleep(200);
    } else {
        setStatus(StatusDisconnected);
    }
}

void VpnController::setStatus(int status)
{
    QMetaObject::invokeMethod(
        this, [this, status]() {
            m_status = status;

            switch (status) {
            case StatusConnected: {
                m_statsTimer->start(UPDATE_TIMER);
                m_wasConnected = true;
                m_reconnectAttempts = 0;
                m_connectedSince = QDateTime::currentSecsSinceEpoch();
                m_lastSampleTime = 0;
                m_lastRxBytes = 0;
                m_lastTxBytes = 0;

                // Remembered against the profile, so the list can say when each
                // one was last used - which is how a person tells two similar
                // profiles apart.
                if (m_currentProfile.isEmpty() == false) {
                    OcSettings settings;
                    settings.setValue(QLatin1String(PREFIX) + m_currentProfile
                            + QLatin1String("/last-connected"),
                        m_connectedSince);
                    emit profilesChanged();
                }

                const bool hidden = (m_minimizeOnConnect == true && m_trayIcon != nullptr);
                if (m_minimizeOnConnect == true) {
                    if (m_trayIcon != nullptr) {
                        emit windowHideRequested();
                    } else {
                        emit windowMinimizeRequested();
                    }
                }

                // A window that has just taken itself away owes an explanation,
                // so that case says so whatever the setting.
                if (m_trayIcon != nullptr && (m_notifyOnChange == true || hidden == true)) {
                    m_trayIcon->showMessage(tr("Connected"),
                        tr("You are connected to %1").arg(m_currentProfile),
                        QSystemTrayIcon::Information, 6000);
                }
                break;
            }

            case StatusDisconnected:
                m_statsTimer->stop();
                m_cmd_fd = INVALID_SOCKET;
                m_ip.clear();
                m_ip6.clear();
                m_dns.clear();
                m_cstpCipher.clear();
                m_dtlsCipher.clear();
                m_received.clear();
                m_sent.clear();
                m_rxRate = 0;
                m_txRate = 0;
                m_connectedSince = 0;
                Logger::instance().addMessage(QObject::tr("Disconnected"));
                emit tunnelChanged();
                emit statsChanged();
                emit readyToShutdown();

                // A connection that was up and is now down without anyone
                // asking for that is the case worth dialling again. A failure
                // to connect in the first place is not: it is usually a wrong
                // password or an unreachable server, and retrying would just
                // repeat it.
                if (m_reconnectOnDrop == true && m_userAskedToDisconnect == false
                    && m_quitWhenDisconnected == false && m_wasConnected == true) {
                    scheduleReconnect();
                }

                if (m_trayIcon != nullptr && m_notifyOnChange == true
                    && m_wasConnected == true && m_quitWhenDisconnected == false) {
                    m_trayIcon->showMessage(
                        m_userAskedToDisconnect ? tr("Disconnected") : tr("The connection dropped"),
                        m_userAskedToDisconnect
                            ? tr("The tunnel to %1 is closed.").arg(m_currentProfile)
                            : tr("The tunnel to %1 went down.").arg(m_currentProfile),
                        QSystemTrayIcon::Information, 6000);
                }
                m_wasConnected = false;
                break;

            default:
                break;
            }

            updateTrayIcon();
            emit statusChanged();

            if (status == StatusDisconnected && m_quitWhenDisconnected == true) {
                qApp->quit();
            }
        },
        Qt::QueuedConnection);
}

void VpnController::setTunnelInfo(const QString& dns, const QString& ip, const QString& ip6,
    const QString& cstpCipher, const QString& dtlsCipher, const QString& searchDomains)
{
    QMetaObject::invokeMethod(
        this, [this, dns, ip, ip6, cstpCipher, dtlsCipher, searchDomains]() {
            m_searchDomains = searchDomains;
            m_dns = dns;
            m_ip = ip;
            m_ip6 = ip6;
            m_cstpCipher = cstpCipher;
            m_dtlsCipher = dtlsCipher;
            emit tunnelChanged();
        },
        Qt::QueuedConnection);
}

bool VpnController::rememberRequested() const
{
    QMutexLocker lock(&m_promptMutex);
    return m_promptRemember;
}

void VpnController::updateStats(const struct oc_stats* stats, const QString& dtlsCipher)
{
    const QString received = normalize_byte_size(stats->rx_bytes);
    const QString sent = normalize_byte_size(stats->tx_bytes);
    const quint64 rxBytes = stats->rx_bytes;
    const quint64 txBytes = stats->tx_bytes;

    QMetaObject::invokeMethod(
        this, [this, received, sent, rxBytes, txBytes, dtlsCipher]() {
            m_received = received;
            m_sent = sent;

            // Two samples make a rate. The counters only ever grow while a
            // tunnel is up, and a new tunnel starts them from zero, so a
            // smaller number than last time means a new connection rather than
            // a negative rate.
            const qint64 now = QDateTime::currentMSecsSinceEpoch();
            const qint64 elapsed = now - m_lastSampleTime;
            if (m_lastSampleTime > 0 && elapsed > 0 && rxBytes >= m_lastRxBytes
                && txBytes >= m_lastTxBytes) {
                m_rxRate = (rxBytes - m_lastRxBytes) * 1000.0 / elapsed;
                m_txRate = (txBytes - m_lastTxBytes) * 1000.0 / elapsed;
            } else {
                m_rxRate = 0;
                m_txRate = 0;
            }
            m_lastRxBytes = rxBytes;
            m_lastTxBytes = txBytes;
            m_lastSampleTime = now;

            emit statsChanged();

            if (dtlsCipher != m_dtlsCipher) {
                m_dtlsCipher = dtlsCipher;
                emit tunnelChanged();
            }
        },
        Qt::QueuedConnection);
}

void VpnController::requestStats()
{
    char cmd = OC_CMD_STATS;
    if (m_cmd_fd != INVALID_SOCKET) {
        int ret = pipe_write(m_cmd_fd, &cmd, 1);
        if (ret < 0) {
            Logger::instance().addMessage(QObject::tr("update_stats: IPC error: %1").arg(net_errno));
            m_statsTimer->stop();
        }
    } else {
        Logger::instance().addMessage(QObject::tr("update_stats: invalid socket"));
        m_statsTimer->stop();
    }
}

bool VpnController::askPrompt(PromptType type, const QVariantMap& request, QString& text)
{
    {
        QMutexLocker lock(&m_promptMutex);
        m_promptAnswered = false;
        m_promptAccepted = false;
        m_promptRemember = false;
        m_promptText.clear();
    }

    emit promptRequested(type, request);

    if (QThread::currentThread() == thread()) {
        QEventLoop loop;
        m_promptLoop = &loop;
        loop.exec();
        m_promptLoop = nullptr;
    } else {
        QMutexLocker lock(&m_promptMutex);
        while (m_promptAnswered == false) {
            m_promptCondition.wait(&m_promptMutex);
        }
    }

    QMutexLocker lock(&m_promptMutex);
    text = m_promptText;
    return m_promptAccepted;
}

void VpnController::answerPrompt(bool accepted, const QString& text, bool remember)
{
    {
        QMutexLocker lock(&m_promptMutex);
        m_promptAccepted = accepted;
        m_promptText = text;
        m_promptRemember = remember;
        m_promptAnswered = true;
    }
    m_promptCondition.wakeAll();

    if (m_promptLoop != nullptr) {
        m_promptLoop->quit();
    }
}

// The library's own pretty names say what a protocol is compatible with, which
// is long: "Cisco AnyConnect or OpenConnect". Beside a connect button there is
// room for one word, so each protocol gets one here.
static QString shortProtocolName(const QString& name)
{
    static const QHash<QString, QString> names{
        { QStringLiteral("anyconnect"), QStringLiteral("AnyConnect") },
        { QStringLiteral("nc"), QStringLiteral("Juniper") },
        { QStringLiteral("pulse"), QStringLiteral("Pulse") },
        { QStringLiteral("gp"), QStringLiteral("GlobalProtect") },
        { QStringLiteral("f5"), QStringLiteral("F5") },
        { QStringLiteral("fortinet"), QStringLiteral("Fortinet") },
        { QStringLiteral("array"), QStringLiteral("Array") }
    };

    const QString known = names.value(name);
    return known.isEmpty() ? name.toUpper() : known;
}

QVariantList VpnController::protocols() const
{
    QVariantList list;
    struct oc_vpn_proto* protos = nullptr;

    if (openconnect_get_supported_protocols(&protos) >= 0) {
        for (oc_vpn_proto* p = protos; p->name; ++p) {
            const QString name = QString::fromUtf8(p->name);
            list.append(QVariantMap{
                { QStringLiteral("name"), name },
                { QStringLiteral("label"), QString::fromUtf8(p->pretty_name) },
                { QStringLiteral("short"), shortProtocolName(name) },
                { QStringLiteral("description"), QString::fromUtf8(p->description) } });
        }
        openconnect_free_supported_protocols(protos);
    }

    return list;
}

QVariantList VpnController::tokenModes() const
{
    return QVariantList{
        QVariantMap{ { QStringLiteral("value"), -1 }, { QStringLiteral("label"), tr("Disabled") } },
        QVariantMap{ { QStringLiteral("value"), OC_TOKEN_MODE_STOKEN }, { QStringLiteral("label"), tr("STOKEN (RSA)") } },
        QVariantMap{ { QStringLiteral("value"), OC_TOKEN_MODE_TOTP }, { QStringLiteral("label"), tr("TOTP") } },
        QVariantMap{ { QStringLiteral("value"), OC_TOKEN_MODE_HOTP }, { QStringLiteral("label"), tr("HOTP") } }
    };
}

QVariantList VpnController::logLevels() const
{
    return QVariantList{
        QVariantMap{ { QStringLiteral("value"), PRG_ERR }, { QStringLiteral("label"), tr("Error") } },
        QVariantMap{ { QStringLiteral("value"), PRG_INFO }, { QStringLiteral("label"), tr("Info") } },
        QVariantMap{ { QStringLiteral("value"), PRG_DEBUG }, { QStringLiteral("label"), tr("Debug") } },
        QVariantMap{ { QStringLiteral("value"), PRG_TRACE }, { QStringLiteral("label"), tr("Trace") } }
    };
}

QVariantList VpnController::systemCertificates() const
{
    QVariantList list;

#ifdef USE_SYSTEM_KEYS
    gnutls_system_key_iter_t iter = nullptr;
    char* cert_url;
    char* key_url;
    char* label;
    int ret = -1;

    do {
        ret = gnutls_system_key_iter_get_info(&iter, GNUTLS_CRT_X509, &cert_url, &key_url, &label,
            nullptr, 0);
        if (ret >= 0) {
            list.append(QVariantMap{
                { QStringLiteral("label"), label != nullptr ? QString::fromUtf8(label) : QString::fromUtf8(cert_url) },
                { QStringLiteral("certUrl"), QString::fromUtf8(cert_url) },
                { QStringLiteral("keyUrl"), QString::fromUtf8(key_url) } });
        }
    } while (ret >= 0);

    gnutls_system_key_iter_deinit(iter);
#endif

    return list;
}

QVariantMap VpnController::loadProfile(const QString& name) const
{
    QVariantMap profile;
    StoredServer ss;
    QString label = name;

    if (name.isEmpty() == false) {
        ss.load(label);
    }

    QString serverPin;
    ss.get_server_pin(serverPin);

    QString protocol = ss.get_protocol_name();
    if (protocol.isEmpty() == true && protocols().isEmpty() == false) {
        protocol = protocols().first().toMap().value("name").toString();
    }

    profile["name"] = name.isEmpty() ? QString() : ss.get_label();
    profile["originalName"] = name;
    profile["gateway"] = name.isEmpty() ? QString() : ss.get_server_gateway();
    profile["username"] = ss.get_username();
    profile["groupname"] = ss.get_groupname();
    profile["protocol"] = protocol;
    profile["tokenType"] = ss.get_token_str().isEmpty() ? -1 : ss.get_token_type();
    profile["tokenStr"] = ss.get_token_str();
    profile["interfaceName"] = ss.get_interface_name();
    profile["vpncScript"] = ss.get_vpnc_script_filename();
    profile["logLevel"] = ss.get_log_level();
    profile["batchMode"] = ss.get_batch_mode();
    profile["dnsMode"] = ss.get_dns_mode();
    // The password is handed to the editor so it can be shown as filled in and
    // saved again unchanged. It never leaves this program: Windows keeps it
    // sealed to this account, and the editor only ever shows it masked.
    profile["password"] = ss.get_password();
    profile["emoji"] = ss.get_emoji();
    profile["minimizeOnConnect"] = ss.get_minimize();
    profile["disableUdp"] = ss.get_disable_udp();
    profile["useProxy"] = ss.get_proxy();
    profile["reconnectTimeout"] = ss.get_reconnect_timeout();
    profile["dtlsAttemptPeriod"] = ss.get_dtls_reconnect_timeout();
    profile["caCertPin"] = ss.get_ca_cert_pin();
    profile["clientCertPin"] = ss.get_client_cert_pin();
    profile["serverCertPin"] = serverPin;
    profile["keyUrl"] = ss.get_key_url();

#ifdef _WIN32
    profile["interfaceNameMaxLength"] = OC_IFNAME_MAX_LENGTH;
#else
    profile["interfaceNameMaxLength"] = 0;
#endif

    return profile;
}

QString VpnController::saveProfile(const QVariantMap& profile)
{
    const QString name = profile.value("name").toString().trimmed();
    const QString gateway = profile.value("gateway").toString().trimmed();

    if (gateway.isEmpty() == true) {
        return tr("You need to specify a gateway. E.g. vpn.example.com:443");
    }
    if (name.isEmpty() == true) {
        return tr("You need to specify a name for this connection. E.g. 'My company'");
    }

    const QString originalName = profile.value("originalName").toString();
    QString label = originalName.isEmpty() ? name : originalName;

    StoredServer ss;
    ss.load(label);
    ss.set_password_asker([this](const QString& description, QString& password) {
        QVariantMap request;
        request["title"] = tr("Enter password");
        request["label"] = description;
        return askPrompt(PromptPassword, request, password);
    });

    if (profile.value("clearCaCert").toBool() == true) {
        ss.clear_ca();
    }
    if (profile.value("clearClientCert").toBool() == true) {
        ss.clear_cert();
    }
    if (profile.value("clearClientKey").toBool() == true) {
        ss.clear_key();
    }
    if (profile.value("clearServerPin").toBool() == true) {
        ss.clear_server_pin();
    }

    const QString caCertFile = profile.value("caCertFile").toString();
    if (caCertFile.isEmpty() == false && ss.set_ca_cert(caCertFile) != 0) {
        return ss.m_last_err.isEmpty() ? tr("Cannot import CA certificate.") : ss.m_last_err;
    }

    const QString clientKeyFile = profile.value("clientKeyFile").toString();
    if (clientKeyFile.isEmpty() == false && ss.set_client_key(clientKeyFile) != 0) {
        return ss.m_last_err.isEmpty() ? tr("Cannot import user key.") : ss.m_last_err;
    }

    const QString clientCertFile = profile.value("clientCertFile").toString();
    if (clientCertFile.isEmpty() == false && ss.set_client_cert(clientCertFile) != 0) {
        return ss.m_last_err.isEmpty() ? tr("Cannot import user certificate.") : ss.m_last_err;
    }

    if (ss.client_is_complete() != true) {
        return tr("There is a client certificate specified but no key!");
    }

    ss.set_label(name);
    ss.set_server_gateway(gateway);
    ss.set_username(profile.value("username").toString());
    ss.set_groupname(profile.value("groupname").toString());
    ss.set_protocol_name(profile.value("protocol").toString());
    ss.set_interface_name(profile.value("interfaceName").toString());
    ss.set_vpnc_script_filename(profile.value("vpncScript").toString());
    ss.set_log_level(profile.value("logLevel", -1).toInt());
    ss.set_dns_mode(profile.value("dnsMode", 0).toInt());

    const bool remember = profile.value("batchMode").toBool();
    ss.set_batch_mode(remember);
    if (remember == true) {
        ss.set_password(profile.value("password").toString());
    } else {
        ss.clear_password();
    }
    ss.set_emoji(profile.value("emoji").toString().isEmpty()
            ? defaultProfileEmoji()
            : profile.value("emoji").toString());
    ss.set_minimize(profile.value("minimizeOnConnect").toBool());
    ss.set_disable_udp(profile.value("disableUdp").toBool());
    ss.set_proxy(profile.value("useProxy").toBool());
    ss.set_reconnect_timeout(profile.value("reconnectTimeout", 300).toInt());
    ss.set_dtls_reconnect_timeout(profile.value("dtlsAttemptPeriod", 25).toInt());

    const int tokenType = profile.value("tokenType", -1).toInt();
    const QString tokenStr = profile.value("tokenStr").toString();
    if (tokenType != -1 && tokenStr.isEmpty() == false) {
        ss.set_token_str(tokenStr);
        ss.set_token_type(tokenType);
    } else {
        ss.set_token_str("");
        ss.set_token_type(-1);
    }

    ss.save();

    if (originalName.isEmpty() == false && originalName != name) {
        removeProfile(originalName);
    }

    reloadProfiles();
    setCurrentProfile(name);
    return QString();
}

// Copied key by key rather than through StoredServer: that way the certificates,
// the pinned server key and the sealed password come across exactly as they are,
// instead of being decoded and written out again on the way.
QString VpnController::duplicateProfile(const QString& name)
{
    if (m_profiles.contains(name) == false) {
        return QString();
    }

    QString copy = tr("%1 (copy)").arg(name);
    for (int n = 2; m_profiles.contains(copy) == true; n++) {
        copy = tr("%1 (copy %2)").arg(name).arg(n);
    }

    OcSettings settings;
    const QString from = QLatin1String(PREFIX) + name + QLatin1Char('/');
    const QString to = QLatin1String(PREFIX) + copy + QLatin1Char('/');

    const QStringList keys = settings.allKeys();
    for (const QString& key : keys) {
        if (key.startsWith(from) == true) {
            settings.setValue(to + key.mid(from.size()), settings.value(key));
        }
    }

    // A copy has never connected, and saying otherwise would be a small lie in
    // the list.
    settings.remove(to + QLatin1String("last-connected"));
    settings.sync();

    reloadProfiles();
    setCurrentProfile(copy);
    return copy;
}

QString VpnController::exportProfile(const QString& name)
{
    if (m_profiles.contains(name) == false) {
        return tr("There is no profile called '%1'.").arg(name);
    }

    const QString suggested = QDir::toNativeSeparators(
        QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation)
        + QLatin1Char('/') + name + QStringLiteral(".json"));
    const QString path = QFileDialog::getSaveFileName(nullptr,
        tr("Save the profile '%1'").arg(name), suggested, tr("Ocelot profile (*.json)"));
    if (path.isEmpty() == true) {
        return QString();
    }

    QVariantMap profile = loadProfile(name);
    // The file travels; these stay behind. A remembered password is sealed to
    // this account on this computer and could not be read anywhere else anyway,
    // and the seed of a one-time code is the second factor itself.
    profile.remove(QStringLiteral("password"));
    profile.remove(QStringLiteral("tokenStr"));
    profile.remove(QStringLiteral("originalName"));
    profile.remove(QStringLiteral("interfaceNameMaxLength"));
    // Whether to trust a server's certificate is something each computer
    // decides for itself, the first time it connects.
    profile.remove(QStringLiteral("serverCertPin"));
    profile.remove(QStringLiteral("caCertPin"));
    profile.remove(QStringLiteral("clientCertPin"));
    profile[QStringLiteral("batchMode")] = false;
    profile[QStringLiteral("tokenType")] = -1;

    QFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate) == false) {
        return tr("The file %1 could not be written.").arg(QDir::toNativeSeparators(path));
    }
    file.write(QJsonDocument::fromVariant(profile).toJson(QJsonDocument::Indented));
    file.close();

    Logger::instance().addMessage(
        tr("The profile '%1' was written to %2").arg(name, QDir::toNativeSeparators(path)));
    return QString();
}

QString VpnController::importProfile()
{
    const QString path = QFileDialog::getOpenFileName(nullptr, tr("Open a profile"),
        QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation),
        tr("Ocelot profile (*.json)"));
    if (path.isEmpty() == true) {
        return QString();
    }

    QFile file(path);
    if (file.open(QIODevice::ReadOnly) == false) {
        return tr("The file %1 could not be read.").arg(QDir::toNativeSeparators(path));
    }

    QJsonParseError problem;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &problem);
    file.close();

    if (document.isObject() == false) {
        return tr("%1 does not hold a profile: %2")
            .arg(QDir::toNativeSeparators(path), problem.errorString());
    }

    QVariantMap profile = document.object().toVariantMap();
    if (profile.value(QStringLiteral("gateway")).toString().trimmed().isEmpty() == true) {
        return tr("%1 does not hold a profile: there is no gateway in it.")
            .arg(QDir::toNativeSeparators(path));
    }

    QString name = profile.value(QStringLiteral("name")).toString().trimmed();
    if (name.isEmpty() == true) {
        name = profile.value(QStringLiteral("gateway")).toString().trimmed();
    }

    // A profile brought from elsewhere must not quietly take the place of one
    // that is already here under the same name.
    QString unique = name;
    for (int n = 2; m_profiles.contains(unique) == true; n++) {
        unique = tr("%1 (%2)").arg(name).arg(n);
    }

    profile[QStringLiteral("name")] = unique;
    profile[QStringLiteral("originalName")] = QString();
    profile.remove(QStringLiteral("password"));
    profile.remove(QStringLiteral("tokenStr"));

    const QString failure = saveProfile(profile);
    if (failure.isEmpty() == false) {
        return failure;
    }

    setCurrentProfile(unique);
    Logger::instance().addMessage(
        tr("The profile '%1' was read from %2").arg(unique, QDir::toNativeSeparators(path)));
    return QString();
}

int VpnController::forgetAllPasswords()
{
    OcSettings settings;
    int forgotten = 0;

    for (const QString& name : m_profiles) {
        const QString group = QLatin1String(PREFIX) + name + QLatin1Char('/');
        if (settings.value(group + QStringLiteral("password")).toByteArray().isEmpty() == false) {
            forgotten++;
        }
        settings.remove(group + QStringLiteral("password"));
        // Left on, the profile would save the next password it is given.
        settings.setValue(group + QStringLiteral("batch"), false);
    }
    settings.sync();

    Logger::instance().addMessage(tr("Passwords deleted: %1").arg(forgotten));
    emit profilesChanged();
    return forgotten;
}

QString VpnController::saveLog(const QString& text)
{
    const QString suggested = QDir::toNativeSeparators(
        QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation)
        + QStringLiteral("/ocelot-log-")
        + QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd-HHmm"))
        + QStringLiteral(".txt"));
    const QString path = QFileDialog::getSaveFileName(nullptr, tr("Save the log"), suggested,
        tr("Text file (*.txt)"));
    if (path.isEmpty() == true) {
        return QString();
    }

    QFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text) == false) {
        return tr("The file %1 could not be written.").arg(QDir::toNativeSeparators(path));
    }
    {
        QTextStream stream(&file);
        stream.setEncoding(QStringConverter::Utf8);
        stream << text;
    }
    file.close();

    Logger::instance().addMessage(
        tr("The log was written to %1").arg(QDir::toNativeSeparators(path)));
    return QString();
}

void VpnController::removeProfile(const QString& name)
{
    OcSettings settings;
    const QString prefix = QLatin1String(PREFIX) + name + QLatin1String("/");

    for (const auto& key : settings.allKeys()) {
        if (key.startsWith(prefix)) {
            settings.remove(key);
        }
    }

    if (m_currentProfile == name) {
        m_currentProfile.clear();
    }
    reloadProfiles();
}

void VpnController::reloadProfiles()
{
    QStringList profiles;
    OcSettings settings;

    for (const auto& key : settings.allKeys()) {
        if (key.startsWith(PREFIX) && key.endsWith("/server")) {
            QString str{ key };
            str.remove(0, sizeof(PREFIX) - 1); /* remove prefix */
            str.remove(str.size() - 7, 7); /* remove /server suffix */
            profiles.append(str);
        }
    }

    // The one used last is the one most likely wanted next, so it comes first.
    // Profiles that have never connected keep to the end, in their own order by
    // name.
    std::sort(profiles.begin(), profiles.end(),
        [&settings](const QString& left, const QString& right) {
            const qint64 lastLeft = settings.value(QLatin1String(PREFIX) + left
                + QStringLiteral("/last-connected"), 0).toLongLong();
            const qint64 lastRight = settings.value(QLatin1String(PREFIX) + right
                + QStringLiteral("/last-connected"), 0).toLongLong();
            if (lastLeft != lastRight) {
                return lastLeft > lastRight;
            }
            return QString::localeAwareCompare(left, right) < 0;
        });

    if (profiles != m_profiles) {
        m_profiles = profiles;
        emit profilesChanged();
    }

    if (m_profiles.contains(m_currentProfile) == false) {
        setCurrentProfile(m_profiles.isEmpty() ? QString() : m_profiles.first());
    } else {
        // the profile restored from the settings keeps its name, but the
        // gateway and the protocol still have to be read
        loadCurrentProfileInfo();
        emit currentProfileChanged();
    }
}

void VpnController::createTrayIcon()
{
    m_trayIcon = new QSystemTrayIcon(this);
    m_trayIcon->installEventFilter(this);

    // No menu of the system's own. Everything it used to offer - connecting to
    // a profile, disconnecting, the window, quitting - is in the popover, drawn
    // like the rest of the program; a menu in the system's style beside it
    // would be the one thing here that belongs to a different design.
    connect(m_trayIcon, &QSystemTrayIcon::activated,
        this, [this](QSystemTrayIcon::ActivationReason reason) {
            // One click, either button, is the popover. Two clicks are for the
            // window itself.
            if (reason == QSystemTrayIcon::Trigger
                || reason == QSystemTrayIcon::Context
                || reason == QSystemTrayIcon::MiddleClick) {
                emit popoverToggleRequested();
            } else if (reason == QSystemTrayIcon::DoubleClick) {
                emit windowRequested(true);
            }
        });

    updateTrayIcon();
    m_trayIcon->show();
}

bool VpnController::eventFilter(QObject* watched, QEvent* event)
{
    // The notification area icon has no hover signal; the only sign that the
    // pointer is resting on it is the tooltip the system asks for.
    if (watched == m_trayIcon && event->type() == QEvent::ToolTip) {
        emit popoverPeekRequested();
    }
    return QObject::eventFilter(watched, event);
}

void VpnController::updateTrayIcon()
{
    if (m_trayIcon == nullptr) {
        return;
    }

    QFileSelector selector;
    const QString file = (m_status == StatusConnected)
        ? QStringLiteral(":/images/network-connected.png")
        : QStringLiteral(":/images/network-disconnected.png");

    QIcon icon(selector.select(file));
    icon.setIsMask(true);
    m_trayIcon->setIcon(icon);

    switch (m_status) {
    case StatusConnected:
        m_trayIcon->setToolTip(tr("Connected to %1").arg(m_currentProfile));
        break;
    case StatusConnecting:
        m_trayIcon->setToolTip(tr("Connecting to %1").arg(m_currentProfile));
        break;
    case StatusDisconnecting:
        m_trayIcon->setToolTip(tr("Disconnecting from %1").arg(m_currentProfile));
        break;
    default:
        m_trayIcon->setToolTip(tr("Disconnected"));
        break;
    }
}


void VpnController::tryCheckLatestVersion()
{
    if (m_checkUpdates == false) {
        return;
    }

    const qint64 now = QDateTime::currentSecsSinceEpoch();

    // Check during start up only a time every a few days to avoid
    // overloading GitHub.
    if (now - m_lastCheckTime < 5 * 86400) {
        Logger::instance().addMessage(QObject::tr("Skipping automatic check for current version"));
        return;
    }

    startVersionRequest();
}

void VpnController::startVersionRequest()
{
    QNetworkRequest request{ QUrl(QLatin1String(APP_LATEST_RELEASE_URL)) };
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);

    Logger::instance().addMessage(QObject::tr("Checking for current version"));
    m_lastCheckTime = QDateTime::currentSecsSinceEpoch();
    m_checkingForUpdates = true;
    emit checkingForUpdatesChanged();
    m_network->get(request);
}

bool VpnController::downloadingUpdate() const
{
    return m_updater->busy();
}

double VpnController::updateProgress() const
{
    return m_updater->progress();
}

bool VpnController::updateDownloaded() const
{
    return m_updater->file().isEmpty() == false;
}

bool VpnController::canInstallUpdate() const
{
#ifdef Q_OS_WIN
    return true;
#else
    // The app image is one file that whoever runs it keeps where they like;
    // replacing it is not this program's business.
    return false;
#endif
}

void VpnController::downloadUpdate()
{
    if (updateAvailable() == false) {
        emit errorOccurred(tr("Update Ocelot"), tr("There is nothing newer to install."));
        return;
    }

    m_updater->start(m_latestVersion);
    emit updateProgressChanged();
}

void VpnController::applyUpdate()
{
    QString error;
    if (m_updater->apply(error) == false) {
        emit errorOccurred(tr("Update Ocelot"), error);
        return;
    }

    quit();
}

QString VpnController::downloadUrl() const
{
    // The installer's file name carries the openconnect version as well as
    // ours, so it cannot be worked out from the version alone; the releases
    // page is one click away from the file and always right.
    return QLatin1String(APP_RELEASES_URL);
}

void VpnController::checkForUpdates()
{
    if (m_latestVersion.isEmpty() == true) {
        startVersionRequest();
        return;
    }

    emit latestVersionChanged();
}

void VpnController::gotLatestVersion(QNetworkReply* reply)
{
    const QString location = QString::fromUtf8(reply->rawHeader("Location"));
    Logger::instance().addMessage(QObject::tr("Version location: %1").arg(location));

    if (location.isEmpty() == false) {
        // Asking for the latest release is answered with a redirect to the tag
        // it points at:
        //     https://github.com/<owner>/<repo>/releases/tag/v1.2.3
        // A repository with no releases yet redirects to the releases page
        // instead, which names no version at all. Reading the tail of that
        // address as one is how this came to announce "eleases" as a newer
        // release than the program itself.
        static const QRegularExpression tag(QStringLiteral("/releases/tag/v?([^/]+)/?$"));
        const QRegularExpressionMatch found = tag.match(location);

        if (found.hasMatch() == true) {
            m_latestVersion = found.captured(1);
            Logger::instance().addMessage(QObject::tr("Latest available version is %1, current %2")
                                              .arg(m_latestVersion)
                                              .arg(INTERNAL_PROJECT_VERSION));

            if (m_trayIcon != nullptr && m_trayIcon->supportsMessages()
                && updateAvailable() == true) {
                m_trayIcon->showMessage(tr("New version available"),
                    tr("%1 version %2 is available!").arg(QLatin1String(PRODUCT_NAME_SHORT)).arg(m_latestVersion));
            }
        } else {
            Logger::instance().addMessage(
                QObject::tr("No release has been published yet, so there is nothing newer"));
        }
    } else {
        Logger::instance().addMessage(QObject::tr("Unable to identify current version: %1").arg(reply->errorString()));
    }

    m_checkingForUpdates = false;
    emit checkingForUpdatesChanged();
    emit latestVersionChanged();
    reply->deleteLater();
}

QString VpnController::aboutText() const
{
    QString txt;

    if (QLatin1String(PROJECT_VERSION).contains(QLatin1String("-g"))) {
        txt += tr("Development snapshot <i>%1</i> (%2 bit)<br>")
                   .arg(PROJECT_VERSION)
                   .arg(QSysInfo::buildCpuArchitecture() == QLatin1String("i386") ? 32 : 64);
        txt += tr("Built at <i>%1</i><br>").arg(QLatin1String(appBuildOn));
    } else {
        txt += tr("Version <i>%1</i> (%2 bit)<br>")
                   .arg(PROJECT_VERSION)
                   .arg(QSysInfo::buildCpuArchitecture() == QLatin1String("i386") ? 32 : 64);
    }

    txt += tr("<br><i>%1</i> is free software built on the OpenConnect project. "
              "See the license for more information.<br>")
               .arg(APP_NAME);

    txt += tr("<br>For macOS there is a client of its own: "
              "<a href=\"%1\">%1</a>.<br>")
               .arg(QLatin1String(APP_MACOS_URL));

    // CC BY asks for the author and the licence to be named wherever the work
    // is passed on, and the artwork travels inside the installer, the app
    // image and the disk image. A note in docs/ would not reach anyone who
    // receives the program.
    txt += tr("<br>The two icons in the notification area are by Google, from the "
              "Material Design Icons, used under "
              "<a href=\"https://creativecommons.org/licenses/by/4.0/\">CC BY 4.0</a>. "
              "Everything else here is drawn by this program.<br>");

    return txt;
}

QString VpnController::licenseText() const
{
    QString txt = tr("Based on");
    txt += tr("<br>- <a href=\"https://www.infradead.org/openconnect\">OpenConnect</a> ") + QLatin1String(openconnect_get_version());
    txt += tr("<br>- <a href=\"https://www.gnutls.org\">GnuTLS</a> v") + QLatin1String(gnutls_check_version(nullptr));
    txt += tr("<br>- <a href=\"https://github.com/gabime/spdlog\">spdlog</a> v%1.%2.%3")
               .arg(QString::number(SPDLOG_VER_MAJOR))
               .arg(QString::number(SPDLOG_VER_MINOR))
               .arg(QString::number(SPDLOG_VER_PATCH));
    txt += tr("<br>- <a href=\"https://www.qt.io\">Qt</a> v%1").arg(QT_VERSION_STR);

    txt += tr("<br><br>%1<br>").arg(PRODUCT_NAME_COPYRIGHT_FULL);
    txt += tr("<br><i>%1</i> comes with ABSOLUTELY NO WARRANTY. This is free software, "
              "and you are welcome to redistribute it under the conditions "
              "of the GNU General Public License version 2.<br>")
               .arg(APP_NAME);

    return txt;
}

void VpnController::copyToClipboard(const QString& text) const
{
    QApplication::clipboard()->setText(text);
}

void VpnController::showWindow()
{
    emit windowRequested(true);
}

// The size is remembered under a key of its own for this layout. A window that
// suited the single narrow column the program used to have is the wrong shape
// for a sidebar beside a pane, and restoring it would open every existing
// installation at a size that fits neither.
QRect VpnController::windowGeometry() const
{
    OcSettings settings;
    return settings.value("MainWindow/rect2").toRect();
}

void VpnController::saveWindowGeometry(const QRect& geometry)
{
    OcSettings settings;
    settings.setValue("MainWindow/rect2", geometry);
}

bool VpnController::requestWindowClose()
{
    if (m_trayIcon != nullptr && m_trayIcon->isVisible() && m_minimizeInsteadOfClose == true) {
        emit windowHideRequested();
        return false;
    }

    quit();
    return true;
}

void VpnController::quit()
{
    if (m_status == StatusConnected || m_status == StatusConnecting) {
        m_quitWhenDisconnected = true;
        disconnectVpn();
        return;
    }

    qApp->quit();
}

void VpnController::readSettings()
{
    OcSettings settings;

    settings.beginGroup("Settings");
    m_lastCheckTime = settings.value("last-check-time").toLongLong();
    m_minimizeToTray = settings.value("minimizeToTheNotificationArea", true).toBool();
    m_minimizeInsteadOfClose = settings.value("minimizeTheApplicationInsteadOfClosing", true).toBool();
    m_startMinimized = settings.value("startMinimized", false).toBool();
    m_singleInstance = settings.value("singleInstanceMode", true).toBool();
    m_logLevel = settings.value("logLevel", PRG_INFO).toInt();
    m_theme = settings.value("theme", ThemeOcelot).toInt();
    m_language = settings.value("language", LanguageSystem).toInt();
    m_windowStyle = settings.value("windowStyle", WindowStyleOcelot).toInt();
    m_connectOnStart = settings.value("connectOnStart", false).toBool();
    m_connectOnLogon = settings.value("connectOnLogon", false).toBool();
    m_reconnectOnDrop = settings.value("reconnectOnDrop", true).toBool();
    m_notifyOnChange = settings.value("notifyOnChange", true).toBool();
    m_checkUpdates = settings.value("checkUpdates", true).toBool();
    m_autoConnectProfile = settings.value("autoConnectProfile").toString();
    settings.endGroup();

    if (m_theme < ThemeOcelot || m_theme > ThemeNight) {
        m_theme = ThemeOcelot;
    }

    if (m_language < LanguageSystem || m_language > LanguageRussian) {
        m_language = LanguageSystem;
    }

    if (m_windowStyle < WindowStyleOcelot || m_windowStyle > WindowStyleSystem) {
        m_windowStyle = WindowStyleOcelot;
    }
    applyLanguage();

    if (m_logLevel < PRG_ERR || m_logLevel > PRG_TRACE) {
        m_logLevel = PRG_INFO;
    }

    m_currentProfile = settings.value("Profiles/current").toString();
}

void VpnController::writeSettings()
{
    OcSettings settings;

    settings.beginGroup("Settings");
    if (m_lastCheckTime > 0) {
        settings.setValue("last-check-time", m_lastCheckTime);
    }
    settings.setValue("minimizeToTheNotificationArea", m_minimizeToTray);
    settings.setValue("minimizeTheApplicationInsteadOfClosing", m_minimizeInsteadOfClose);
    settings.setValue("startMinimized", m_startMinimized);
    settings.setValue("singleInstanceMode", m_singleInstance);
    settings.setValue("logLevel", m_logLevel);
    settings.setValue("theme", m_theme);
    settings.setValue("language", m_language);
    settings.setValue("windowStyle", m_windowStyle);
    settings.setValue("connectOnStart", m_connectOnStart);
    settings.setValue("connectOnLogon", m_connectOnLogon);
    settings.setValue("reconnectOnDrop", m_reconnectOnDrop);
    settings.setValue("notifyOnChange", m_notifyOnChange);
    settings.setValue("checkUpdates", m_checkUpdates);
    settings.setValue("autoConnectProfile", m_autoConnectProfile);
    settings.endGroup();

    settings.setValue("Profiles/current", m_currentProfile);
}
