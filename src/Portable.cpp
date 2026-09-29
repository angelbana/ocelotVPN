/*
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

#include "Portable.h"

#include "Autostart.h"
#include "config.h"
#include "logger.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QObject>
#include <QProcess>
#include <QSettings>
#include <QTextStream>

namespace {

bool g_decided = false;
bool g_portable = false;
QString g_data;

#ifdef Q_OS_WIN

// A folder is only usable for the settings if something can actually be put in
// it, which is asked by trying rather than by reading permissions: a stick may
// be write protected, and a folder inside another program's may not be ours.
bool folderTakesFiles(const QString& path)
{
    QFile probe(path + QStringLiteral("/.ocelot-write-test"));
    if (probe.open(QIODevice::WriteOnly) == false) {
        return false;
    }
    probe.close();
    probe.remove();
    return true;
}

QString fromEnvironment(const char* variable)
{
    return QDir::cleanPath(QDir::fromNativeSeparators(qEnvironmentVariable(variable)));
}

bool isBelow(const QString& path, const QString& root)
{
    if (root.isEmpty() == true) {
        return false;
    }
    return path.compare(root, Qt::CaseInsensitive) == 0
        || path.startsWith(root + QLatin1Char('/'), Qt::CaseInsensitive);
}

// Where programs are put on this computer. A copy in any of these was installed
// - by the button in the settings, by the installer, or by hand - and is not
// treated as portable however writable the folder happens to be.
bool inAProgramFolder(const QString& path)
{
    const char* const variables[] = { "ProgramFiles", "ProgramFiles(x86)",
        "ProgramW6432", "ProgramData" };

    for (const char* variable : variables) {
        if (isBelow(path, fromEnvironment(variable)) == true) {
            return true;
        }
    }

    const QString perUser = fromEnvironment("LocalAppData");
    return perUser.isEmpty() == false
        && isBelow(path, perUser + QStringLiteral("/Programs"));
}

QString uninstallKey()
{
    return QStringLiteral("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows"
                          "\\CurrentVersion\\Uninstall\\")
        + QLatin1String(PRODUCT_NAME_SHORT);
}

QString shortcutPath()
{
    const QString menu = fromEnvironment("ProgramData");
    if (menu.isEmpty() == true) {
        return QString();
    }
    return menu + QStringLiteral("/Microsoft/Windows/Start Menu/Programs/")
        + QLatin1String(PRODUCT_NAME_SHORT) + QStringLiteral(".lnk");
}

QString programName()
{
    return QFileInfo(QCoreApplication::applicationFilePath()).fileName();
}

// Runs a few lines of batch. The steps that outlive the program - deleting the
// folder it runs from, starting the copy that replaces it - cannot be handed to
// cmd as arguments: quoting a path with spaces through its parser is a trap, and
// the command interpreter reads such a line differently from everything else. So
// the commands go into a file, which deletes itself on its last line - and does
// so by leaving the batch first, or cmd reads on and complains about a file that
// is no longer there.
bool runDetachedScript(const QString& name, const QString& body, QString& error)
{
    const QString path = QDir::cleanPath(QDir::tempPath() + QLatin1Char('/') + name);

    QFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate) == false) {
        error = QObject::tr("The file %1 could not be written.")
                    .arg(QDir::toNativeSeparators(path));
        return false;
    }
    {
        QTextStream stream(&file);
        // In the console's own code page, because that is what cmd reads a batch
        // file as.
        stream.setEncoding(QStringConverter::System);
        stream << body;
    }
    file.close();

    if (QProcess::startDetached(QStringLiteral("cmd"),
            QStringList() << QStringLiteral("/c") << QDir::toNativeSeparators(path))
        == false) {
        error = QObject::tr("The command interpreter could not be started.");
        return false;
    }
    return true;
}

void writeUninstallEntry(const QString& target, quint64 bytes)
{
    const QString program = QDir::toNativeSeparators(target + QLatin1Char('/') + programName());
    const QString command = QLatin1Char('"') + program + QStringLiteral("\" ")
        + QLatin1String(Portable::uninstallFlag());

    QSettings entry(uninstallKey(), QSettings::NativeFormat);
    entry.setValue(QStringLiteral("DisplayName"), QLatin1String(PRODUCT_NAME_SHORT));
    // The plain version, not the one a development build carries the git
    // description in: this is what Programs and Features shows.
    entry.setValue(QStringLiteral("DisplayVersion"), QLatin1String(INTERNAL_PROJECT_VERSION));
    entry.setValue(QStringLiteral("Publisher"), QLatin1String(PRODUCT_NAME_COMPANY));
    entry.setValue(QStringLiteral("InstallLocation"), QDir::toNativeSeparators(target));
    entry.setValue(QStringLiteral("DisplayIcon"), program);
    entry.setValue(QStringLiteral("UninstallString"), command);
    entry.setValue(QStringLiteral("QuietUninstallString"), command);
    entry.setValue(QStringLiteral("URLInfoAbout"), QLatin1String(APP_REPO_URL));
    entry.setValue(QStringLiteral("NoModify"), 1);
    entry.setValue(QStringLiteral("NoRepair"), 1);
    // Windows shows this as the space the program takes, in kilobytes.
    entry.setValue(QStringLiteral("EstimatedSize"), static_cast<int>(bytes / 1024));
    entry.sync();

    if (entry.status() != QSettings::NoError) {
        Logger::instance().addMessage(QObject::tr(
            "Ocelot was copied, but the entry in Programs and Features could not be written"));
    }
}

// The shortcut is a small binary file that only the shell knows how to write,
// and the one way to ask it from here is the scripting object every Windows has.
void writeShortcut(const QString& target)
{
    const QString path = shortcutPath();
    if (path.isEmpty() == true) {
        return;
    }

    const QString link = QDir::toNativeSeparators(path)
                             .replace(QLatin1Char('\''), QStringLiteral("''"));
    const QString program = QDir::toNativeSeparators(target + QLatin1Char('/') + programName())
                                .replace(QLatin1Char('\''), QStringLiteral("''"));
    const QString folder = QDir::toNativeSeparators(target)
                               .replace(QLatin1Char('\''), QStringLiteral("''"));

    const QString script = QStringLiteral(
        "$link = (New-Object -ComObject WScript.Shell).CreateShortcut('%1');"
        " $link.TargetPath = '%2'; $link.WorkingDirectory = '%3';"
        " $link.IconLocation = '%2'; $link.Description = '%4'; $link.Save()")
                               .arg(link, program, folder, QLatin1String(PRODUCT_NAME_LONG));

    QProcess shell;
    shell.start(QStringLiteral("powershell"), QStringList()
            << QStringLiteral("-NoProfile")
            << QStringLiteral("-NonInteractive")
            << QStringLiteral("-ExecutionPolicy") << QStringLiteral("Bypass")
            << QStringLiteral("-Command") << script);

    if (shell.waitForFinished(20000) == false || shell.exitCode() != 0) {
        Logger::instance().addMessage(QObject::tr(
            "Ocelot was copied, but the Start menu shortcut could not be created"));
    }
}

// Everything the program is made of, except what belongs to the portable copy
// alone: its settings, and the log it has been writing.
bool copyFolder(const QString& from, const QString& to, quint64& bytes, QString& error)
{
    QDir source(from);
    const QFileInfoList entries = source.entryInfoList(
        QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot | QDir::Hidden);

    for (const QFileInfo& entry : entries) {
        const QString path = QDir::cleanPath(entry.absoluteFilePath());
        if (g_data.isEmpty() == false && path.compare(g_data, Qt::CaseInsensitive) == 0) {
            continue;
        }

        const QString destination = to + QLatin1Char('/') + entry.fileName();

        if (entry.isDir() == true) {
            if (QDir().mkpath(destination) == false) {
                error = QObject::tr("The folder %1 could not be created.")
                            .arg(QDir::toNativeSeparators(destination));
                return false;
            }
            if (copyFolder(path, destination, bytes, error) == false) {
                return false;
            }
            continue;
        }

        if (entry.suffix().compare(QStringLiteral("log"), Qt::CaseInsensitive) == 0) {
            continue;
        }

        QFile::remove(destination);
        if (QFile::copy(path, destination) == false) {
            error = QObject::tr("%1 could not be copied. If an installed Ocelot is "
                                "running, quit it and try again.")
                        .arg(QDir::toNativeSeparators(destination));
            return false;
        }
        bytes += static_cast<quint64>(entry.size());
    }

    return true;
}

// What the portable copy remembers is read from its file and written where the
// installed copy will look for it. An installed copy that already has settings
// of its own keeps them.
void carrySettings()
{
    QSettings installed(QSettings::NativeFormat, QSettings::UserScope,
        QLatin1String(PRODUCT_NAME_COMPANY), QLatin1String(PRODUCT_NAME_SHORT));
    if (installed.allKeys().isEmpty() == false) {
        return;
    }

    QSettings carried(QSettings::IniFormat, QSettings::UserScope,
        QLatin1String(PRODUCT_NAME_COMPANY), QLatin1String(PRODUCT_NAME_SHORT));
    const QStringList keys = carried.allKeys();
    if (keys.isEmpty() == true) {
        return;
    }

    for (const QString& key : keys) {
        installed.setValue(key, carried.value(key));
    }
    installed.sync();

    Logger::instance().addMessage(
        QObject::tr("The settings and profiles were carried over to the installed copy"));
}

#endif // Q_OS_WIN

} // namespace

namespace Portable {

const char* uninstallFlag()
{
    return "--uninstall";
}

const char* installFlag()
{
    return "--install";
}

void prepare()
{
    if (g_decided == true) {
        return;
    }
    g_decided = true;

#ifdef Q_OS_WIN
    const QString here = QDir::cleanPath(QCoreApplication::applicationDirPath());
    if (inAProgramFolder(here) == true || folderTakesFiles(here) == false) {
        return;
    }

    const QString data = here + QStringLiteral("/data");
    if (QDir().mkpath(data) == false) {
        return;
    }

    g_portable = true;
    g_data = data;
    // Every setting goes through OcSettings, which asks for a file rather than
    // the registry once this is on; this is where that file is looked for.
    QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, data);
#endif
}

bool isActive()
{
    return g_portable;
}

QString dataDirectory()
{
    return g_data;
}

#ifdef Q_OS_WIN

bool canInstall()
{
    return true;
}

QString installDirectory()
{
    // A 32-bit program is offered the 32-bit folder under its own name, so
    // asking for that one is right either way.
    QString root = fromEnvironment(sizeof(void*) == 4 ? "ProgramFiles" : "ProgramW6432");
    if (root.isEmpty() == true) {
        root = fromEnvironment("ProgramFiles");
    }
    if (root.isEmpty() == true) {
        root = QStringLiteral("C:/Program Files");
    }
    return root + QLatin1Char('/') + QLatin1String(PRODUCT_NAME_SHORT);
}

bool isInstalledCopy()
{
    QSettings entry(uninstallKey(), QSettings::NativeFormat);
    const QString recorded = QDir::cleanPath(QDir::fromNativeSeparators(
        entry.value(QStringLiteral("InstallLocation")).toString()));
    if (recorded.isEmpty() == true) {
        return false;
    }

    return recorded.compare(QDir::cleanPath(QCoreApplication::applicationDirPath()),
               Qt::CaseInsensitive)
        == 0;
}

QString installedProgram()
{
    return QDir::toNativeSeparators(installDirectory() + QLatin1Char('/') + programName());
}

bool install(QString& error)
{
    error.clear();

    const QString here = QDir::cleanPath(QCoreApplication::applicationDirPath());
    const QString target = installDirectory();

    if (here.compare(target, Qt::CaseInsensitive) == 0) {
        error = QObject::tr("Ocelot is already running from that folder.");
        return false;
    }
    if (QDir().mkpath(target) == false) {
        error = QObject::tr("The folder %1 could not be created.")
                    .arg(QDir::toNativeSeparators(target));
        return false;
    }

    quint64 bytes = 0;
    if (copyFolder(here, target, bytes, error) == false) {
        return false;
    }

    writeUninstallEntry(target, bytes);
    writeShortcut(target);
    carrySettings();

    Logger::instance().addMessage(
        QObject::tr("Ocelot was installed in %1").arg(QDir::toNativeSeparators(target)));
    return true;
}

bool launchInstalledAfterExit(QString& error)
{
    // Waiting for this program to end rather than for a set number of seconds,
    // because it may have a connection to bring down first. The count is there so
    // that the waiting can never go on for ever: after two minutes the copy is
    // started anyway, and the worst that does is raise the window of the one that
    // would not leave.
    const QString body = QStringLiteral(
        "@echo off\r\n"
        "for /l %%i in (1,1,60) do (\r\n"
        "  tasklist /fi \"PID eq %1\" | find \"%1\" >nul\r\n"
        "  if errorlevel 1 goto start\r\n"
        "  ping -n 2 127.0.0.1 >nul\r\n"
        ")\r\n"
        ":start\r\n"
        "start \"\" \"%2\"\r\n"
        "(goto) 2>nul & del \"%~f0\"\r\n")
                             .arg(QString::number(QCoreApplication::applicationPid()),
                                 installedProgram());

    return runDetachedScript(QStringLiteral("ocelot-start-installed.cmd"), body, error);
}

bool uninstall(QString& error)
{
    error.clear();

    const QString here = QDir::cleanPath(QCoreApplication::applicationDirPath());

    // The sign-in task names this copy; left behind, it would try every morning
    // to start a program that is no longer there.
    if (Autostart::isEnabled() == true) {
        QString ignored;
        Autostart::setEnabled(false, ignored);
    }

    const QString shortcut = shortcutPath();
    if (shortcut.isEmpty() == false) {
        QFile::remove(shortcut);
    }

    QSettings entry(uninstallKey(), QSettings::NativeFormat);
    entry.remove(QString());
    entry.sync();

    // The folder holds the program that is asking for it to be deleted, so the
    // deleting is left to someone outside it, who waits for this one to end. It
    // keeps trying for about a minute, which covers a connection that takes its
    // time coming down.
    const QString body = QStringLiteral(
        "@echo off\r\n"
        "for /l %%i in (1,1,30) do (\r\n"
        "  rd /s /q \"%1\" 2>nul\r\n"
        "  if not exist \"%1\" goto done\r\n"
        "  ping -n 3 127.0.0.1 >nul\r\n"
        ")\r\n"
        ":done\r\n"
        "(goto) 2>nul & del \"%~f0\"\r\n")
                             .arg(QDir::toNativeSeparators(here));

    if (runDetachedScript(QStringLiteral("ocelot-remove.cmd"), body, error) == false) {
        return false;
    }

    Logger::instance().addMessage(
        QObject::tr("Ocelot is removing itself from %1").arg(QDir::toNativeSeparators(here)));
    return true;
}

#else

bool canInstall()
{
    return false;
}

QString installDirectory()
{
    return QString();
}

bool isInstalledCopy()
{
    return false;
}

QString installedProgram()
{
    return QString();
}

bool install(QString& error)
{
    error = QObject::tr("Installing itself is something only the Windows build does.");
    return false;
}

bool launchInstalledAfterExit(QString& error)
{
    error = QObject::tr("Installing itself is something only the Windows build does.");
    return false;
}

bool uninstall(QString& error)
{
    error = QObject::tr("Installing itself is something only the Windows build does.");
    return false;
}

#endif // Q_OS_WIN

} // namespace Portable
