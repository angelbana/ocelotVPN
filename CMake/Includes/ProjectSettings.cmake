option(PROJ_GNUTLS_DEBUG "Enable GnuTLS debug mode" OFF)

option(PROJ_ADMIN_PRIV_ELEVATION "Admin privileges elevation; don't turn it off in production!! (UAC on Windows) " ON)

# A relative path is resolved next to the program, an absolute one is used as
# it is. The fallback is tried when the relative one is not there, which is how
# a build that ships no script of its own keeps working.
if(MINGW)
    set(DEFAULT_VPNC_SCRIPT "vpnc-script.js")
else()
    set(DEFAULT_VPNC_SCRIPT "vpnc-script")
    set(DEFAULT_VPNC_SCRIPT_FALLBACK "/etc/vpnc/vpnc-script")
endif()
option(PROJ_PKCS11 "Enable PKCS11" ON)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_compile_options(-pipe -Wall -Wextra -Wpedantic -Wno-unused-parameter)
#add_compile_options(-Weffc++)
if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    add_compile_options(-Werror)
endif()

set(CMAKE_INCLUDE_CURRENT_DIR ON)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
