### Development with QtCreator

[![EN](https://img.shields.io/badge/lang-EN-0b5fff?style=flat-square)](dev_QtCreator.md)
[![RU](https://img.shields.io/badge/lang-RU-6c757d?style=flat-square)](dev_QtCreator.ru.md)

- start QtCreator
- create/select a session if make sense
- open CMakeLists.txt from project root
- update desired Qt 5.12 version build types and click "Configure"
- open 'Project' tab on left side of QtCreator with CMake configuration
- change
    - 'PROJ\_ADMIN\_PRIV\_ELEVATION' to 'off' because QtCreator is not able to start app with UAC (?) :/
- click 'Apply Configuration Changes' and then switch again to 'Edit' tab on left side of QtCreator
- build the project

Optionally setup MAKEFLAGS in Projects settings if you like for faster build.

