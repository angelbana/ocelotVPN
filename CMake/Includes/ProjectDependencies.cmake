# common dependencies
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)

# LinguistTools turns the translation file into the compiled form that ends up
# inside the program; without it there is no Russian.
find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Widgets Network Qml Quick QuickControls2 LinguistTools)
if(MINGW)
    get_target_property(_qwindows_dll Qt6::QWindowsIntegrationPlugin LOCATION)
    if(Qt6Core_VERSION VERSION_GREATER_EQUAL "6.7")
        get_target_property(_qwinstyle_dylib Qt6::QModernWindowsStylePlugin LOCATION)
    elseif(Qt6Core_VERSION VERSION_GREATER_EQUAL "6.0")
        get_target_property(_qwinstyle_dylib Qt6::QWindowsVistaStylePlugin LOCATION)
    endif()

    get_target_property(_schannel_dll Qt6::QSchannelBackendPlugin LOCATION)
endif()

# On Linux, or when cross-building for Windows, we have sane package
# management. Use it.
if(CMAKE_CROSSCOMPILING OR NOT WIN32)
    find_package(GnuTLS REQUIRED)
    if(GNUTLS_FOUND)
        message(STATUS "Library 'GnuTLS' found at ${GNUTLS_LIBRARIES}")
    include_directories(SYSTEM ${GNUTLS_INCLUDE_DIR})
    else()
        message(FATAL_ERROR "Library 'GnuTLS' not found! Install it with e.g. 'brew install gnutls' or 'dnf install gnutls-devel'")
    endif()

    find_package(OpenConnect REQUIRED)
    if(OPENCONNECT_FOUND)
        message(STATUS "Library 'OpenConnect' found at ${OPENCONNECT_LIBRARIES}")
        link_directories(${OPENCONNECT_LIBRARY_DIRS})
        include_directories(SYSTEM ${OPENCONNECT_INCLUDE_DIRS})
    else()
        message(FATAL_ERROR "Library 'OpenConnect' not found! Install it with e.g. 'brew install openconnect or 'dnf install openconnect'")
    endif()

    # This is optional as the package isn't ubiquitous. We'll pull it
    # in and build it locally if not found.
    find_package(spdlog CONFIG)
endif()

if(UNIX)
    set(CMAKE_THREAD_PREFER_PTHREAD ON)
    find_package(Threads REQUIRED)
endif()

# mingw32/mingw64 and other external dependencies
include(ProjectExternals)
