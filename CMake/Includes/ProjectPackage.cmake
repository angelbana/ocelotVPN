#include(InstallRequiredSystemLibraries)

# common CPacke variables
set(CPACK_PACKAGE_NAME ${PROJECT_NAME})
set(CPACK_PACKAGE_VENDOR ${PRODUCT_NAME_COMPANY})
set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})
#set(CPACK_PACKAGE_DESCRIPTION_FILE ${CMAKE_SOURCE_DIR}/README)
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY ${PRODUCT_NAME_LONG})
#set(CPACK_PACKAGE_FILE_NAME ${CPACK_PACKAGE_NAME}-${CPACK_PACKAGE_VERSION}-${CPACK_SYSTEM_NAME})
set(CPACK_PACKAGE_INSTALL_DIRECTORY "${PRODUCT_NAME_SHORT}")
set(CPACK_PACKAGE_CHECKSUM SHA512)
set(CPACK_RESOURCE_FILE_LICENSE ${CMAKE_CURRENT_SOURCE_DIR}/LICENSE.txt)
#set(CPACK_RESOURCE_FILE_README ...)
#set(CPACK_RESOURCE_FILE_WELCOME ...)
if(WIN32 AND MINGW)
    if(CMAKE_CROSSCOMPILING AND MINGW)
        set(CPACK_GENERATOR "ZIP")
    else()
        set(CPACK_GENERATOR "NSIS")
    endif()

    set(CPACK_NSIS_INSTALLED_ICON_NAME "${PROJECT_NAME}.exe")
    set(CPACK_NSIS_DISPLAY_NAME "${CPACK_PACKAGE_INSTALL_DIRECTORY}")
    set(CPACK_NSIS_HELP_LINK "${APP_ISSUES_URL}")
    set(CPACK_NSIS_URL_INFO_ABOUT "${CMAKE_PROJECT_HOMEPAGE_URL}")
    set(CPACK_NSIS_COMPRESSOR "/SOLID lzma")
    set(CPACK_NSIS_MODIFY_PATH ON)
    set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL OFF)

    set(CPACK_NSIS_MUI_ICON "${CMAKE_CURRENT_SOURCE_DIR}\\\\src\\\\${PROJECT_NAME}.ico")
    set(CPACK_NSIS_MUI_UNIICON "${CMAKE_CURRENT_SOURCE_DIR}\\\\src\\\\${PROJECT_NAME}.ico")

    set(CPACK_PACKAGE_ICON ${CMAKE_CURRENT_SOURCE_DIR}\\\\nsis\\\\images\\\\header-openconnect.bmp)
    set(CPACK_NSIS_MUI_WELCOMEFINISHPAGE_BITMAP ${CMAKE_CURRENT_SOURCE_DIR}\\\\nsis\\\\images\\\\install-openconnect.bmp)
    set(CPACK_NSIS_MUI_UNWELCOMEFINISHPAGE_BITMAP ${CMAKE_CURRENT_SOURCE_DIR}\\\\nsis\\\\images\\\\install-openconnect.bmp)

    set(CPACK_NSIS_EXECUTABLES_DIRECTORY ".")
    set(CPACK_NSIS_MUI_FINISHPAGE_RUN "${PROJECT_NAME}.exe")

    set(CPACK_NSIS_MENU_LINKS
        "${CMAKE_PROJECT_HOMEPAGE_URL}" "Homepage"
        "${APP_ISSUES_URL}" "Issues"
    )

    # NSIS'es list of all components
    set(CPACK_COMPONENTS_ALL App App_Console vpnc_script)

    set(CPACK_COMPONENT_APP_REQUIRED on)
    set(CPACK_COMPONENT_APP_DISPLAY_NAME "${APP_NAME}")
    set(CPACK_COMPONENT_APP_DESCRIPTION "${PRODUCT_NAME_LONG}")
    set(CPACK_COMPONENT_APP_GROUP "Application")
    set(CPACK_COMPONENT_APP_INSTALL_TYPES Full AppOnly Standard)

    set(CPACK_COMPONENT_VPNC_SCRIPT_REQUIRED on)
    set(CPACK_COMPONENT_VPNC_SCRIPT_DISPLAY_NAME "vpnc-script.js")
    set(CPACK_COMPONENT_VPNC_SCRIPT_DESCRIPTION "Helper script to set the routing and name service up")
    set(CPACK_COMPONENT_VPNC_SCRIPT_GROUP "Application")
    set(CPACK_COMPONENT_VPNC_SCRIPT_INSTALL_TYPES Full AppOnly Standard)

    set(CPACK_COMPONENT_APP_CONSOLE_DISABLED on)
    set(CPACK_COMPONENT_APP_CONSOLE_REQUIRED off)
    set(CPACK_COMPONENT_APP_CONSOLE_DISPLAY_NAME "console")
    set(CPACK_COMPONENT_APP_CONSOLE_DESCRIPTION "Console version of OpenConnect VPN")
    set(CPACK_COMPONENT_APP_CONSOLE_GROUP "Application")
    set(CPACK_COMPONENT_APP_CONSOLE_INSTALL_TYPES Full)

    # NSIS'es Runtime-group
    set(CPACK_COMPONENT_GROUP_APPLICATION_DESCRIPTION "Main application and network configuration script")
    set(CPACK_COMPONENT_GROUP_APPLICATION_EXPANDED on)

    # NSIS'es install types lists
    set(CPACK_ALL_INSTALL_TYPES Full)
    set(CPACK_INSTALL_TYPE_FULL_DISPLAY_NAME "Full installation")
    set(CPACK_INSTALL_TYPE_APPONLY_DISPLAY_NAME "Application only")
    set(CPACK_INSTALL_TYPE_STANDARD_DISPLAY_NAME "Standard installation")

    # source code packaging
    #set(CPACK_SOURCE_PACKAGE_FILE_NAME )
    set(CPACK_SOURCE_GENERATOR "7Z")
    set(CPACK_SOURCE_IGNORE_FILES "build-release/;/\.git/;\.swp$;\.gitignore$")
else()
    # Linux has no CPack generator of its own here: the app image is assembled
    # by linuxdeploy from the installed tree, not by CPack.
endif()
set(CPACK_PACKAGE_EXECUTABLES "${PROJECT_NAME}" "${PRODUCT_NAME_LONG}")
set(CPACK_CREATE_DESKTOP_LINKS  "${PROJECT_NAME}")

# custom variables to pass to cpack
# Homebrew builds for one processor at a time, and the openconnect and GnuTLS
# it provides cannot be made universal, so each processor gets its own disk
# image and the name has to say which one it is for.
set(CPACK_OCG_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
set(CPACK_OCG_OPENCONNECT_FOUND "${OPENCONNECT_FOUND}")
set(CPACK_OCG_OPENCONNECT_VERSION "${OPENCONNECT_VERSION}")
set(CPACK_OCG_openconnect-TAG "${openconnect-TAG}")
set(CPACK_OCG_SOURCE_DIR "${CMAKE_SOURCE_DIR}")
set(CPACK_OCG_BINARY_DIR "${CMAKE_BINARY_DIR}")

# project settings for cpack
set(CPACK_PROJECT_CONFIG_FILE "${CMAKE_SOURCE_DIR}/CMake/Includes/ProjectPackageConfig.cmake")

include(CPack)
