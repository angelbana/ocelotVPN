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

#include "Updater.h"

#include "Portable.h"
#include "config.h"
#include "logger.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QStandardPaths>
#include <QUrl>

namespace {

// github.com/<owner>/<repo> is written down once, in the build; the address the
// list of files comes from is worked out from it rather than written again.
QString releaseApiUrl()
{
    const QUrl repo{ QLatin1String(APP_REPO_URL) };
    return QStringLiteral("https://api.github.com/repos") + repo.path()
        + QStringLiteral("/releases/latest");
}

// What this copy replaces itself with: an installed one takes the installer, a
// copy that runs from its own folder takes the archive that folder came in.
QString wantedSuffix()
{
#ifdef Q_OS_WIN
    return Portable::isActive() ? QStringLiteral("-portable.zip") : QStringLiteral("-win64.exe");
#else
    return QStringLiteral(".AppImage");
#endif
}

QString downloadDirectory()
{
    return QDir::cleanPath(QStandardPaths::writableLocation(QStandardPaths::TempLocation)
        + QStringLiteral("/ocelot-update"));
}

} // namespace

Updater::Updater(QObject* parent)
    : QObject(parent)
    , m_network(new QNetworkAccessManager(this))
    , m_reply(nullptr)
    , m_sink(nullptr)
    , m_busy(false)
    , m_progress(0)
{
}

Updater::~Updater()
{
    cleanUp();
}

bool Updater::busy() const
{
    return m_busy;
}

double Updater::progress() const
{
    return m_progress;
}

QString Updater::file() const
{
    return m_file;
}

QString Updater::signer() const
{
    return m_signer;
}

void Updater::start(const QString& version)
{
    if (m_busy == true) {
        return;
    }

    m_version = version;
    m_assetName.clear();
    m_assetUrl.clear();
    m_checksumUrl.clear();
    m_expectedHash.clear();
    m_file.clear();
    m_signer.clear();
    m_progress = 0;
    m_busy = true;
    emit progressChanged();

    requestRelease();
}

void Updater::requestRelease()
{
    QNetworkRequest request{ QUrl(releaseApiUrl()) };
    request.setRawHeader("Accept", "application/vnd.github+json");
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
        QNetworkRequest::NoLessSafeRedirectPolicy);

    Logger::instance().addMessage(tr("Asking what the latest release holds"));

    QNetworkReply* reply = m_network->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() { gotRelease(reply); });
}

void Updater::gotRelease(QNetworkReply* reply)
{
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        fail(tr("The list of files could not be read: %1").arg(reply->errorString()));
        return;
    }

    const QJsonDocument document = QJsonDocument::fromJson(reply->readAll());
    const QJsonObject release = document.object();
    const QJsonArray assets = release.value(QStringLiteral("assets")).toArray();
    const QString suffix = wantedSuffix();

    for (const QJsonValue& value : assets) {
        const QJsonObject asset = value.toObject();
        const QString name = asset.value(QStringLiteral("name")).toString();
        const QString url = asset.value(QStringLiteral("browser_download_url")).toString();

        if (name.endsWith(suffix) == true) {
            m_assetName = name;
            m_assetUrl = url;
        } else if (name.endsWith(suffix + QStringLiteral(".sha512")) == true) {
            m_checksumUrl = url;
        }
    }

    if (m_assetUrl.isEmpty() == true) {
        fail(tr("That release has nothing this copy of Ocelot could install."));
        return;
    }
    if (m_checksumUrl.isEmpty() == true) {
        // Without the published sum there is nothing to measure the download
        // against, and running it unchecked is not on offer.
        fail(tr("That release carries no checksum for %1.").arg(m_assetName));
        return;
    }

    QNetworkRequest request{ QUrl(m_checksumUrl) };
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
        QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply* next = m_network->get(request);
    connect(next, &QNetworkReply::finished, this, [this, next]() { gotChecksum(next); });
}

void Updater::gotChecksum(QNetworkReply* reply)
{
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        fail(tr("The checksum could not be read: %1").arg(reply->errorString()));
        return;
    }

    // The file reads "<hash>  <name>", as sha512sum writes it.
    m_expectedHash = QString::fromLatin1(reply->readAll()).trimmed().section(QLatin1Char(' '), 0, 0);
    if (m_expectedHash.size() != 128) {
        fail(tr("The checksum published for %1 does not look like one.").arg(m_assetName));
        return;
    }

    startDownload();
}

void Updater::startDownload()
{
    const QString directory = downloadDirectory();
    QDir().mkpath(directory);

    const QString path = directory + QLatin1Char('/') + m_assetName;
    QFile::remove(path);

    m_sink = new QFile(path, this);
    if (m_sink->open(QIODevice::WriteOnly | QIODevice::Truncate) == false) {
        fail(tr("The file %1 could not be written.").arg(QDir::toNativeSeparators(path)));
        return;
    }

    Logger::instance().addMessage(tr("Downloading %1").arg(m_assetName));

    QNetworkRequest request{ QUrl(m_assetUrl) };
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
        QNetworkRequest::NoLessSafeRedirectPolicy);

    m_reply = m_network->get(request);
    connect(m_reply, &QNetworkReply::readyRead, this, [this]() {
        if (m_sink != nullptr) {
            m_sink->write(m_reply->readAll());
        }
    });
    connect(m_reply, &QNetworkReply::downloadProgress, this,
        [this](qint64 received, qint64 total) {
            m_progress = total > 0 ? double(received) / double(total) : 0;
            emit progressChanged();
        });
    connect(m_reply, &QNetworkReply::finished, this, [this]() { gotFile(m_reply); });
}

void Updater::gotFile(QNetworkReply* reply)
{
    const QString path = m_sink != nullptr ? m_sink->fileName() : QString();

    if (m_sink != nullptr) {
        m_sink->write(reply->readAll());
        m_sink->close();
        m_sink->deleteLater();
        m_sink = nullptr;
    }
    reply->deleteLater();
    m_reply = nullptr;

    if (reply->error() != QNetworkReply::NoError) {
        QFile::remove(path);
        fail(tr("The download did not finish: %1").arg(reply->errorString()));
        return;
    }

    QString problem;
    if (verifyChecksum(path, problem) == false) {
        QFile::remove(path);
        fail(problem);
        return;
    }

    m_signer = readSigner(path);
#ifdef Q_OS_WIN
    // Only the installer is signed; an archive is a container and carries no
    // signature of its own, which is what its checksum is for.
    if (m_assetName.endsWith(QStringLiteral(".exe")) == true && m_signer.isEmpty() == true) {
        QFile::remove(path);
        fail(tr("The downloaded installer carries no signature Windows accepts, "
                "so it will not be run."));
        return;
    }
#endif

    m_file = path;
    m_busy = false;
    m_progress = 1;
    emit progressChanged();

    Logger::instance().addMessage(tr("%1 was downloaded and checked").arg(m_assetName));
    emit ready(m_version, m_signer);
}

bool Updater::verifyChecksum(const QString& path, QString& error) const
{
    QFile file(path);
    if (file.open(QIODevice::ReadOnly) == false) {
        error = tr("The file %1 could not be read.").arg(QDir::toNativeSeparators(path));
        return false;
    }

    QCryptographicHash hash(QCryptographicHash::Sha512);
    if (hash.addData(&file) == false) {
        error = tr("The file %1 could not be read.").arg(QDir::toNativeSeparators(path));
        return false;
    }

    const QString got = QString::fromLatin1(hash.result().toHex());
    if (got.compare(m_expectedHash, Qt::CaseInsensitive) != 0) {
        error = tr("What was downloaded does not match the checksum published with it, "
                   "so it has been deleted.");
        return false;
    }

    return true;
}

QString Updater::readSigner(const QString& path) const
{
#ifdef Q_OS_WIN
    const QString quoted = QDir::toNativeSeparators(path)
                               .replace(QLatin1Char('\''), QStringLiteral("''"));
    const QString script = QStringLiteral(
        "$signature = Get-AuthenticodeSignature -LiteralPath '%1';"
        " if ($signature.Status -eq 'Valid') { $signature.SignerCertificate.Subject }")
                               .arg(quoted);

    QProcess shell;
    shell.start(QStringLiteral("powershell"), QStringList()
            << QStringLiteral("-NoProfile")
            << QStringLiteral("-NonInteractive")
            << QStringLiteral("-ExecutionPolicy") << QStringLiteral("Bypass")
            << QStringLiteral("-Command") << script);

    if (shell.waitForFinished(60000) == false) {
        shell.kill();
        return QString();
    }

    return QString::fromLocal8Bit(shell.readAllStandardOutput()).trimmed();
#else
    Q_UNUSED(path)
    return QString();
#endif
}

bool Updater::apply(QString& error)
{
    if (m_file.isEmpty() == true || QFile::exists(m_file) == false) {
        error = tr("There is nothing downloaded to install.");
        return false;
    }

#ifdef Q_OS_WIN
    if (Portable::isActive() == false) {
        // The installer knows how to replace an installed copy; it is started
        // and this program gets out of its way.
        if (QProcess::startDetached(m_file, QStringList()) == false) {
            error = tr("%1 could not be started.").arg(QDir::toNativeSeparators(m_file));
            return false;
        }
        return true;
    }

    // A copy that runs from its own folder is replaced in place: the archive is
    // unpacked beside it, and the swap is left to someone who is still there
    // after this program has quit.
    const QString unpacked = QDir::cleanPath(downloadDirectory() + QStringLiteral("/unpacked"));
    QDir(unpacked).removeRecursively();

    const QString script = QStringLiteral(
        "Expand-Archive -LiteralPath '%1' -DestinationPath '%2' -Force")
                               .arg(QDir::toNativeSeparators(m_file)
                                        .replace(QLatin1Char('\''), QStringLiteral("''")),
                                   QDir::toNativeSeparators(unpacked)
                                       .replace(QLatin1Char('\''), QStringLiteral("''")));

    QProcess shell;
    shell.start(QStringLiteral("powershell"), QStringList()
            << QStringLiteral("-NoProfile")
            << QStringLiteral("-NonInteractive")
            << QStringLiteral("-ExecutionPolicy") << QStringLiteral("Bypass")
            << QStringLiteral("-Command") << script);

    if (shell.waitForFinished(300000) == false || shell.exitCode() != 0) {
        shell.kill();
        error = tr("The archive could not be unpacked.");
        return false;
    }

    // The archive holds one folder with everything in it; the files to copy
    // over are inside that folder, not beside it.
    QString source = unpacked;
    const QFileInfoList inside = QDir(unpacked).entryInfoList(
        QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot);
    if (inside.size() == 1 && inside.first().isDir() == true) {
        source = inside.first().absoluteFilePath();
    }
    if (QFile::exists(source + QStringLiteral("/")
            + QFileInfo(QCoreApplication::applicationFilePath()).fileName())
        == false) {
        error = tr("The archive does not hold the program.");
        return false;
    }

    return Portable::replaceWith(source, downloadDirectory(), error);
#else
    error = tr("Installing an update is something only the Windows build does.");
    return false;
#endif
}

void Updater::fail(const QString& message)
{
    m_busy = false;
    m_progress = 0;
    emit progressChanged();

    Logger::instance().addMessage(message);
    emit failed(message);
}

void Updater::cleanUp()
{
    if (m_reply != nullptr) {
        m_reply->abort();
        m_reply = nullptr;
    }
    if (m_sink != nullptr) {
        m_sink->close();
        m_sink = nullptr;
    }
}
