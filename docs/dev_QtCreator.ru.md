### Разработка в QtCreator

[![EN](https://img.shields.io/badge/lang-EN-6c757d?style=flat-square)](dev_QtCreator.md)
[![RU](https://img.shields.io/badge/lang-RU-0b5fff?style=flat-square)](dev_QtCreator.ru.md)

- запустите QtCreator;
- создайте или выберите сеанс, если это уместно;
- откройте `CMakeLists.txt` из корня проекта;
- выберите нужные типы сборки для установленной Qt и нажмите «Configure»;
- откройте вкладку «Project» слева, где настройки CMake;
- измените
    - `PROJ_ADMIN_PRIV_ELEVATION` на `off`, потому что QtCreator не умеет
      запускать приложение с запросом прав администратора;
- нажмите «Apply Configuration Changes» и вернитесь на вкладку «Edit» слева;
- соберите проект.

При желании задайте `MAKEFLAGS` в настройках проекта — сборка пойдёт быстрее.
