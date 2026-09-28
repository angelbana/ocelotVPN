if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(MINGW_VARIANT mingw64)
else()
    set(MINGW_VARIANT mingw32)
endif()

# --------------------------------------------------------------------------------------------------
# openconnect (libs, headers, etc.)
# --------------------------------------------------------------------------------------------------
if(NOT EXISTS ${CMAKE_SOURCE_DIR}/external/openconnect-devel-${openconnect-TAG}_${MINGW_VARIANT}.zip)
    message(FATAL_ERROR "external/openconnect-devel-${openconnect-TAG}_${MINGW_VARIANT}.zip was not found")
else()
    message(STATUS "Using local openconnect-devel packages... (${MINGW_VARIANT})")
    set(OPENCONNECT_DEV_URL ${CMAKE_SOURCE_DIR}/external)

    #get the hash for local zip
    file(STRINGS ${OPENCONNECT_DEV_URL}/openconnect-devel-${openconnect-TAG}_${MINGW_VARIANT}.zip.sha512 TESTURLHASH)
    string(REPLACE " " ";" TESTURLHASH ${TESTURLHASH} )
    list(GET TESTURLHASH 0 OPENCONNECT_DEV_URL_HASH)
    set(OPENCONNECT_DEV_URL_HASH "SHA512=${OPENCONNECT_DEV_URL_HASH}")
endif()

ExternalProject_Add(openconnect-devel-${openconnect-TAG}
    PREFIX ${CMAKE_BINARY_DIR}/external
    INSTALL_DIR ${CMAKE_BINARY_DIR}/external
    
    DOWNLOAD_NO_PROGRESS 1
    
    URL ${OPENCONNECT_DEV_URL}/openconnect-devel-${openconnect-TAG}_${MINGW_VARIANT}.zip
    URL_HASH ${OPENCONNECT_DEV_URL_HASH}

    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ""
)
ExternalProject_Add_Step(openconnect-devel-${openconnect-TAG} deploy_headers
    COMMAND ${CMAKE_COMMAND} -E copy_directory include <INSTALL_DIR>/include
    COMMENT "...deploying openconnect-${openconnect-TAG} headers"
    WORKING_DIRECTORY <SOURCE_DIR>
    DEPENDEES install
)
ExternalProject_Add_Step(openconnect-devel-${openconnect-TAG} deploy_libraries
    COMMAND ${CMAKE_COMMAND} -E copy_directory lib <INSTALL_DIR>/lib
    COMMENT "...deploying openconnect-${openconnect-TAG} libraries"
    WORKING_DIRECTORY <SOURCE_DIR>
    DEPENDEES install
    ALWAYS 0
)

# --------------------------------------------------------------------------------------------------
# openconnect (util & libs)
# --------------------------------------------------------------------------------------------------
if(NOT EXISTS ${CMAKE_SOURCE_DIR}/external/openconnect-${openconnect-TAG}_${MINGW_VARIANT}.zip)
    message(FATAL_ERROR "external/openconnect-${openconnect-TAG}_${MINGW_VARIANT}.zip was not found")
else()
    message(STATUS "Using local openconnect packages... ${MINGW_VARIANT}")
    set(OPENCONNECT_URL ${CMAKE_SOURCE_DIR}/external)

    #get the hash for local zip
    file(STRINGS ${OPENCONNECT_URL}/openconnect-${openconnect-TAG}_${MINGW_VARIANT}.zip.sha512 TESTURLHASH)
    string(REPLACE " " ";" TESTURLHASH ${TESTURLHASH} )
    list(GET TESTURLHASH 0 OPENCONNECT_URL_HASH)
    set(OPENCONNECT_URL_HASH "SHA512=${OPENCONNECT_URL_HASH}")
endif()

ExternalProject_Add(openconnect-${openconnect-TAG}
    PREFIX ${CMAKE_BINARY_DIR}/external
    INSTALL_DIR ${CMAKE_BINARY_DIR}/bin
    
    DOWNLOAD_NO_PROGRESS 1

    URL ${OPENCONNECT_URL}/openconnect-${openconnect-TAG}_${MINGW_VARIANT}.zip
    URL_HASH ${OPENCONNECT_URL_HASH}

    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ""
)
ExternalProject_Add_Step(openconnect-${openconnect-TAG} deploy_libs
    COMMAND ${CMAKE_COMMAND} -E copy_directory . <INSTALL_DIR>
    COMMENT "...deploying openconnect-${openconnect-TAG} libraries"
    WORKING_DIRECTORY <SOURCE_DIR>
    DEPENDEES install
)

add_executable(openconnect::app IMPORTED)
set_property(TARGET openconnect::app PROPERTY IMPORTED_LOCATION ${CMAKE_BINARY_DIR}/bin/openconnect.exe)

add_library(openconnect::gmp SHARED IMPORTED)
set_property(TARGET openconnect::gmp PROPERTY IMPORTED_LOCATION ${CMAKE_BINARY_DIR}/bin/libgmp-10.dll)
set_property(TARGET openconnect::gmp PROPERTY IMPORTED_IMPLIB ${CMAKE_BINARY_DIR}/external/lib/libgmp.dll.a)

add_library(openconnect::gnutls SHARED IMPORTED)
set_property(TARGET openconnect::gnutls PROPERTY IMPORTED_LOCATION ${CMAKE_BINARY_DIR}/bin/libgnutls-30.dll)
set_property(TARGET openconnect::gnutls PROPERTY IMPORTED_IMPLIB ${CMAKE_BINARY_DIR}/external/lib/libgnutls.dll.a)

add_library(openconnect::hogweed SHARED IMPORTED)
set_property(TARGET openconnect::hogweed PROPERTY IMPORTED_LOCATION ${CMAKE_BINARY_DIR}/bin/libhogweed-7.dll)
set_property(TARGET openconnect::hogweed PROPERTY IMPORTED_IMPLIB ${CMAKE_BINARY_DIR}/external/lib/libhogweed.dll.a)

add_library(openconnect::nettle SHARED IMPORTED)
set_property(TARGET openconnect::nettle PROPERTY IMPORTED_LOCATION ${CMAKE_BINARY_DIR}/bin/libnettle-9.dll)
set_property(TARGET openconnect::nettle PROPERTY IMPORTED_IMPLIB ${CMAKE_BINARY_DIR}/external/lib/libnettle.dll.a)

add_library(openconnect::openconnect SHARED IMPORTED)
set_property(TARGET openconnect::openconnect PROPERTY IMPORTED_LOCATION ${CMAKE_BINARY_DIR}/bin/libopenconnect-5.dll)
set_property(TARGET openconnect::openconnect PROPERTY IMPORTED_IMPLIB ${CMAKE_BINARY_DIR}/external/lib/libopenconnect.dll.a)

add_library(openconnect::p11-kit SHARED IMPORTED)
set_property(TARGET openconnect::p11-kit PROPERTY IMPORTED_LOCATION ${CMAKE_BINARY_DIR}/bin/libp11-kit-0.dll)
set_property(TARGET openconnect::p11-kit PROPERTY IMPORTED_IMPLIB ${CMAKE_BINARY_DIR}/external/lib/libp11-kit.dll.a)

add_library(openconnect::stoken SHARED IMPORTED)
set_property(TARGET openconnect::stoken PROPERTY IMPORTED_LOCATION ${CMAKE_BINARY_DIR}/bin/libstoken-1.dll)
set_property(TARGET openconnect::stoken PROPERTY IMPORTED_IMPLIB ${CMAKE_BINARY_DIR}/external/lib/libstoken.dll.a)

add_library(openconnect::xml2 SHARED IMPORTED)
set_property(TARGET openconnect::xml2 PROPERTY IMPORTED_LOCATION ${CMAKE_BINARY_DIR}/bin/libxml2-16.dll)
set_property(TARGET openconnect::xml2 PROPERTY IMPORTED_IMPLIB ${CMAKE_BINARY_DIR}/external/lib/libxml2.dll.a)

add_library(openconnect::wintun SHARED IMPORTED)
set_property(TARGET openconnect::wintun PROPERTY IMPORTED_LOCATION ${CMAKE_BINARY_DIR}/bin/wintun.dll)

# Only the program: the script that comes with it is a second, unpinned copy of
# the one installed as the vpnc_script component, and having two of them in the
# installation root means a change has to be made twice. The console program can
# be pointed at the installed vpnc-script.js with --script.
install(
    FILES
        ${CMAKE_BINARY_DIR}/bin/openconnect.exe
    DESTINATION .
    COMPONENT App_Console
)
