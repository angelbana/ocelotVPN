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

#pragma once

#include "common.h"

#include <QFutureWatcher>
#include <QMutex>
#include <QObject>
#include <QRect>
#include <QStringList>
#include <QVariantMap>
#include <QWaitCondition>

class QAction;
class QEventLoop;
class QMenu;
class QNetworkAccessManager;
class QNetworkReply;
class QQmlEngine;
class QSystemTrayIcon;
class QTimer;
class QTranslator;

class VpnController : public QObject {
    Q_OBJECT

    Q_PROPERTY(int status READ status NOTIFY statusChanged)
    Q_PROPERTY(QStringList profiles READ profiles NOTIFY profilesChanged)
    Q_PROPERTY(QString currentProfile READ currentProfile WRITE setCurrentProfile NOTIFY currentProfileChanged)
    Q_PROPERTY(QString gateway READ gateway NOTIFY currentProfileChanged)
    Q_PROPERTY(QString protocolName READ protocolName NOTIFY currentProfileChanged)
    // The character shown for the selected profile, and one entry per profile
    // for the list beside it. The list is a property of its own because the
    // sidebar needs a name, an emoji and a server for every profile at once.
    Q_PROPERTY(QString profileEmoji READ profileEmoji NOTIFY currentProfileChanged)
    Q_PROPERTY(QVariantList profileEntries READ profileEntries NOTIFY profilesChanged)

    Q_PROPERTY(QString ip READ ip NOTIFY tunnelChanged)
    Q_PROPERTY(QString ip6 READ ip6 NOTIFY tunnelChanged)
    Q_PROPERTY(QString dns READ dns NOTIFY tunnelChanged)
    // The domains the tunnel resolves, when the server named any.
    Q_PROPERTY(QString searchDomains READ searchDomains NOTIFY tunnelChanged)
    Q_PROPERTY(QString cstpCipher READ cstpCipher NOTIFY tunnelChanged)
    Q_PROPERTY(QString dtlsCipher READ dtlsCipher NOTIFY tunnelChanged)
    Q_PROPERTY(QString received READ received NOTIFY statsChanged)
    Q_PROPERTY(QString sent READ sent NOTIFY statsChanged)
    // Bytes per second over the last sampling interval; the chart is drawn from
    // these, so they are numbers rather than text.
    Q_PROPERTY(double rxRate READ rxRate NOTIFY statsChanged)
    Q_PROPERTY(double txRate READ txRate NOTIFY statsChanged)
    Q_PROPERTY(QString uptime READ uptime NOTIFY statsChanged)

    Q_PROPERTY(QString appVersion READ appVersion CONSTANT)
    // the version the release check compares against; appVersion also carries
    // the git description of a development build
    Q_PROPERTY(QString releaseVersion READ releaseVersion CONSTANT)
    // the addresses the About screen links to, so they are configured in one
    // place in the build rather than written out again in the interface
    Q_PROPERTY(QString repoUrl READ repoUrl CONSTANT)
    Q_PROPERTY(QString issuesUrl READ issuesUrl CONSTANT)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY latestVersionChanged)
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY latestVersionChanged)
    Q_PROPERTY(bool checkingForUpdates READ checkingForUpdates NOTIFY checkingForUpdatesChanged)
    Q_PROPERTY(bool hasTray READ hasTray CONSTANT)

    Q_PROPERTY(int theme READ theme WRITE setTheme NOTIFY settingsChanged)
    // The language of the interface. Changing it takes effect at once: the
    // translation is inside the program, and Qt re-reads every visible string.
    Q_PROPERTY(int language READ language WRITE setLanguage NOTIFY settingsChanged)
    Q_PROPERTY(int logLevel READ logLevel WRITE setLogLevel NOTIFY settingsChanged)
    Q_PROPERTY(bool minimizeToTray READ minimizeToTray WRITE setMinimizeToTray NOTIFY settingsChanged)
    Q_PROPERTY(bool minimizeInsteadOfClose READ minimizeInsteadOfClose WRITE setMinimizeInsteadOfClose NOTIFY settingsChanged)
    Q_PROPERTY(bool startMinimized READ startMinimized WRITE setStartMinimized NOTIFY settingsChanged)
    Q_PROPERTY(bool singleInstance READ singleInstance WRITE setSingleInstance NOTIFY settingsChanged)

    // Starting with Windows, and the three ways of connecting without being
    // asked. They are separate settings because they answer separate
    // questions: whether the program starts by itself, whether it dials when
    // it starts, and whether it dials again after the line drops.
    Q_PROPERTY(bool autostart READ autostart WRITE setAutostart NOTIFY settingsChanged)
    Q_PROPERTY(bool autostartSupported READ autostartSupported CONSTANT)
    Q_PROPERTY(bool connectOnStart READ connectOnStart WRITE setConnectOnStart NOTIFY settingsChanged)
    Q_PROPERTY(bool connectOnLogon READ connectOnLogon WRITE setConnectOnLogon NOTIFY settingsChanged)
    Q_PROPERTY(bool reconnectOnDrop READ reconnectOnDrop WRITE setReconnectOnDrop NOTIFY settingsChanged)
    // Which profile the two connect-by-itself settings use.
    Q_PROPERTY(QString autoConnectProfile READ autoConnectProfile WRITE setAutoConnectProfile NOTIFY settingsChanged)
    Q_PROPERTY(bool reconnectPending READ reconnectPending NOTIFY reconnectPendingChanged)
    // A short message when the tunnel comes up or goes down.
    Q_PROPERTY(bool notifyOnChange READ notifyOnChange WRITE setNotifyOnChange NOTIFY settingsChanged)
    // Asking GitHub, at most every few days, whether a newer release exists.
    Q_PROPERTY(bool checkUpdates READ checkUpdates WRITE setCheckUpdates NOTIFY settingsChanged)

public:
    enum Status {
        StatusDisconnecting,
        StatusDisconnected,
        StatusConnecting,
        StatusConnected
    };
    Q_ENUM(Status)

    // Three looks that differ in colour only. Ocelot is the one the program
    // is named after and the one it starts with.
    enum ThemeMode {
        ThemeOcelot,
        ThemeDay,
        ThemeNight
    };
    Q_ENUM(ThemeMode)

    // Which language the interface speaks. System follows Windows, which is
    // what someone who never opens the settings expects.
    enum Language {
        LanguageSystem,
        LanguageEnglish,
        LanguageRussian
    };
    Q_ENUM(Language)

    enum PromptType {
        PromptInput,
        PromptPassword,
        PromptChoice,
        PromptConfirm
    };
    Q_ENUM(PromptType)

    explicit VpnController(bool useTray, QObject* parent = nullptr);
    ~VpnController();

    int status() const;
    QStringList profiles() const;
    QString currentProfile() const;
    void setCurrentProfile(const QString& name);
    QString gateway() const;
    QString protocolName() const;
    QString profileEmoji() const;
    QVariantList profileEntries() const;

    QString ip() const;
    QString ip6() const;
    QString dns() const;
    QString searchDomains() const;
    QString cstpCipher() const;
    QString dtlsCipher() const;
    QString received() const;
    QString sent() const;
    double rxRate() const;
    double txRate() const;
    QString uptime() const;

    QString appVersion() const;
    QString releaseVersion() const;
    QString repoUrl() const;
    QString issuesUrl() const;
    QString latestVersion() const;
    bool updateAvailable() const;
    bool checkingForUpdates() const;
    bool hasTray() const;

    int theme() const;
    void setTheme(int mode);
    int language() const;
    void setLanguage(int language);
    int logLevel() const;
    void setLogLevel(int level);
    bool minimizeToTray() const;
    void setMinimizeToTray(bool value);
    bool minimizeInsteadOfClose() const;
    void setMinimizeInsteadOfClose(bool value);
    bool startMinimized() const;
    void setStartMinimized(bool value);
    bool singleInstance() const;
    void setSingleInstance(bool value);
    bool autostart() const;
    void setAutostart(bool value);
    bool autostartSupported() const;
    bool connectOnStart() const;
    void setConnectOnStart(bool value);
    bool connectOnLogon() const;
    void setConnectOnLogon(bool value);
    bool reconnectOnDrop() const;
    void setReconnectOnDrop(bool value);
    QString autoConnectProfile() const;
    void setAutoConnectProfile(const QString& name);
    bool reconnectPending() const;
    bool notifyOnChange() const;
    void setNotifyOnChange(bool value);
    bool checkUpdates() const;
    void setCheckUpdates(bool value);

    Q_INVOKABLE void connectVpn();
    Q_INVOKABLE void disconnectVpn();
    Q_INVOKABLE void connectToProfile(const QString& name);

    Q_INVOKABLE QVariantList protocols() const;
    Q_INVOKABLE QVariantList tokenModes() const;
    Q_INVOKABLE QVariantList logLevels() const;
    Q_INVOKABLE QVariantList systemCertificates() const;
    // The characters a profile may be given, in the order they are offered.
    Q_INVOKABLE QStringList emojiChoices() const;
    // The languages on offer, as {value, label} pairs for the settings screen.
    Q_INVOKABLE QVariantList languages() const;
    Q_INVOKABLE QVariantMap loadProfile(const QString& name) const;
    Q_INVOKABLE QString saveProfile(const QVariantMap& profile);
    Q_INVOKABLE void removeProfile(const QString& name);
    // A copy of a profile under a new name, for a second account on the same
    // server or a variant of the same connection.
    Q_INVOKABLE QString duplicateProfile(const QString& name);

    Q_INVOKABLE void answerPrompt(bool accepted, const QString& text = QString());

    Q_INVOKABLE void checkForUpdates();
    Q_INVOKABLE QString downloadUrl() const;
    Q_INVOKABLE QString aboutText() const;
    Q_INVOKABLE QString licenseText() const;
    Q_INVOKABLE void copyToClipboard(const QString& text) const;

    // Removes the split DNS rules the vpnc script leaves behind when the
    // program does not get to disconnect - a crash, a kill, a reboot while
    // connected - and clears the resolver cache after them.
    Q_INVOKABLE void repairDns();

    Q_INVOKABLE void showWindow();
    // Where the notification area icon sits, so the popover can be put beside
    // it. An empty rectangle means the system would not say.
    Q_INVOKABLE QRect trayIconGeometry() const;
    // Connecting by itself, once the interface is up and able to ask questions.
    void applyStartupActions(bool launchedByLogonTask);
    // Handed the engine so a change of language can re-read the interface
    // instead of waiting for a restart.
    void setQmlEngine(QQmlEngine* engine);
    Q_INVOKABLE QRect windowGeometry() const;
    Q_INVOKABLE void saveWindowGeometry(const QRect& geometry);
    Q_INVOKABLE bool requestWindowClose();
    Q_INVOKABLE void quit();

    // Called from the VPN worker thread.
    void updateStats(const struct oc_stats* stats, const QString& dtlsCipher);
    void setStatus(int status);
    void setTunnelInfo(const QString& dns, const QString& ip, const QString& ip6,
        const QString& cstpCipher, const QString& dtlsCipher, const QString& searchDomains);
    bool askPrompt(PromptType type, const QVariantMap& request, QString& text);
    int appLogLevel() const;

signals:
    void statusChanged();
    void profilesChanged();
    void currentProfileChanged();
    void reconnectPendingChanged();
    void tunnelChanged();
    void statsChanged();
    void latestVersionChanged();
    void checkingForUpdatesChanged();
    void settingsChanged();

    void promptRequested(int type, const QVariantMap& request);
    void errorOccurred(const QString& title, const QString& message);
    void windowRequested(bool activate);
    // A click on the notification area icon; the popover decides what to do
    // with it, since only it knows whether it is already showing.
    void popoverToggleRequested();
    void windowMinimizeRequested();
    void windowHideRequested();
    void readyToShutdown();

private slots:
    void requestStats();
    void gotLatestVersion(QNetworkReply* reply);

private:
    void createTrayIcon();
    void updateTrayIcon();
    void updateTrayMenu();
    void reloadProfiles();
    void loadCurrentProfileInfo();
    void readSettings();
    void writeSettings();
    void terminateConnection();
    void tryCheckLatestVersion();
    void startVersionRequest();
    void cleanupNrptRules(bool flushCache);
    void applyLanguage();
    // Dialling again after a connection was lost rather than ended.
    void scheduleReconnect();
    void cancelReconnect();

    int m_status;
    SOCKET m_cmd_fd;
    bool m_minimizeOnConnect;
    bool m_quitWhenDisconnected;
    QFutureWatcher<void> m_futureWatcher;
    QTimer* m_statsTimer;

    QStringList m_profiles;
    QString m_currentProfile;
    QString m_gateway;
    QString m_protocolName;
    QString m_profileEmoji;

    QString m_ip;
    QString m_ip6;
    QString m_dns;
    QString m_searchDomains;
    QString m_cstpCipher;
    QString m_dtlsCipher;
    QString m_received;
    QString m_sent;
    double m_rxRate;
    double m_txRate;
    quint64 m_lastRxBytes;
    quint64 m_lastTxBytes;
    qint64 m_lastSampleTime;
    qint64 m_connectedSince;

    QString m_latestVersion;
    bool m_checkingForUpdates;
    qint64 m_lastCheckTime;
    QNetworkAccessManager* m_network;

    QSystemTrayIcon* m_trayIcon;
    QMenu* m_trayMenu;
    QMenu* m_trayProfilesMenu;
    QAction* m_trayDisconnectAction;

    int m_theme;
    int m_language;
    QTranslator* m_translator;
    QQmlEngine* m_qmlEngine;
    int m_logLevel;
    bool m_minimizeToTray;
    bool m_minimizeInsteadOfClose;
    bool m_startMinimized;
    bool m_singleInstance;
    bool m_connectOnStart;
    bool m_connectOnLogon;
    bool m_reconnectOnDrop;
    bool m_notifyOnChange;
    bool m_checkUpdates;
    QString m_autoConnectProfile;

    // Telling a connection that ended from one that was ended: only the first
    // is worth dialling again.
    bool m_userAskedToDisconnect;
    bool m_wasConnected;
    int m_reconnectAttempts;
    QTimer* m_reconnectTimer;

    mutable QMutex m_promptMutex;
    QWaitCondition m_promptCondition;
    QEventLoop* m_promptLoop;
    QString m_promptText;
    bool m_promptAccepted;
    bool m_promptAnswered;
};
