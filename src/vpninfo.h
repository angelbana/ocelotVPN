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

#include <QString>
#include <QUrl>
#include "common.h"

class StoredServer;
class VpnController;

class VpnInfo {
public:
    VpnInfo(QString name, StoredServer* ss, VpnController* m);
    ~VpnInfo();

    void setUrl(const QUrl& url);
    int connect();
    void mainloop();
    void get_info(QString& dns, QString& ip, QString& ip6, QString& domains);
    void get_cipher_info(QString& cstp, QString& dtls);

    // The address of the profile icon, if the server named one in a header.
    // Empty when it did not; available only once the connection is up.
    void logServerOptions();
    // What the server said about how long this sign-in is good for. Worth
    // knowing: a session that runs out is the usual reason a tunnel that was
    // working all day stops in the evening.
    void logSessionExpiry();
    SOCKET get_cmd_fd() const;
    void reset_vpn();
    bool get_minimize() const;
    bool is_username_form_option(struct oc_auth_form* form, struct oc_form_opt* opt);
    bool is_password_form_option(struct oc_auth_form* form, struct oc_form_opt* opt);

    QString last_err;
    // Set when the server refused who we said we were, as opposed to not being
    // reachable at all. The two deserve opposite answers: one is worth trying
    // again, the other would only lock the account.
    bool auth_failed = false;
    bool auth_cancelled = false;
    QUrl mUrl;
    VpnController* m;
    StoredServer* ss;
    struct openconnect_info* vpninfo;
    unsigned int authgroup_set;
    unsigned int password_set;
    unsigned int form_attempt;
    unsigned int form_pass_attempt;
    bool last_form_empty = false;

    void logVpncScriptOutput();
    QByteArray generateUniqueInterfaceName();

private:
    SOCKET cmd_fd;
};
