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

#include "server_storage.h"
#include "cryptdata.h"
#include "common.h"
#include <OcSettings.h>
#include <cstdio>

StoredServer::~StoredServer(void)
{
}

StoredServer::StoredServer()
    : m_batch_mode{ false }
    , m_minimize_on_connect{ false }
    , m_proxy{ false }
    , m_disable_udp{ false }
    , m_reconnect_timeout{ 300 }
    , m_dtls_attempt_period{ 25 }
    , m_server_pin_algo(0)
    , m_dns_mode{ 0 }
    , m_emoji{ defaultProfileEmoji() }
    , m_log_level (-1)
{
}

// LCA: drop this define from whole project...
#define PREFIX "server:"

void StoredServer::clear_password()
{
    this->m_password.clear();
}

void StoredServer::clear_groupname()
{
    this->m_groupname.clear();
}

void StoredServer::clear_cert()
{
    this->m_client.cert.clear();
}

void StoredServer::clear_key()
{
    this->m_client.key.clear();
}

void StoredServer::clear_ca()
{
    this->m_ca_cert.clear();
}

void StoredServer::clear_server_pin()
{
    this->m_server_pin.clear();
    this->m_server_pin_algo = 0;
}

QString StoredServer::get_cert_file()
{
    QString File;
    if (this->m_client.cert.is_ok()) {
        this->m_client.cert.tmpfile_export(File);
    }
    return File;
}

QString StoredServer::get_key_file()
{
    QString File;
    if (this->m_client.key.is_ok()) {
        this->m_client.key.tmpfile_export(File);
    }
    return File;
}

QString StoredServer::get_key_url() const
{
    QString File;
    if (this->m_client.key.is_ok()) {
        this->m_client.key.get_url(File);
    }
    return File;
}

QString StoredServer::get_ca_cert_file()
{
    QString File;
    if (this->m_ca_cert.is_ok()) {
        this->m_ca_cert.tmpfile_export(File);
    }
    return File;
}

int StoredServer::set_ca_cert(const QString& filename)
{
    int ret = this->m_ca_cert.import_file(filename);
    this->m_last_err = this->m_ca_cert.last_err;
    return ret;
}

int StoredServer::set_client_cert(const QString& filename)
{
    int ret = this->m_client.import_cert(filename);
    this->m_last_err = this->m_client.last_err;

    if (ret != 0) {
        ret = this->m_client.import_pfx(filename);
        this->m_last_err = this->m_client.last_err;
    }
    return ret;
}

int StoredServer::set_client_key(const QString& filename)
{
    int ret = this->m_client.import_key(filename);
    this->m_last_err = this->m_client.last_err;
    return ret;
}

bool StoredServer::server_pin_algo_is_legacy(void)
{
    if (this->m_server_pin_algo != GNUTLS_DIG_SHA256)
        return true;
    else
        return false;
}

void StoredServer::get_server_pin(QString& hash) const
{
    if (this->m_server_pin_algo == 0) {
        hash = "";
    } else {
        if (this->m_server_pin_algo == GNUTLS_DIG_SHA256) {
            hash = "pin-sha256:";
            hash += this->m_server_pin.toBase64();
        } else {
            hash = gnutls_mac_get_name((gnutls_mac_algorithm_t)this->m_server_pin_algo);
            hash += ":";
            hash += this->m_server_pin.toHex();
        }
    }
}

// Returns: < 0 on error to load
//          0 if no entry existed
//          1 if an entry existed
int StoredServer::load(QString& name)
{
    this->m_label = name;
    OcSettings settings;
    int rval = 1;

    settings.beginGroup(PREFIX + name);

    this->m_server_gateway = settings.value("server").toString();
    if (this->m_server_gateway.isEmpty() == true) {
        this->m_server_gateway = name;
        rval = 0;
    }

    this->m_username = settings.value("username").toString();
    this->m_batch_mode = settings.value("batch", false).toBool();
    this->m_proxy = settings.value("proxy", false).toBool();
    this->m_disable_udp = settings.value("disable-udp", false).toBool();
    this->m_minimize_on_connect = settings.value("minimize-on-connect", false).toBool();
    this->m_reconnect_timeout = settings.value("reconnect-timeout", 300).toInt();
    this->m_dtls_attempt_period = settings.value("dtls_attempt_period", 25).toInt();

    bool ret = false;

    if (this->m_batch_mode == true) {
        this->m_groupname = settings.value("groupname").toString();
        ret = CryptData::decode(this->m_server_gateway,
            settings.value("password").toByteArray(),
            this->m_password);
        if (ret == false) {
            m_last_err = "decoding of password failed";
            rval = -1;
        }
    }

    QByteArray data;
    data = settings.value("ca-cert").toByteArray();
    if (data.isEmpty() == false && this->m_ca_cert.import_pem(data) < 0) {
        this->m_last_err = this->m_ca_cert.last_err;
        rval = -1;
    }

    data = settings.value("client-cert").toByteArray();
    if (data.isEmpty() == false && this->m_client.cert.import_pem(data) < 0) {
        this->m_last_err = this->m_client.cert.last_err;
        rval = -1;
    }

    QString str;
    ret = CryptData::decode(this->m_server_gateway,
        settings.value("client-key").toByteArray(), str);
    if (ret == false) {
        m_last_err = "decoding of client keyfailed";
        rval = -1;
    }

    if (is_url(str) == true) {
        this->m_client.key.import_file(str);
    } else {
        data = str.toUtf8();
        this->m_client.key.import_pem(data);
    }

    this->m_server_pin = settings.value("server-hash").toByteArray();
    this->m_server_pin_algo = settings.value("server-hash-algo").toInt();

    ret = CryptData::decode(this->m_server_gateway,
        settings.value("token-str").toByteArray(),
        this->m_token_string);
    if (ret == false) {
        m_last_err = "decoding of OTP token failed";
        rval = -1;
    }

    this->m_token_type = settings.value("token-type").toInt();

    m_protocol_name = settings.value("protocol-name").toString();

    m_interface_name = settings.value("interface-name").toString();
#ifdef _WIN32
    /* truncate interface name to OC_IFNAME_MAX_LENGTH in case it was saved by a previous version
     * that did not impose the length constraint in the text edit
     */
    m_interface_name.truncate(OC_IFNAME_MAX_LENGTH);
#endif
    m_vpnc_script_filename = settings.value("vpnc-script").toString();
    m_emoji = settings.value("emoji", defaultProfileEmoji()).toString();

    m_log_level = settings.value("log-level", -1).toInt();
    m_dns_mode = settings.value("dns-mode", 0).toInt();

    settings.endGroup();
    return rval;
}

int StoredServer::save()
{
    OcSettings settings;
    settings.beginGroup(PREFIX + this->m_label);
    settings.setValue("server", this->m_server_gateway);
    settings.setValue("batch", this->m_batch_mode);
    settings.setValue("proxy", this->m_proxy);
    settings.setValue("disable-udp", this->m_disable_udp);
    settings.setValue("minimize-on-connect", this->m_minimize_on_connect);
    settings.setValue("reconnect-timeout", this->m_reconnect_timeout);
    settings.setValue("dtls_attempt_period", this->m_dtls_attempt_period);
    settings.setValue("username", this->m_username);

    if (this->m_batch_mode == true) {
        settings.setValue("password",
            CryptData::encode(this->m_server_gateway, this->m_password));
        settings.setValue("groupname", this->m_groupname);
    } else {
        // Switching the profile back to asking every time has to take the
        // stored password with it; leaving the key behind would keep a
        // password on disk that nothing is going to use again.
        settings.remove("password");
    }

    QByteArray data;
    this->m_ca_cert.data_export(data);
    settings.setValue("ca-cert", data);

    this->m_client.cert_export(data);
    settings.setValue("client-cert", data);

    this->m_client.key_export(data);
    QString str = QString::fromLatin1(data);
    settings.setValue("client-key", CryptData::encode(this->m_server_gateway, str));

    settings.setValue("server-hash", this->m_server_pin);
    settings.setValue("server-hash-algo", this->m_server_pin_algo);

    settings.setValue("token-str",
        CryptData::encode(this->m_server_gateway, this->m_token_string));
    settings.setValue("token-type", this->m_token_type);

    settings.setValue("protocol-name", m_protocol_name);

    settings.setValue("interface-name", m_interface_name);
    settings.setValue("vpnc-script", m_vpnc_script_filename);
    settings.setValue("emoji", m_emoji);
    settings.setValue("dns-mode", m_dns_mode);
    if (m_log_level == -1)
        settings.remove("log-level");
    else
        settings.setValue("log-level", m_log_level);

    settings.endGroup();
    return 0;
}

const QString& StoredServer::get_emoji() const
{
    return this->m_emoji;
}

void StoredServer::set_emoji(const QString& emoji)
{
    this->m_emoji = emoji;
}

int StoredServer::get_dns_mode() const
{
    return this->m_dns_mode;
}

void StoredServer::set_dns_mode(const int mode)
{
    this->m_dns_mode = mode;
}


const QString& StoredServer::get_username() const
{
    return this->m_username;
}

const QString& StoredServer::get_password() const
{
    return this->m_password;
}

const QString& StoredServer::get_groupname() const
{
    return this->m_groupname;
}

const QString& StoredServer::get_server_gateway() const
{
    return this->m_server_gateway;
}

const QString& StoredServer::get_label() const
{
    return this->m_label;
}

void StoredServer::set_username(const QString& username)
{
    this->m_username = username;
}

void StoredServer::set_password(const QString& password)
{
    this->m_password = password;
}

void StoredServer::set_groupname(const QString& groupname)
{
    this->m_groupname = groupname;
}

void StoredServer::set_server_gateway(const QString& server_gateway)
{
    this->m_server_gateway = server_gateway;
}

void StoredServer::set_label(const QString& label)
{
    this->m_label = label;
}

void StoredServer::set_disable_udp(bool v)
{
    this->m_disable_udp = v;
}

bool StoredServer::get_disable_udp() const
{
    return this->m_disable_udp;
}

QString StoredServer::get_client_cert_pin()
{
    return m_client.cert.cert_pin();
}

QString StoredServer::get_ca_cert_pin()
{
    return m_ca_cert.cert_pin();
}

void StoredServer::set_password_asker(const Key::PasswordAsker& asker)
{
    m_client.set_password_asker(asker);
}

void StoredServer::set_batch_mode(const bool mode)
{
    this->m_batch_mode = mode;
}

bool StoredServer::get_batch_mode() const
{
    return this->m_batch_mode;
}

bool StoredServer::get_minimize() const
{
    return this->m_minimize_on_connect;
}

bool StoredServer::get_proxy() const
{
    return this->m_proxy;
}

bool StoredServer::client_is_complete() const
{
    return m_client.is_complete();
}

void StoredServer::set_minimize(const bool t)
{
    this->m_minimize_on_connect = t;
}

void StoredServer::set_proxy(const bool t)
{
    this->m_proxy = t;
}

int StoredServer::get_reconnect_timeout() const
{
    return m_reconnect_timeout;
}

void StoredServer::set_reconnect_timeout(const int timeout)
{
    m_reconnect_timeout = timeout;
}

int StoredServer::get_dtls_reconnect_timeout() const
{
    return m_dtls_attempt_period;
}

void StoredServer::set_dtls_reconnect_timeout(const int timeout)
{
    m_dtls_attempt_period = timeout;
}

QString StoredServer::get_token_str()
{
    return this->m_token_string;
}

void StoredServer::set_token_str(const QString& str)
{
    this->m_token_string = str;
}

int StoredServer::get_token_type()
{
    return this->m_token_type;
}

void StoredServer::set_token_type(const int type)
{
    this->m_token_type = type;
}

const QString& StoredServer::get_protocol_name() const
{
    return m_protocol_name;
}

void StoredServer::set_protocol_name(const QString name)
{
    m_protocol_name = name;
}

void StoredServer::set_server_pin(const unsigned algo, const QByteArray& hash)
{
    this->m_server_pin_algo = algo;
    if (algo != GNUTLS_DIG_SHA256) {
        throw std::runtime_error("sha256 is the expected certificate algorithm pin");
    }
    this->m_server_pin = hash;
}

unsigned StoredServer::get_server_pin(QByteArray& hash) const
{
    hash = this->m_server_pin;
    return this->m_server_pin_algo;
}

const QString& StoredServer::get_interface_name() const
{
    return this->m_interface_name;
}

void StoredServer::set_interface_name(const QString& interface_name)
{
    this->m_interface_name = interface_name;
}

const QString& StoredServer::get_vpnc_script_filename() const
{
    return this->m_vpnc_script_filename;
}

void StoredServer::set_vpnc_script_filename(const QString& vpnc_script_filename)
{
    this->m_vpnc_script_filename = vpnc_script_filename;
}

int StoredServer::get_log_level()
{
    return this->m_log_level;
}

void StoredServer::set_log_level(const int log_level)
{
    this->m_log_level = log_level;
}

