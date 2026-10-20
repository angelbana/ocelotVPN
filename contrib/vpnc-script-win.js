// vpnc-script-win.js
//
// Originally part of vpnc source code:
// © 2007-2008 Maurice Massar, Jörg Mayer, Antonio Borneo, et al.
// © 2014 David Woodhouse <dwmw2@infradead.org>
// © 2020-2022 Daniel Lenski <dlenski@gmail.com> et al.
//
// Routing, IP, and DNS configuration script for OpenConnect.
//
// Taken from https://gitlab.com/openconnect/vpnc-scripts at revision
// ce9e961bd0f6b867e1c7c35f78f6fb973f6ff101 and modified here: see
// docs/adr/0001-permanent-fork-from-upstream.md for why this file lives in
// the repository rather than being patched onto a clone.
//
// The change is split DNS. Upstream registers the tunnel's DNS servers for the
// whole interface, which sends every query into the VPN, and drops the list of
// domains the server asked to resolve through the tunnel. Here that list is
// honoured with Name Resolution Policy Table rules instead.
//
// Microsoft's "JScript" is what we're actually using here.  It's
// based on a truly ancient version of JavaScript (ECMAScript 3.0
// according to a Microsoft engineer, see
// https://stackoverflow.com/a/28331933) so it doesn't include any
// modern features:
//   - no String.prototype.trim       (ECMAScript 5.0)
//   - no Date.prototype.toISOString  (ECMAScript 5.1)
//   - no 'const'                     (ECMAScript 6.0)

// --------------------------------------------------------------
// Initial setup
// --------------------------------------------------------------

var accumulatedExitCode = 0;
var ws = WScript.CreateObject("WScript.Shell");
var env = ws.Environment("Process");
var comspec = ws.ExpandEnvironmentStrings("%comspec%");

var ERROR = 0, INFO = 1, DEBUG = 2, TRACE = 3;
var logLevel = parseInt(env("LOG_LEVEL")) || INFO;
var logTimestamps = false;

// NRPT ownership and verification are shared with the application's repair
// action in ocelot-dns.ps1.

// How to add the default internal route
// 0 - As interface gateway when setting properties
// 1 - As a 0.0.0.0/0 route with a lower metric than the default route
// 2 - As 0.0.0.0/1 + 128.0.0.0/1 routes (override the default route cleanly)
var REDIRECT_GATEWAY_METHOD = 0;

// --------------------------------------------------------------
// Utilities
// --------------------------------------------------------------

function ocTimestamp(d) {
    // Matches format of `openconnect --timestamp` ("%Y-%m-%d %H:%M:%S", local time)
    function pad(number) {
        if (number < 10)
            return '0' + number;
        return number;
    }
    return (d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' '
            + pad(d.getHours()) + ':' + pad(d.getMinutes())   + ':' + pad(d.getSeconds()));
}

function echo(level, msg)
{
    var msg_write;
    if (logLevel < level)
        return;

    if (logTimestamps)
        msg_write = "[" + ocTimestamp(new Date()) + "] " + msg;
    else
        msg_write = msg;

    if (env("LOG2FILE")) {
        log.WriteLine(msg_write);
    } else {
        WScript.echo(msg_write);
    }
}

function run_silent(cmd)
{
    var fullCmd = comspec + " /C \"" + cmd + "\" > NUL 2>&1";
    var oExec = ws.Exec(fullCmd);
    oExec.StdIn.Close();
}

function run(cmd)
{
    var fullCmd = comspec + " /C \"" + cmd + "\" 2>&1";
    echo(DEBUG, "-> " + fullCmd);
    var oExec = ws.Exec(fullCmd);
    oExec.StdIn.Close();

    var s = oExec.StdOut.ReadAll();

    var exitCode = oExec.ExitCode;
    if (exitCode != 0)
        echo(ERROR, "\"" + cmd + "\" returned non-zero exit status: " + exitCode);
    echo((exitCode != 0 ? ERROR : TRACE), "   stdout+stderr dump: " + s);
    accumulatedExitCode += exitCode;

    return s;
}

// Runs PowerShell from a temporary file rather than from the command line.
// The command would otherwise have to survive two levels of quoting - JScript
// and cmd.exe - and the NRPT commands contain quotes of their own.
function runPowerShell(psText)
{
    var fso = WScript.CreateObject("Scripting.FileSystemObject");
    var path = fso.GetSpecialFolder(2) + "\\" + fso.GetTempName() + ".ps1";
    var file = fso.CreateTextFile(path, true, true);
    file.WriteLine(psText);
    file.Close();

    // The short path has no spaces in it, which keeps the cmd.exe quoting simple.
    var shortPath = fso.GetFile(path).ShortPath;
    var powershell = ws.ExpandEnvironmentStrings("%SystemRoot%") +
        "\\System32\\WindowsPowerShell\\v1.0\\powershell.exe";
    try {
        return run('"' + powershell + '" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + shortPath + '"');
    } finally {
        fso.DeleteFile(path, true);
    }
}

function configureDns(action, zones, servers)
{
    var fso = WScript.CreateObject("Scripting.FileSystemObject");
    var helper = fso.GetParentFolderName(WScript.ScriptFullName) + "\\ocelot-dns.ps1";
    var zoneValues = [], serverValues = [];
    for (var i = 0; i < zones.length; i++)
        zoneValues[zoneValues.length] = psString(zones[i]);
    for (var i = 0; i < servers.length; i++)
        serverValues[serverValues.length] = psString(servers[i]);
    var previousExitCode = accumulatedExitCode;
    runPowerShell("$ErrorActionPreference = 'Stop'; try { . " + psString(helper) +
        "; Invoke-OcelotDns -Action " + action + " -Namespaces @(" + zoneValues.join(",") +
        ") -Servers @(" + serverValues.join(",") + ") | ConvertTo-Json -Compress } " +
        "catch { Write-Error $_.Exception.Message; exit 1 }");
    return accumulatedExitCode == previousExitCode;
}

// Remember only routes we actually added. Existing routes belong to their
// creator and must survive Ocelot disconnecting.
function outerRouteStatePath()
{
    var fso = WScript.CreateObject("Scripting.FileSystemObject");
    return fso.GetSpecialFolder(2) + "\\ocelot-outer-routes-" + env("TUNIDX") + ".json";
}

function psString(value)
{
    return "'" + value.replace(/'/g, "''") + "'";
}

function addOuterRoute(prefix)
{
    var state = psString(outerRouteStatePath());
    runPowerShell(
        "$ErrorActionPreference = 'Stop'; $prefix = " + psString(prefix) + "; " +
        "$state = " + state + "; " +
        "if (Get-NetRoute -DestinationPrefix $prefix -ErrorAction SilentlyContinue) { return }; " +
        "$address = $prefix.Split('/')[0]; " +
        "$best = Find-NetRoute -RemoteIPAddress $address | " +
        "Where-Object { $_.CimClass.CimClassName -eq 'MSFT_NetRoute' } | Select-Object -First 1; " +
        "if (!$best) { throw 'No route to the VPN gateway or excluded network' }; " +
        "$owned = @(); if (Test-Path -LiteralPath $state) { " +
        "$owned = @(Get-Content -LiteralPath $state -Raw | ConvertFrom-Json) }; " +
        "$created = New-NetRoute -DestinationPrefix $prefix -InterfaceIndex $best.InterfaceIndex " +
        "-NextHop $best.NextHop -RouteMetric 1 -PolicyStore ActiveStore; " +
        "$owned += $created | Select-Object DestinationPrefix, InterfaceIndex, NextHop; " +
        "try { ConvertTo-Json -InputObject @($owned) | Set-Content -LiteralPath $state } " +
        "catch { $created | Remove-NetRoute -Confirm:$false; throw }");
}

function removeOuterRoutes()
{
    runPowerShell(
        "$ErrorActionPreference = 'Stop'; $state = " + psString(outerRouteStatePath()) + "; " +
        "if (Test-Path -LiteralPath $state) { " +
        "$owned = @(Get-Content -LiteralPath $state -Raw | ConvertFrom-Json); " +
        "foreach ($entry in $owned) { " +
        "Get-NetRoute -DestinationPrefix $entry.DestinationPrefix " +
        "-InterfaceIndex $entry.InterfaceIndex -NextHop $entry.NextHop " +
        "-PolicyStore ActiveStore -ErrorAction SilentlyContinue | " +
        "Remove-NetRoute -Confirm:$false }; " +
        "Remove-Item -LiteralPath $state }");
}

function getDefaultGateway4()
{
    if (run("route print").match(/0\.0\.0\.0 *(0|128)\.0\.0\.0 *([0-9\.]*)/)) {
        return (RegExp.$2);
    }
    return ("");
}

function getDefaultGateway6()
{
    if (run("netsh interface ipv6 show route").match(/::\/0 *([0-9]+ *[0-9a-f:]+)/)) {
        return (RegExp.$1);
    }
    return ("");
}

if (!String.prototype.trim) {
    String.prototype.trim = function () {
        return this.replace(/^[\s﻿\xA0]+|[\s﻿\xA0]+$/g, '');
    };
}

// --------------------------------------------------------------
// Script starts here
// --------------------------------------------------------------

// Ensure that output of commands is in a known encoding for consistent
// logging.
run_silent("chcp 65001");

if (env("LOG2FILE")) {
	var fs = WScript.CreateObject("Scripting.FileSystemObject");
	var tmpdir = fs.GetSpecialFolder(2)+"\\";
	var log = fs.OpenTextFile(tmpdir + "vpnc.log", 8, true);
}

switch (env("reason")) {
case "pre-init":
    break;
case "connect":
    if (env("CISCO_BANNER")) {
        echo(INFO, "--------------------- BANNER ---------------------");
        echo(INFO, env("CISCO_BANNER"));
        echo(INFO, "------------------- BANNER end -------------------");
    }

    var gw4 = getDefaultGateway4();
    var gw6 = getDefaultGateway6();

    // Use INTERNAL_IP4_ADDRESS as the "gateway" address for the
    // VPN tunnel connection. As noted in the OpenConnect source,
    // "It's a tunnel; having a gateway is meaningless." Setting
    // the gateway to match the INTERNAL_IP4_ADDRESS seems like
    // the simplest way to behave correctly in all cases,
    // including when the INTERNAL_IP4_NETMASK is /0 or /32.
    var internal_ip4_netmask = env("INTERNAL_IP4_NETMASK") || "255.255.255.255";
    var internal_gw = env("INTERNAL_IP4_ADDRESS");

    echo(INFO, "Legacy IP Internet gateway: " + gw4);
    echo(INFO, "IPv6 Internet gateway     : " + gw6);
    echo(INFO, "VPN Interface Identifiers : \"" + env("TUNDEV") + "\" / " + env("TUNIDX"));
    echo(INFO, "Public VPN Gateway Address: " + env("VPNGATEWAY"));
    echo(INFO, "Internal Legacy IP Address: " + env("INTERNAL_IP4_ADDRESS"));
    echo(INFO, "Internal Legacy IP Netmask: " + internal_ip4_netmask);


    if (env("INTERNAL_IP4_MTU")) {
        echo(INFO, "MTU: " + env("INTERNAL_IP4_MTU"));
        run("netsh interface ipv4 set subinterface " + env("TUNIDX") +
            " mtu=" + env("INTERNAL_IP4_MTU") + " store=active");

        if (env("INTERNAL_IP6_ADDRESS")) {
            run("netsh interface ipv6 set subinterface " + env("TUNIDX") +
                " mtu=" + env("INTERNAL_IP4_MTU") + " store=active");
        }
    }

    // Add explicit route for the VPN gateway to avoid routing loops
    var vpngw = env("VPNGATEWAY");
    if (vpngw.match(/:/g)) {
	    echo(INFO, "Configuring explicit route to IPv6 VPN gateway " + vpngw);
        addOuterRoute(vpngw + "/128");
    } else {
	    echo(INFO, "Configuring explicit route to IPv4 VPN gateway " + vpngw);
        addOuterRoute(vpngw + "/32");
    }
    echo(INFO, "done.");

    // Select excluded paths before the VPN routes change the best route.
    // Add excluded routes
    if (env("CISCO_SPLIT_EXC")) {
        for (var i = 0 ; i < parseInt(env("CISCO_SPLIT_EXC")); i++) {
            var network = env("CISCO_SPLIT_EXC_" + i + "_ADDR");
            var netmask = env("CISCO_SPLIT_EXC_" + i + "_MASK");
            var netmasklen = env("CISCO_SPLIT_EXC_" + i + "_MASKLEN");
            addOuterRoute(network + "/" + netmasklen);
            echo(INFO, "Configured Legacy IP split-exclude route: " + network + "/" + netmasklen);
        }
    }

    echo(INFO, "Configuring \"" + env("TUNDEV") + "\" / " + env("TUNIDX") + " interface for Legacy IP...");

    if (!env("CISCO_SPLIT_INC") && REDIRECT_GATEWAY_METHOD != 2) {
        // Interface metric must be set to 1 in order to add a route with metric 1 since Windows Vista
        run("netsh interface ip set interface " + env("TUNIDX") + " metric=1 store=active");
    }

    if (env("CISCO_SPLIT_INC") || REDIRECT_GATEWAY_METHOD > 0) {
        run("netsh interface ip set address " + env("TUNIDX") + " static " +
            env("INTERNAL_IP4_ADDRESS") + " " + internal_ip4_netmask + " store=active");
    } else {
        // The default route will be added automatically
        run("netsh interface ip set address " + env("TUNIDX") + " static " +
            env("INTERNAL_IP4_ADDRESS") + " " + internal_ip4_netmask + " " + internal_gw +
            " gwmetric=1 store=active");
    }

    run("netsh interface ipv4 delete winsservers " + env("TUNIDX") + " all");
    if (env("INTERNAL_IP4_NBNS")) {
        var wins = env("INTERNAL_IP4_NBNS").split(/ /);
        for (var i = 0; i < wins.length; i++) {
            run("netsh interface ipv4 add winsservers " + env("TUNIDX") + " " + wins[i]);
        }
        echo(INFO, "Configured " + wins.length + " WINS servers: " + wins.join(" "));
    }

    // DNS is an additive NRPT overlay: leave all adapter DNS settings intact.
    // Removing only our rules restores the previous policy without overwriting
    // configuration changed by another VPN while Ocelot was connected.
    if (!configureDns("Cleanup", [], []))
        WScript.Quit(1);
    if (env("INTERNAL_IP4_DNS")) {
        var dns = env("INTERNAL_IP4_DNS").split(/ +/);
        var splitDns = env("OC_DNS_MODE") == "all" ? "" : env("CISCO_SPLIT_DNS");
        var namespaces = [];
        if (splitDns) {
            var zones = splitDns.split(/,/);
            for (var i = 0; i < zones.length; i++) {
                var zone = zones[i].trim();
                if (!zone)
                    continue;
                if (zone.charAt(0) != ".")
                    zone = "." + zone;
                namespaces[namespaces.length] = zone;
            }
            if (!namespaces.length) {
                echo(ERROR, "The server supplied an empty split DNS domain list");
                WScript.Quit(1);
            }
        } else {
            namespaces[0] = ".";
        }
        if (!configureDns("Apply", namespaces, dns))
            WScript.Quit(1);
        echo(INFO, "Configured DNS for " + namespaces.length + " zone(s) through " + dns.join(" "));
    }
    echo(INFO, "done.");

    // Add internal network routes
    echo(INFO, "Configuring Legacy IP networks:");
    if (env("CISCO_SPLIT_INC")) {
        for (var i = 0 ; i < parseInt(env("CISCO_SPLIT_INC")); i++) {
            var network = env("CISCO_SPLIT_INC_" + i + "_ADDR");
            var netmask = env("CISCO_SPLIT_INC_" + i + "_MASK");
            var netmasklen = env("CISCO_SPLIT_INC_" + i + "_MASKLEN");
            run("route add " + network + " mask " + netmask +
                " " + internal_gw + " if " + env("TUNIDX"));
            echo(INFO, "Configured Legacy IP split-include route: " + network + "/" + netmasklen);
        }
    } else if (REDIRECT_GATEWAY_METHOD == 1) {
        run("route add 0.0.0.0 mask 0.0.0.0 " + internal_gw + " metric 1");
        echo(INFO, "Configured Legacy IP default route.");
    } else if (REDIRECT_GATEWAY_METHOD == 2) {
        run("route add 0.0.0.0 mask 128.0.0.0 " + internal_gw);
        run("route add 128.0.0.0 mask 128.0.0.0 " + internal_gw);
        echo(INFO, "Configured Legacy IP default route pair (0.0.0.0/1, 128.0.0.0/1)");
    }

    echo(INFO, "Legacy IP route configuration done.");

    if (env("INTERNAL_IP6_ADDRESS")) {
        echo(INFO, "Configuring \"" + env("TUNDEV") + "\" / " + env("TUNIDX") + " interface for IPv6...");

        run("netsh interface ipv6 set address " + env("TUNIDX") + " " + env("INTERNAL_IP6_ADDRESS") + " store=active");

        echo(INFO, "done.");

        // Add internal network routes
        echo(INFO, "Configuring IPv6 networks:");
        if (env("INTERNAL_IP6_NETMASK") && !env("INTERNAL_IP6_NETMASK").match("/128$")) {
            run("netsh interface ipv6 add route " + env("INTERNAL_IP6_NETMASK") +
                " " + env("TUNIDX") + " store=active");
        }

        if (env("CISCO_IPV6_SPLIT_INC")) {
            for (var i = 0 ; i < parseInt(env("CISCO_IPV6_SPLIT_INC")); i++) {
                var network = env("CISCO_IPV6_SPLIT_INC_" + i + "_ADDR");
                var netmasklen = env("CISCO_IPV6_SPLIT_INC_" + i + "_MASKLEN");
                run("netsh interface ipv6 add route " + network + "/" +
                    netmasklen + " " + env("TUNIDX") + " store=active")
                echo(INFO, "Configured IPv6 split-include route: " + network + "/" + netmasklen);
            }
        } else {
            echo(INFO, "Setting default IPv6 route through VPN.");
            // We need to use the gateway address fe80::8 below, as this is how the TAP device on Windows provides a tunnel
            run("netsh interface ipv6 add route 2000::/3 " + env("TUNIDX") + " fe80::8 store=active");
        }

        // FIXME: handle IPv6 split-excludes

        echo(INFO, "IPv6 route configuration done.");
    }

    break;
case "disconnect":
    echo(INFO, "Deconfiguring \"" + env("TUNDEV") + "\" / " + env("TUNIDX") + " interface...");

    // Take our split-DNS rules out before anything else: they point at servers
    // that stop answering the moment the tunnel goes.
    configureDns("Cleanup", [], []);

    // Delete explicit route for the VPN gateway
    removeOuterRoutes();

    // Delete address
    echo(INFO, "Removing" + (env("INTERNAL_IP6_ADDRESS") ? " IPv6 and" : "") + " Legacy IP addresses");
    run("netsh interface ipv4 delete address " + env("TUNIDX") + " " +
        env("INTERNAL_IP4_ADDRESS") + " gateway=all");
    if (env("INTERNAL_IP6_ADDRESS")) {
        run("netsh interface ipv6 delete address " + env("TUNIDX") + " " + env("INTERNAL_IP6_ADDRESS") + " store=active");

        if (env("CISCO_IPV6_SPLIT_INC")) {
       	    // FIXME: handle IPv6 split-includes
        } else {
            echo(INFO, "Removing default IPv6 route through VPN.");
            run("netsh interface ipv6 delete route 2000::/3 " + env("TUNIDX"));
        }
    }

    // FIXME: handle IPv6 split-excludes
    echo(INFO, "done.");
}

if (env("LOG2FILE")) {
	log.Close();
}

WScript.Quit(accumulatedExitCode);
