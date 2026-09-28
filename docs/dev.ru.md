### Сборка из исходников

[![EN](https://img.shields.io/badge/lang-EN-6c757d?style=flat-square)](dev.md)
[![RU](https://img.shields.io/badge/lang-RU-0b5fff?style=flat-square)](dev.ru.md)

Ocelot собирается для Windows и для Linux. Каждая команда здесь — та же, что
выполняет рабочий процесс выпуска, поэтому написанное проверено прогонами;
целиком он лежит в
[.github/workflows/release.yml](../.github/workflows/release.yml). Сборка на
своей машине — ещё и способ получить программу, когда серверы сборки
недоступны.

Клиент под macOS — отдельный проект, и к нему здесь ничего не относится.


## Windows

В MSYS2, в оболочке MINGW64. Зависимости собираются из исходников, поэтому
первый раз идёт долго:

    pacman -S --needed git patch make unzip zip \
        mingw-w64-x86_64-toolchain mingw-w64-x86_64-cmake \
        mingw-w64-x86_64-pkgconf mingw-w64-x86_64-qt6-base \
        mingw-w64-x86_64-qt6-declarative mingw-w64-x86_64-qt6-tools \
        mingw-w64-x86_64-nsis

    ./contrib/build_deps_mingw@msys2.sh
    cmake -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -S . -B build
    cmake --build build -j$(nproc)

Программа окажется в `build/bin`, но для запуска ей нужны библиотеки Qt рядом:
прямо оттуда она не стартует и жалуется на отсутствующую `Qt6Network.dll`.
Сначала разложите её — вместе с программой скопируется и среда выполнения:

    cmake --install build --prefix "$(pwd)/build/app"

Чтобы собрать установщик:

    cd build && cpack

Версия в имени файла берётся из `git describe`, поэтому дерево с
незафиксированными изменениями даёт имя с пометкой `dirty`.


## Linux

Нужна Qt 6.5 или новее — программа использует
`Application.styleHints.colorScheme`, появившийся там. На Fedora 41, где
собирает рабочий процесс:

    dnf install gcc-c++ cmake git patch pkgconf-pkg-config \
        qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qttools-devel \
        openconnect-devel gnutls-devel libxml2-devel

    cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
    cmake --build build -j$(nproc)

`spdlog-devel` ставить **не нужно**: с ним программа связывается с системной
spdlog и потом отказывается запускаться там, где этой библиотеки нет. Без него
сборка включает собственную копию внутрь.

Для запуска нужны права суперпользователя (ради устройства tun) и
`/etc/vpnc/vpnc-script` из пакета `vpnc-scripts`:

    sudo ./build/bin/ocelot

Образ приложения собирается поверх этого через `linuxdeploy` — как именно,
видно в задаче Linux рабочего процесса.


## Перевод на русский

Интерфейс пишется по-английски, перевод лежит в `src/i18n/ocelot_ru.ts`.
Собранная форма попадает внутрь программы, поэтому рядом с ней ничего ставить
не нужно, а язык переключается на ходу.

После того как добавили или изменили текст, который видит человек, соберите
новые строки:

    cmake --build build --target update_translations

Файл `.ts` перепишется, всё новое будет помечено как незавершённое. Заполните
эти строки — подойдёт Qt Linguist или любой редактор — и соберите снова:
скомпилированный перевод получается в ходе сборки.
