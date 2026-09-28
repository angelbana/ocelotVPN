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

pragma Singleton

import QtQuick

QtObject {
    // keep in sync with VpnController::ThemeMode
    readonly property int themeOcelot: 0
    readonly property int themeDay: 1
    readonly property int themeNight: 2

    // bound to the controller by Main.qml; the singleton itself must not depend
    // on the context properties, they are not there yet when it is created
    property int mode: themeOcelot

    readonly property bool night: mode === themeNight

    // Three looks, one layout. Every difference between them lives in this one
    // object, so a theme is a set of colours and nothing else - no screen knows
    // which one is on.
    //
    // Ocelot is warm paper and amber, the colours the program is named after.
    // Day is the same design in cool neutrals. Night is the dark one.
    readonly property var palettes: [
        {
            "surface": "#fffdf9", "card": "#ffffff", "cardHover": "#fcf8f1",
            "stroke": "#e9e2d6", "strokeStrong": "#d8cdb9",
            "ink": "#2b2622", "inkSoft": "#7a7066", "inkFaint": "#a89e92",
            "accent": "#e88f34", "accentSoft": "#fdf0e0", "accentInk": "#ffffff",
            "mint": "#1c9c7e", "mintSoft": "#e2f7f1",
            "coral": "#d8453a", "coralSoft": "#fdeae8",
            "lavender": "#7166cf", "lavenderSoft": "#eeecfc",
            "blush": "#f4a2a8", "pelt": "#f7c886", "peltShade": "#eeb065", "spot": "#7f542e",
            "scrim": "#4d2b2622"
        },
        {
            "surface": "#eef1f7", "card": "#ffffff", "cardHover": "#e6ebf4",
            "stroke": "#dce2ec", "strokeStrong": "#c6cede",
            "ink": "#1b2330", "inkSoft": "#616d80", "inkFaint": "#93a0b4",
            "accent": "#e08529", "accentSoft": "#fdeedd", "accentInk": "#ffffff",
            "mint": "#0f9e79", "mintSoft": "#e0f5ef",
            "coral": "#d0443a", "coralSoft": "#fce9e7",
            "lavender": "#6459c9", "lavenderSoft": "#ebe9fb",
            "blush": "#f0a0a6", "pelt": "#f4c483", "peltShade": "#e9ab61", "spot": "#6f4a28",
            "scrim": "#4d1b2330"
        },
        {
            "surface": "#14161c", "card": "#1c1f27", "cardHover": "#232733",
            "stroke": "#2c313d", "strokeStrong": "#3c4351",
            "ink": "#e8ecf4", "inkSoft": "#9aa5b8", "inkFaint": "#6e7a8f",
            "accent": "#f2a857", "accentSoft": "#3a2a16", "accentInk": "#1a1206",
            "mint": "#40d1ad", "mintSoft": "#13322a",
            "coral": "#f7766b", "coralSoft": "#3a1f1c",
            "lavender": "#9f96eb", "lavenderSoft": "#262346",
            "blush": "#de8c93", "pelt": "#e2b070", "peltShade": "#cc9658", "spot": "#5a3d22",
            "scrim": "#b0080a0e"
        }
    ]

    readonly property var p: palettes[Math.max(0, Math.min(mode, palettes.length - 1))]

    readonly property color surface: p.surface
    readonly property color card: p.card
    readonly property color cardHover: p.cardHover
    readonly property color line: p.stroke
    readonly property color lineStrong: p.strokeStrong

    readonly property color ink: p.ink
    readonly property color muted: p.inkSoft
    readonly property color faint: p.inkFaint

    readonly property color accent: p.accent
    readonly property color accentSoft: p.accentSoft
    readonly property color accentInk: p.accentInk

    readonly property color ok: p.mint
    readonly property color okSoft: p.mintSoft
    readonly property color busy: p.lavender
    readonly property color busySoft: p.lavenderSoft
    readonly property color danger: p.coral
    readonly property color dangerSoft: p.coralSoft
    readonly property color dangerInk: night ? "#1c0c0b" : "#ffffff"
    readonly property color off: p.inkFaint
    readonly property color offSoft: p.cardHover

    // the mascot's own colours
    readonly property color blush: p.blush
    readonly property color pelt: p.pelt
    readonly property color peltShade: p.peltShade
    readonly property color spot: p.spot

    readonly property color scrim: p.scrim

    // Names the older screens were written against. Kept so a change of look is
    // a change of palette and nothing more.
    readonly property color raised: card
    readonly property color sunken: night ? p.surface : p.cardHover
    readonly property color warn: accent
    readonly property color warnSoft: accentSoft

    // Qt already scales the interface by the screen's device pixel ratio; this
    // keeps it usable when the user picks a larger system font as well.
    readonly property FontMetrics metrics: FontMetrics {
        font: Application.font
    }
    readonly property real scale: Math.max(1.0, Math.min(metrics.height / 16, 2.0))

    // The rounded face is carried inside the program and loaded at start; this
    // is the name it registers under. Falling back to the system font is
    // survivable, so nothing here insists on it.
    readonly property string fontFamily: Qt.fontFamilies().indexOf("Nunito") !== -1
        ? "Nunito" : Application.font.family

    readonly property int radiusSmall: Math.round(9 * scale)
    readonly property int radius: Math.round(14 * scale)
    readonly property int radiusLarge: Math.round(20 * scale)
    readonly property int spacing: Math.round(12 * scale)
    readonly property int padding: Math.round(16 * scale)

    readonly property int fontCaption: Math.round(11 * scale)
    readonly property int fontSmall: Math.round(12 * scale)
    readonly property int fontNormal: Math.round(13 * scale)
    readonly property int fontMedium: Math.round(15 * scale)
    readonly property int fontLarge: Math.round(19 * scale)
    readonly property int fontHuge: Math.round(23 * scale)

    readonly property int controlHeight: Math.round(36 * scale)
    readonly property int controlHeightSmall: Math.round(28 * scale)
    readonly property int headerHeight: Math.round(40 * scale)
    readonly property int sidebarWidth: Math.round(212 * scale)
    readonly property int popoverWidth: Math.round(330 * scale)

    // Window metrics. The minimums are the point below which the layout stops
    // being readable, so the window cannot be resized past them.
    //
    // This is the one place where the font scale is held back. Everything else
    // may grow with a larger system font, but a window that grows with it too
    // ends up taller than the screen it has to fit on - and a minimum size
    // larger than the screen cannot be satisfied at all.
    readonly property real windowScale: Math.min(scale, 1.2)
    readonly property int defaultWindowWidth: Math.round(800 * windowScale)
    readonly property int defaultWindowHeight: Math.round(560 * windowScale)
    readonly property int minWindowWidth: Math.round(620 * windowScale)
    readonly property int minWindowHeight: Math.round(440 * windowScale)
    // below this a two-column form is no longer worth having
    readonly property int narrowWidth: Math.round(520 * scale)

    readonly property string monoFamily: {
        const candidates = ["JetBrains Mono", "Cascadia Mono", "Consolas", "DejaVu Sans Mono", "Menlo"];
        const available = Qt.fontFamilies();
        for (const family of candidates) {
            if (available.indexOf(family) !== -1)
                return family;
        }
        return "monospace";
    }

    // keep in sync with VpnController::Status
    readonly property int statusDisconnecting: 0
    readonly property int statusDisconnected: 1
    readonly property int statusConnecting: 2
    readonly property int statusConnected: 3

    function statusColor(status) {
        if (status === statusConnected)
            return ok;
        if (status === statusConnecting)
            return busy;
        if (status === statusDisconnecting)
            return muted;
        return off;
    }

    function statusSoftColor(status) {
        if (status === statusConnected)
            return okSoft;
        if (status === statusConnecting)
            return busySoft;
        return offSoft;
    }

    function statusLabel(status) {
        if (status === statusConnected)
            return qsTr("Connected");
        if (status === statusConnecting)
            return qsTr("Signing in");
        if (status === statusDisconnecting)
            return qsTr("Disconnecting");
        return qsTr("Not connected");
    }

    function statusIsBusy(status) {
        return status === statusConnecting || status === statusDisconnecting;
    }

    // Bytes, as a person would write them.
    function formatBytes(value) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let v = Math.max(0, value);
        let unit = 0;
        while (v >= 1024 && unit < units.length - 1) {
            v /= 1024;
            unit++;
        }
        if (unit === 0)
            return Math.round(v) + " B";
        return (v >= 100 ? v.toFixed(0) : v.toFixed(1)) + " " + units[unit];
    }

    function formatRate(bytesPerSecond) {
        return formatBytes(bytesPerSecond) + "/s";
    }

    // When something last happened, said the way a person would. Seconds since
    // the epoch in, a short phrase out; an empty string when it never happened.
    function formatWhen(epochSeconds) {
        if (!epochSeconds || epochSeconds <= 0)
            return "";

        const then = new Date(epochSeconds * 1000);
        const now = new Date();
        const elapsed = (now.getTime() - then.getTime()) / 1000;

        if (elapsed < 90)
            return qsTr("just now");
        if (elapsed < 3600)
            return qsTr("%1 min ago").arg(Math.round(elapsed / 60));

        const sameDay = then.toDateString() === now.toDateString();
        if (sameDay)
            return qsTr("today at %1").arg(Qt.formatTime(then, Qt.DefaultLocaleShortDate));

        const yesterday = new Date(now.getTime() - 86400000);
        if (then.toDateString() === yesterday.toDateString())
            return qsTr("yesterday at %1").arg(Qt.formatTime(then, Qt.DefaultLocaleShortDate));

        return Qt.formatDateTime(then, Qt.DefaultLocaleShortDate);
    }
}
