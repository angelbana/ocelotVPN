### Building from source

[![EN](https://img.shields.io/badge/lang-EN-0b5fff?style=flat-square)](dev.md)
[![RU](https://img.shields.io/badge/lang-RU-6c757d?style=flat-square)](dev.ru.md)

Ocelot is built for Windows and for Linux. Every command here is one the
release workflow runs, so what is written is what is known to work; see
[.github/workflows/release.yml](../.github/workflows/release.yml) for the
whole of it. Building locally is also the way to get a program when the
runners are not available.

The macOS client is a separate project, and nothing here applies to it.


## Windows

Under MSYS2, in the MINGW64 shell. The dependencies are built from source, so
the first run takes a while:

    pacman -S --needed git patch make unzip zip \
        mingw-w64-x86_64-toolchain mingw-w64-x86_64-cmake \
        mingw-w64-x86_64-pkgconf mingw-w64-x86_64-qt6-base \
        mingw-w64-x86_64-qt6-declarative mingw-w64-x86_64-qt6-tools \
        mingw-w64-x86_64-nsis

    ./contrib/build_deps_mingw@msys2.sh
    cmake -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -S . -B build
    cmake --build build -j$(nproc)

The program is then in `build/bin`, and it needs the Qt libraries beside it to
start - running it straight from there fails with a missing `Qt6Network.dll`.
Install it somewhere first, which copies the runtime along with it:

    cmake --install build --prefix "$(pwd)/build/app"

To build the installer instead:

    cd build && cpack

The version in the file name comes from `git describe`, so a tree with
uncommitted changes produces one marked `dirty`.


## Linux

Qt 6.5 or newer is needed - the program uses
`Application.styleHints.colorScheme`, which arrived there. On Fedora 41, which
is what the workflow builds on:

    dnf install gcc-c++ cmake git patch pkgconf-pkg-config \
        qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qttools-devel \
        openconnect-devel gnutls-devel libxml2-devel

    cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
    cmake --build build -j$(nproc)

Do not install `spdlog-devel`: with it the program links against the system
spdlog and then refuses to start anywhere that library is missing. Without it
the build compiles its own copy in.

Running needs root, for the tun device, and `/etc/vpnc/vpnc-script`, which
comes with the `vpnc-scripts` package:

    sudo ./build/bin/ocelot

Building the app image on top of that is what the workflow's Linux job does,
with `linuxdeploy`; the steps are there if you need one locally.


## The Russian translation

The interface is written in English and translated in `src/i18n/ocelot_ru.ts`.
The compiled form is built into the program, so nothing has to be installed
beside it and the language can be changed while it runs.

After adding or changing any text shown to a person, collect the new strings:

    cmake --build build --target update_translations

That rewrites the `.ts` file with whatever is new, marked as unfinished. Fill
those in - Qt Linguist opens the file, or any editor will do - and build again;
the compiled translation is produced as part of the build.
