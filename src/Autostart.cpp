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

#include "Autostart.h"

#include "config.h"
#include "logger.h"

#include <QCoreApplication>
#include <QDir>
#include <QObject>
#include <QProcess>
#include <QFile>
#include <QTemporaryDir>
#include <QTextStream>

namespace {

const char* const TASK_NAME = PRODUCT_NAME_SHORT;

#ifdef Q_OS_WIN

QString schtasks()
{
    const QString root = qEnvironmentVariable("SystemRoot", QStringLiteral("C:/Windows"));
    return QDir::toNativeSeparators(root + QStringLiteral("/System32/schtasks.exe"));
}

QString currentUser()
{
    const QString domain = qEnvironmentVariable("USERDOMAIN");
    const QString user = qEnvironmentVariable("USERNAME");
    return domain.isEmpty() ? user : domain + QLatin1Char('\\') + user;
}

QString programPath()
{
    return QDir::toNativeSeparators(QCoreApplication::applicationFilePath());
}

// Runs schtasks and hands back what it said. Its own messages are localised,
// so they are shown as they come rather than matched against.
int runSchtasks(const QStringList& arguments, QString& output)
{
    QProcess process;
    process.setProgram(schtasks());
    process.setArguments(arguments);
    process.setProcessChannelMode(QProcess::MergedChannels);
    process.start();

    if (process.waitForStarted(5000) == false) {
        output = QObject::tr("The task scheduler could not be started.");
        return -1;
    }
    if (process.waitForFinished(20000) == false) {
        process.kill();
        output = QObject::tr("The task scheduler did not answer.");
        return -1;
    }

    // schtasks speaks the console code page, not UTF-8.
    output = QString::fromLocal8Bit(process.readAll()).trimmed();
    return process.exitCode();
}

QString escaped(const QString& text)
{
    QString out = text;
    out.replace(QLatin1Char('&'), QLatin1String("&amp;"));
    out.replace(QLatin1Char('<'), QLatin1String("&lt;"));
    out.replace(QLatin1Char('>'), QLatin1String("&gt;"));
    return out;
}

// The task is registered from a definition rather than from a command line.
// Several of the scheduler's defaults are wrong for a VPN client and can only
// be changed this way: a task started at sign-in is killed after three days,
// and on a laptop running on battery it is not started at all.
QString taskDefinition()
{
    const QString user = escaped(currentUser());

    return QStringLiteral(R"(<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Starts %1 when you sign in to Windows.</Description>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
      <UserId>%2</UserId>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>%2</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>false</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>6</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>%3</Command>
      <Arguments>%4</Arguments>
    </Exec>
  </Actions>
</Task>
)")
        .arg(QLatin1String(TASK_NAME), user, escaped(programPath()),
            QLatin1String(Autostart::logonFlag()));
}

#endif // Q_OS_WIN

} // namespace

namespace Autostart {

const char* logonFlag()
{
    return "--logon";
}

#ifdef Q_OS_WIN

bool isSupported()
{
    return true;
}

bool isEnabled()
{
    QString output;
    return runSchtasks({ QStringLiteral("/Query"), QStringLiteral("/TN"),
                           QLatin1String(TASK_NAME) },
               output)
        == 0;
}

bool setEnabled(bool enabled, QString& error)
{
    error.clear();

    if (enabled == false) {
        if (isEnabled() == false) {
            return true;
        }

        QString output;
        if (runSchtasks({ QStringLiteral("/Delete"), QStringLiteral("/TN"),
                            QLatin1String(TASK_NAME), QStringLiteral("/F") },
                output)
            != 0) {
            error = output;
            Logger::instance().addMessage(
                QObject::tr("Could not remove the sign-in task: %1").arg(output));
            return false;
        }

        Logger::instance().addMessage(QObject::tr("The sign-in task was removed"));
        return true;
    }

    // The definition has to reach schtasks as a file, and as UTF-16: it refuses
    // one written as UTF-8.
    QTemporaryDir dir;
    if (dir.isValid() == false) {
        error = QObject::tr("A temporary file could not be created.");
        return false;
    }

    const QString path = dir.filePath(QStringLiteral("task.xml"));
    QFile file(path);
    if (file.open(QIODevice::WriteOnly) == false) {
        error = QObject::tr("A temporary file could not be created.");
        return false;
    }
    {
        QTextStream stream(&file);
        stream.setEncoding(QStringConverter::Utf16LE);
        stream.setGenerateByteOrderMark(true);
        stream << taskDefinition();
    }
    file.close();

    QString output;
    if (runSchtasks({ QStringLiteral("/Create"), QStringLiteral("/TN"),
                        QLatin1String(TASK_NAME), QStringLiteral("/XML"),
                        QDir::toNativeSeparators(path), QStringLiteral("/F") },
            output)
        != 0) {
        error = output;
        Logger::instance().addMessage(
            QObject::tr("Could not create the sign-in task: %1").arg(output));
        return false;
    }

    Logger::instance().addMessage(
        QObject::tr("%1 will start when you sign in").arg(QLatin1String(TASK_NAME)));
    return true;
}

#else

bool isSupported()
{
    return false;
}

bool isEnabled()
{
    return false;
}

bool setEnabled(bool enabled, QString& error)
{
    Q_UNUSED(enabled)
    error = QObject::tr("Starting at sign-in is only available on Windows.");
    return false;
}

#endif // Q_OS_WIN

} // namespace Autostart
