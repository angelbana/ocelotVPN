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

#include "KillSwitch.h"

#include "logger.h"

#include <QCoreApplication>
#include <QDir>
#include <QHostAddress>
#include <QObject>

#ifdef Q_OS_WIN

#include <winsock2.h>
#include <ws2ipdef.h>
#include <ws2tcpip.h>

#include <windows.h>

#include <fwpmu.h>
#include <iphlpapi.h>

namespace {

// The filtering platform's own names for the places a rule can sit and the
// things it can look at. The toolchain's headers declare the functions but not
// these, so they are written out here - the values are Microsoft's own, read
// from the Windows SDK.
const GUID kLayerConnectV4 = { 0xc38d57d1, 0x05a7, 0x4c33,
    { 0x90, 0x4f, 0x7f, 0xbc, 0xee, 0xe6, 0x0e, 0x82 } };
const GUID kLayerConnectV6 = { 0x4a72393b, 0x319f, 0x44bc,
    { 0x84, 0xc3, 0xba, 0x54, 0xdc, 0xb3, 0xb6, 0xb4 } };
const GUID kLayerAcceptV4 = { 0xe1cd9fe7, 0xf4b5, 0x4273,
    { 0x96, 0xc0, 0x59, 0x2e, 0x48, 0x7b, 0x86, 0x50 } };
const GUID kLayerAcceptV6 = { 0xa3b42c97, 0x9f04, 0x4672,
    { 0xb8, 0x7e, 0xce, 0xe9, 0xc4, 0x83, 0x25, 0x7f } };

const GUID kConditionAppId = { 0xd78e1e87, 0x8644, 0x4ea5,
    { 0x94, 0x37, 0xd8, 0x09, 0xec, 0xef, 0xc9, 0x71 } };
const GUID kConditionLocalInterface = { 0x4cd62a49, 0x59c3, 0x4969,
    { 0xb7, 0xf3, 0xbd, 0xa5, 0xd3, 0x28, 0x90, 0xa4 } };
const GUID kConditionProtocol = { 0x3971ef2b, 0x623e, 0x4f9a,
    { 0x8c, 0xb1, 0x6e, 0x79, 0xb8, 0x06, 0xb9, 0xa7 } };
const GUID kConditionRemoteAddress = { 0xb235ae9a, 0x1d64, 0x49b8,
    { 0xa4, 0x4c, 0x5f, 0xf3, 0xd9, 0x09, 0x50, 0x45 } };
const GUID kConditionRemotePort = { 0xc35a604d, 0xd22b, 0x4e1a,
    { 0x91, 0xb4, 0x68, 0xf6, 0x74, 0xee, 0x67, 0x4b } };

// Ours, and nobody else's: the rules are weighed against each other inside it
// rather than against whatever the firewall is already doing.
// Not in the toolchain's headers either; the value is Microsoft's own. It is
// the whole point of this file: what a dynamic session writes, the system takes
// away again when the session's handle goes.
#ifndef FWPM_SESSION_FLAG_DYNAMIC
#define FWPM_SESSION_FLAG_DYNAMIC (0x00000001)
#endif

const GUID kSubLayer = { 0x0ce1075f, 0x7b4d, 0x4de4,
    { 0x9a, 0x6d, 0x21, 0x5c, 0x1b, 0x73, 0x0e, 0x42 } };

HANDLE g_engine = nullptr;
FWP_BYTE_BLOB* g_appId = nullptr;

const UINT8 kWeightBlock = 0;
const UINT8 kWeightAllow = 10;
const UINT8 kWeightProgram = 12;

QString lastError(DWORD status)
{
    return QStringLiteral("0x%1").arg(static_cast<quint32>(status), 8, 16, QLatin1Char('0'));
}

// Which interface wears that address. The tunnel is found by its own address
// rather than by its name: the name a server hands out is not ours to predict,
// and the address is the one thing the connection already told us.
bool interfaceFor(const QString& address, NET_LUID& luid)
{
    const QHostAddress wanted{ address };
    if (wanted.isNull() == true) {
        return false;
    }

    MIB_UNICASTIPADDRESS_TABLE* table = nullptr;
    if (GetUnicastIpAddressTable(AF_UNSPEC, &table) != NO_ERROR || table == nullptr) {
        return false;
    }

    bool found = false;
    for (ULONG i = 0; i < table->NumEntries && found == false; i++) {
        const MIB_UNICASTIPADDRESS_ROW& row = table->Table[i];
        QHostAddress here;

        if (row.Address.si_family == AF_INET) {
            here = QHostAddress(ntohl(row.Address.Ipv4.sin_addr.s_addr));
        } else if (row.Address.si_family == AF_INET6) {
            here = QHostAddress(row.Address.Ipv6.sin6_addr.s6_addr);
        }

        if (here.isNull() == false && here == wanted) {
            luid = row.InterfaceLuid;
            found = true;
        }
    }

    FreeMibTable(table);
    return found;
}

bool addFilter(const wchar_t* name, const GUID& layer, FWP_ACTION_TYPE action, UINT8 weight,
    FWPM_FILTER_CONDITION0* conditions, UINT32 count, QString& error)
{
    FWPM_FILTER0 filter;
    ZeroMemory(&filter, sizeof(filter));

    filter.displayData.name = const_cast<wchar_t*>(name);
    filter.layerKey = layer;
    filter.subLayerKey = kSubLayer;
    filter.action.type = action;
    filter.weight.type = FWP_UINT8;
    filter.weight.uint8 = weight;
    filter.filterCondition = conditions;
    filter.numFilterConditions = count;

    const DWORD status = FwpmFilterAdd0(g_engine, &filter, nullptr, nullptr);
    if (status != ERROR_SUCCESS) {
        error = QObject::tr("A rule could not be written (%1).").arg(lastError(status));
        return false;
    }
    return true;
}

bool blockEverything(QString& error)
{
    const GUID layers[] = { kLayerConnectV4, kLayerConnectV6, kLayerAcceptV4, kLayerAcceptV6 };
    for (const GUID& layer : layers) {
        if (addFilter(L"Ocelot: nothing leaves outside the tunnel", layer, FWP_ACTION_BLOCK,
                kWeightBlock, nullptr, 0, error)
            == false) {
            return false;
        }
    }
    return true;
}

bool allowInterface(const NET_LUID& luid, const wchar_t* name, QString& error)
{
    FWPM_FILTER_CONDITION0 condition;
    ZeroMemory(&condition, sizeof(condition));
    condition.fieldKey = kConditionLocalInterface;
    condition.matchType = FWP_MATCH_EQUAL;
    condition.conditionValue.type = FWP_UINT64;
    condition.conditionValue.uint64 = const_cast<UINT64*>(&luid.Value);

    const GUID layers[] = { kLayerConnectV4, kLayerConnectV6, kLayerAcceptV4, kLayerAcceptV6 };
    for (const GUID& layer : layers) {
        if (addFilter(name, layer, FWP_ACTION_PERMIT, kWeightAllow, &condition, 1, error) == false) {
            return false;
        }
    }
    return true;
}

bool allowThisProgram(QString& error)
{
    const QString path = QDir::toNativeSeparators(QCoreApplication::applicationFilePath());
    const DWORD status = FwpmGetAppIdFromFileName0(
        reinterpret_cast<const wchar_t*>(path.utf16()), &g_appId);
    if (status != ERROR_SUCCESS || g_appId == nullptr) {
        error = QObject::tr("This program could not be named to the firewall (%1).")
                    .arg(lastError(status));
        return false;
    }

    FWPM_FILTER_CONDITION0 condition;
    ZeroMemory(&condition, sizeof(condition));
    condition.fieldKey = kConditionAppId;
    condition.matchType = FWP_MATCH_EQUAL;
    condition.conditionValue.type = FWP_BYTE_BLOB_TYPE;
    condition.conditionValue.byteBlob = g_appId;

    const GUID layers[] = { kLayerConnectV4, kLayerConnectV6, kLayerAcceptV4, kLayerAcceptV6 };
    for (const GUID& layer : layers) {
        if (addFilter(L"Ocelot: its own connection to the server", layer, FWP_ACTION_PERMIT,
                kWeightProgram, &condition, 1, error)
            == false) {
            return false;
        }
    }
    return true;
}

// Everything a computer says to itself. Blocking this would stop far more than
// a leak: every program that talks to another one on the same machine.
bool allowLoopback(QString& error)
{
    FWP_V4_ADDR_AND_MASK loopback4;
    loopback4.addr = 0x7f000000;  // 127.0.0.0
    loopback4.mask = 0xff000000;  // /8

    FWPM_FILTER_CONDITION0 condition4;
    ZeroMemory(&condition4, sizeof(condition4));
    condition4.fieldKey = kConditionRemoteAddress;
    condition4.matchType = FWP_MATCH_EQUAL;
    condition4.conditionValue.type = FWP_V4_ADDR_MASK;
    condition4.conditionValue.v4AddrMask = &loopback4;

    if (addFilter(L"Ocelot: the computer talking to itself", kLayerConnectV4, FWP_ACTION_PERMIT,
            kWeightAllow, &condition4, 1, error)
        == false) {
        return false;
    }
    if (addFilter(L"Ocelot: the computer talking to itself", kLayerAcceptV4, FWP_ACTION_PERMIT,
            kWeightAllow, &condition4, 1, error)
        == false) {
        return false;
    }

    FWP_V6_ADDR_AND_MASK loopback6;
    ZeroMemory(&loopback6, sizeof(loopback6));
    loopback6.addr[15] = 1;  // ::1
    loopback6.prefixLength = 128;

    FWPM_FILTER_CONDITION0 condition6;
    ZeroMemory(&condition6, sizeof(condition6));
    condition6.fieldKey = kConditionRemoteAddress;
    condition6.matchType = FWP_MATCH_EQUAL;
    condition6.conditionValue.type = FWP_V6_ADDR_MASK;
    condition6.conditionValue.v6AddrMask = &loopback6;

    if (addFilter(L"Ocelot: the computer talking to itself", kLayerConnectV6, FWP_ACTION_PERMIT,
            kWeightAllow, &condition6, 1, error)
        == false) {
        return false;
    }
    return addFilter(L"Ocelot: the computer talking to itself", kLayerAcceptV6,
        FWP_ACTION_PERMIT, kWeightAllow, &condition6, 1, error);
}

// Without this the computer loses its address on the network it is plugged
// into the moment the lease runs out, and then there is no tunnel either.
bool allowAddressLeases(QString& error)
{
    FWPM_FILTER_CONDITION0 conditions[2];
    ZeroMemory(conditions, sizeof(conditions));

    conditions[0].fieldKey = kConditionProtocol;
    conditions[0].matchType = FWP_MATCH_EQUAL;
    conditions[0].conditionValue.type = FWP_UINT8;
    conditions[0].conditionValue.uint8 = IPPROTO_UDP;

    conditions[1].fieldKey = kConditionRemotePort;
    conditions[1].matchType = FWP_MATCH_EQUAL;
    conditions[1].conditionValue.type = FWP_UINT16;
    conditions[1].conditionValue.uint16 = 67;

    if (addFilter(L"Ocelot: keeping the address on this network", kLayerConnectV4,
            FWP_ACTION_PERMIT, kWeightAllow, conditions, 2, error)
        == false) {
        return false;
    }

    conditions[1].conditionValue.uint16 = 547;
    return addFilter(L"Ocelot: keeping the address on this network", kLayerConnectV6,
        FWP_ACTION_PERMIT, kWeightAllow, conditions, 2, error);
}

} // namespace

namespace KillSwitch {

bool isSupported()
{
    return true;
}

bool engaged()
{
    return g_engine != nullptr;
}

bool engage(const QString& tunnelAddress, QString& error)
{
    error.clear();

    if (g_engine != nullptr) {
        return true;
    }

    NET_LUID tunnel;
    ZeroMemory(&tunnel, sizeof(tunnel));
    if (interfaceFor(tunnelAddress, tunnel) == false) {
        error = QObject::tr("The tunnel's own interface could not be found, so nothing was "
                            "blocked.");
        return false;
    }

    FWPM_SESSION0 session;
    ZeroMemory(&session, sizeof(session));
    // The one flag that matters here: everything written in this session is
    // thrown away by the system when the handle goes, including when this
    // program goes with it. A computer left unable to reach the network by a
    // program that is no longer running would be the worse bug by far.
    session.flags = FWPM_SESSION_FLAG_DYNAMIC;
    session.displayData.name = const_cast<wchar_t*>(L"Ocelot");
    session.displayData.description = const_cast<wchar_t*>(L"Traffic stays in the tunnel");

    DWORD status = FwpmEngineOpen0(nullptr, RPC_C_AUTHN_DEFAULT, nullptr, &session, &g_engine);
    if (status != ERROR_SUCCESS) {
        g_engine = nullptr;
        error = QObject::tr("The firewall would not let Ocelot in (%1).").arg(lastError(status));
        return false;
    }

    FWPM_SUBLAYER0 sublayer;
    ZeroMemory(&sublayer, sizeof(sublayer));
    sublayer.subLayerKey = kSubLayer;
    sublayer.displayData.name = const_cast<wchar_t*>(L"Ocelot");
    sublayer.displayData.description = const_cast<wchar_t*>(L"Traffic stays in the tunnel");
    sublayer.weight = 0xffff;

    status = FwpmSubLayerAdd0(g_engine, &sublayer, nullptr);
    if (status != ERROR_SUCCESS) {
        release();
        error = QObject::tr("The firewall would not take Ocelot's rules (%1).")
                    .arg(lastError(status));
        return false;
    }

    if (blockEverything(error) == false || allowInterface(tunnel, L"Ocelot: the tunnel", error) == false
        || allowThisProgram(error) == false || allowLoopback(error) == false
        || allowAddressLeases(error) == false) {
        release();
        return false;
    }

    Logger::instance().addMessage(
        QObject::tr("Nothing leaves this computer outside the tunnel now"));
    return true;
}

void release()
{
    if (g_engine == nullptr) {
        return;
    }

    // Closing the handle is what removes the rules: they were written in a
    // session the system drops with it.
    FwpmEngineClose0(g_engine);
    g_engine = nullptr;

    if (g_appId != nullptr) {
        FwpmFreeMemory0(reinterpret_cast<void**>(&g_appId));
        g_appId = nullptr;
    }

    Logger::instance().addMessage(QObject::tr("Traffic may leave outside the tunnel again"));
}

}

#else // Q_OS_WIN

namespace KillSwitch {

bool isSupported()
{
    return false;
}

bool engaged()
{
    return false;
}

bool engage(const QString& tunnelAddress, QString& error)
{
    Q_UNUSED(tunnelAddress)
    error = QObject::tr("Holding traffic inside the tunnel is only available on Windows.");
    return false;
}

void release()
{
}

}

#endif // Q_OS_WIN
