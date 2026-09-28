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

/* undef on normal builds */
#undef PROJ_GNUTLS_DEBUG

#define TMP_CERT_PREFIX "/tmp-certXXXXXX"
#define TMP_KEY_PREFIX "/tmp-keyXXXXXX"

#define UPDATE_TIMER 10000

#ifdef _WIN32
#define net_errno WSAGetLastError()
#define ms_sleep Sleep

//openconnect.h allows users to choose between <winsock.h> and <winsock2.h>
//and that choice needs to be made before including openconnect.h
#include <winsock2.h>

#include <iphlpapi.h>

#else /* ! _WIN32 */
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#define ms_sleep(x) usleep(1000 * x)
#define INVALID_SOCKET -1
#define SOCKET int
#define closesocket close
#define net_errno errno
#endif /* _WIN32 */

extern "C" {
#include <gnutls/gnutls.h>
#include <openconnect.h>
}

#ifdef _WIN32

#if OPENCONNECT_CHECK_VER(5, 10)
/* openconnect >=9.13 (hopefully, api ver 5.10) supports interface name length up to MAX_ADAPTER_NAME - 1 characters. */
#define OC_IFNAME_MAX_LENGTH (MAX_ADAPTER_NAME - 1)
#else
/* openconnect 9.12 supports interface name length up to 39 characters. */
#define OC_IFNAME_MAX_LENGTH (40 - 1)
#endif

#endif /* _WIN32 */

#if GNUTLS_VERSION_NUMBER >= 0x030400
#define USE_SYSTEM_KEYS
#endif

#include <QString>

inline bool is_url(const QString& str)
{
    if (str.startsWith("system:") || str.startsWith("pkcs11:") || str.startsWith("system:")) {
        return true;
    }
    return false;
}
