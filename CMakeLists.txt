cmake_minimum_required(VERSION 3.19 FATAL_ERROR)

project(ocelot
    VERSION 1.1.1
    HOMEPAGE_URL https://github.com/angelbana/ocelotVPN
    LANGUAGES CXX
)

message(STATUS "Building ${PROJECT_NAME} v${PROJECT_VERSION} [cmake]")

# The SHORT and COMPANY names affect the installation directory.
set(PRODUCT_NAME_SHORT "Ocelot")
set(PRODUCT_NAME_COMPANY "SculkDev")
set(PRODUCT_NAME_COMPANY_DOMAIN "sculk.ltd")
set(INTERNAL_PROJECT_VERSION "${PROJECT_VERSION}")

# The long name is used as the installer description
# and About screen description.
set(PRODUCT_NAME_LONG "Ocelot, a VPN client")

# Printed in the About screen
set(PRODUCT_NAME_COPYRIGHT_SHORT "Copyright © 2016-2024 Red Hat Inc., Nikos Mavrogiannopoulos, Ľubomír Carik and others")
set(PRODUCT_NAME_COPYRIGHT_FULL "Copyright © 2014-2015 Red Hat Inc.<br>Copyright © 2016-2024 Nikos Mavrogiannopoulos<br>Copyright © 2016-2024 Ľubomír Carik<br>Copyright © 2020-2024 David Woodhouse<br>Copyright © 2021-2024 Dimitri Papadopoulos Orfanos<br>Copyright © 2023-2024 Marios Paouris")

# The application name / main window title / installer app name
set(APP_NAME "Ocelot")

# Everything that points at the project itself is derived from one address,
# because the repository is the part of this most likely to move.
set(APP_REPO_URL "https://github.com/angelbana/ocelotVPN")
set(APP_RELEASES_URL "${APP_REPO_URL}/releases")
set(APP_ISSUES_URL "${APP_REPO_URL}/issues")
# Asking for the latest release answers with a redirect to the tag it points
# at, and the version is read out of that address; no API token is involved.
set(APP_LATEST_RELEASE_URL "${APP_REPO_URL}/releases/latest")

# The Mac client is a separate program in a repository of its own, and the
# About screen sends anyone who needs it there.
set(APP_MACOS_URL "https://github.com/mraliscoder/ocelotVPN")

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/CMake/Modules/")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/CMake/Includes/")

set(SIGN_EXE "false" CACHE STRING "When set to true the executable will be signed")

include(ProjectSettings)
include(ProjectDependencies)

if(MINGW)
    # FIXME: upgrading CMake from 3.15 to newer version fails on packaging
    # because objdump.exe is not supported (actually the exe suffix break it)
    # TODO: bundling dependencies use CMake deprecated function; need update..
    find_program(CMAKE_OBJDUMP NAMES objdump.exe)
    string(REGEX REPLACE "\\.exe$" "" CMAKE_OBJDUMP ${CMAKE_OBJDUMP})

endif()

add_subdirectory(src)

# Beside the program on Windows; on Linux the licence belongs under share/doc,
# so it does not end up in the root of an app image.
if(UNIX)
    set(_licence_dest "share/doc/${PROJECT_NAME}")
else()
    set(_licence_dest ".")
endif()

install(FILES LICENSE.txt
    DESTINATION ${_licence_dest}
    COMPONENT App
)

include(clang-format)
include(git_revision_main)
include(build_timestamp_main)

include(ProjectPackage)

