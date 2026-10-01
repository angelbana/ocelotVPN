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

#pragma once

#include <QObject>
#include <QString>

class QNetworkAccessManager;
class QNetworkReply;
class QFile;

// Fetching the next version and putting it in place.
//
// Nothing here happens by itself: the program only ever looks at what the
// latest release is called, and this is started by someone pressing a button.
//
// What arrives is checked twice before it is run. The list of files comes from
// GitHub over TLS and carries a SHA-512 for each one, and that is what the
// downloaded file is measured against; then, on Windows, the signature on it is
// read, and the name it was signed with is shown to the person before anything
// is started. A file that fails either check is deleted rather than offered.
//
// An installed copy is replaced by running the installer, which is what it is
// for. A copy that runs from its own folder is replaced by unpacking the
// archive beside it and letting someone outside the program swap the files once
// it has quit - the same trick the folder uses to delete itself, for the same
// reason: a program cannot overwrite the file it is running from.
class Updater : public QObject {
    Q_OBJECT

public:
    explicit Updater(QObject* parent = nullptr);
    ~Updater();

    // Whether a download is going on, and how far it has got (0 to 1).
    bool busy() const;
    double progress() const;

    // The file that was downloaded and checked, and the name it was signed
    // with - empty where nothing has been downloaded yet.
    QString file() const;
    QString signer() const;

    // Looks up the release of that version, downloads the file this copy needs
    // and checks it. Answers through the signals below.
    void start(const QString& version);

    // Puts what was downloaded in place. The program has to quit for it to
    // finish, which the caller does after this returns true.
    bool apply(QString& error);

signals:
    void progressChanged();
    // The file is downloaded and checked; signer is empty where signatures are
    // not a thing this system has.
    void ready(const QString& version, const QString& signer);
    void failed(const QString& message);

private:
    void requestRelease();
    void gotRelease(QNetworkReply* reply);
    void gotChecksum(QNetworkReply* reply);
    void startDownload();
    void gotFile(QNetworkReply* reply);
    bool verifyChecksum(const QString& path, QString& error) const;
    QString readSigner(const QString& path) const;
    void fail(const QString& message);
    void cleanUp();

    QNetworkAccessManager* m_network;
    QNetworkReply* m_reply;
    QFile* m_sink;

    QString m_version;
    QString m_assetName;
    QString m_assetUrl;
    QString m_checksumUrl;
    QString m_expectedHash;
    QString m_file;
    QString m_signer;
    bool m_busy;
    double m_progress;
};
