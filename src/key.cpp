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

#include "key.h"
#include "common.h"
extern "C" {
#include <gnutls/pkcs11.h>
}

Key::Key()
    : privkey(nullptr)
    , imported(false)
{
}

Key::~Key()
{
    clear();
}

void Key::clear()
{
    if (this->privkey) {
        gnutls_x509_privkey_deinit(this->privkey);
        privkey = nullptr;
        imported = false;
    } else if (!this->url.isEmpty()) {
        url.clear();
        imported = false;
    }
}

static int import_Key(const Key::PasswordAsker& asker, gnutls_x509_privkey_t* privkey,
    gnutls_datum_t* raw)
{
    if (raw->size == 0) {
        return -1;
    }

    gnutls_x509_privkey_init(privkey);

    int ret = gnutls_x509_privkey_import2(*privkey, raw, GNUTLS_X509_FMT_PEM, NULL, 0);
    if (ret == GNUTLS_E_DECRYPTION_FAILED && asker) {
        QString text;
        if (asker(QLatin1String("This file requires a password. Please enter your password"), text) == false) {
            ret = -1;
            goto fail;
        }

        ret = gnutls_x509_privkey_import2(*privkey, raw, GNUTLS_X509_FMT_PEM,
            text.toUtf8().data(), 0);
    }

    if (ret == GNUTLS_E_BASE64_DECODING_ERROR || ret == GNUTLS_E_BASE64_UNEXPECTED_HEADER_ERROR) {
        ret = gnutls_x509_privkey_import(*privkey, raw, GNUTLS_X509_FMT_DER);
    }
    if (ret < 0) {
        goto fail;
    }

    return 0;
fail:
    gnutls_x509_privkey_deinit(*privkey);
    *privkey = nullptr;
    return ret;
}

int Key::import_pem(const QByteArray& data)
{
    gnutls_datum_t raw;
    raw.data = (unsigned char*)data.constData();
    raw.size = data.size();

    int ret = import_Key(this->asker, &this->privkey, &raw);
    if (ret < 0) {
        this->last_err = gnutls_strerror(ret);
        return -1;
    }
    imported = true;
    return 0;
}

void Key::set(const gnutls_x509_privkey_t privkey)
{
    clear();
    this->privkey = privkey;
    this->imported = true;
}

void Key::set_password_asker(const PasswordAsker& asker)
{
    this->asker = asker;
}

int Key::data_export(QByteArray& data)
{
    if (imported == false) {
        return -1;
    }

    data.clear();
    if (this->url.isEmpty() == false) {
        /* export the URL */
        data.append(this->url.toUtf8());
        return 0;
    }

    gnutls_datum_t raw;
    int ret = gnutls_x509_privkey_export2(this->privkey, GNUTLS_X509_FMT_PEM, &raw);
    if (ret < 0) {
        this->last_err = gnutls_strerror(ret);
        return -1;
    }

    data = QByteArray((char*)raw.data, raw.size);
    gnutls_free(raw.data);
    return 0;
}

int Key::import_file(const QString& File)
{
    gnutls_datum_t contents = { NULL, 0 };

    if (File.isEmpty() == true) {
        return -1;
    }

    if (this->imported != false) {
        this->clear();
    }

    if (is_url(File) == true) {
        this->url = File;
        imported = true;
        return 0;
    }

    /* normal file */
    int ret = gnutls_load_file(File.toUtf8().data(), &contents);
    if (ret < 0) {
        this->last_err = gnutls_strerror(ret);
        return -1;
    }

    ret = import_Key(this->asker, &this->privkey, &contents);
    gnutls_free(contents.data);
    if (ret < 0) {
        this->last_err = gnutls_strerror(ret);
        return -1;
    }

    imported = true;
    return 0;
}

int Key::tmpfile_export(QString& filename)
{
    if (this->imported == false) {
        return -1;
    }

    if (this->url.isEmpty() == false) {
        filename = this->url;
        return 0;
    }

    tmpfile.resize(0);
    filename = TMP_KEY_PREFIX;
    tmpfile.setFileTemplate(QDir::tempPath() + filename);

    gnutls_datum_t out;
    int ret = gnutls_x509_privkey_export2(this->privkey, GNUTLS_X509_FMT_PEM, &out);
    if (ret < 0) {
        this->last_err = gnutls_strerror(ret);
        return -1;
    }

    QByteArray qa;
    qa.append((const char*)out.data, out.size);
    gnutls_free(out.data);

    bool opened = tmpfile.open();
    if (!opened) {
        return -1;
    }

    ret = tmpfile.write(qa);
    tmpfile.close();
    if (ret == -1) {
        return -1;
    }
    filename = tmpfile.fileName();
    return 0;
}

bool Key::is_ok() const
{
    return imported;
}

void Key::get_url(QString& url) const
{
    url = this->url;
}
