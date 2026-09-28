set(CMAKE_VERBOSE_MAKEFILE ON)

set_property(SOURCE ${PROJECT_NAME}.cpp PROPERTY SKIP_AUTOGEN ON)
set_property(SOURCE timestamp.cpp PROPERTY SKIP_AUTOGEN ON)

set(${PROJECT_NAME}_SRCS
    ocelot.qrc
    Autostart.cpp
    Autostart.h
    cert.cpp
    common.h
    config.h.in
    cryptdata.cpp
    gtdb.cpp
    key.cpp
    keypair.cpp
    main.cpp
    server_storage.cpp

    timestamp.cpp

    vpninfo.cpp

    logger.cpp
    LogModel.cpp
    VpnController.cpp

    FileLogger.cpp
    OcSettings.h
)

set(${PROJECT_NAME}_QML
    qml/AboutPane.qml
    qml/AppButton.qml
    qml/AppComboBox.qml
    qml/AppDialog.qml
    qml/AppField.qml
    qml/AppToggle.qml
    qml/Card.qml
    qml/ChunkyButton.qml
    qml/ConnectionPane.qml
    qml/DetailRow.qml
    qml/GhostButton.qml
    qml/Glyph.qml
    qml/LogPane.qml
    qml/Main.qml
    qml/Mascot.qml
    qml/NewProfileSheet.qml
    qml/Pill.qml
    qml/ProfileEditor.qml
    qml/ProfileRow.qml
    qml/PromptSheet.qml
    qml/PulseDot.qml
    qml/SectionLabel.qml
    qml/SettingsPane.qml
    qml/StatTile.qml
    qml/Telemetry.qml
    qml/Theme.qml
    qml/ThroughputChart.qml
    qml/TrayPopover.qml
)

# Both are single objects the whole interface reads: the palette, and the
# recent throughput the charts draw.
set_source_files_properties(qml/Theme.qml qml/Telemetry.qml
    PROPERTIES
        QT_QML_SINGLETON_TYPE true
)

# The QML files live in a sub-directory, but they have to end up in the root of
# the module; otherwise the implicit directory import shadows the qmldir entries
# (and with them the Theme singleton).
foreach(qmlFile ${${PROJECT_NAME}_QML})
    get_filename_component(qmlFileName ${qmlFile} NAME)
    set_source_files_properties(${qmlFile}
        PROPERTIES
            QT_RESOURCE_ALIAS ${qmlFileName}
    )
endforeach()

set_source_files_properties(
    ${PROJECT_NAME}.cpp
    timestamp.cpp
    PROPERTIES
        GENERATED true
)

configure_file(
    config.h.in
    config.h
    @ONLY
)

if(MINGW)
    list(APPEND ${PROJECT_NAME}_RESOURCES
        ${PROJECT_NAME}.rc.in
        ${PROJECT_NAME}.rc
    )

    set_source_files_properties(
       ${PROJECT_NAME}.rc
        PROPERTIES
            GENERATED true
            # the resource compiler embeds the icon and the manifest Qt writes
            # next to the configured .rc; without these dependencies the
            # executable keeps the old ones when only those files change
            OBJECT_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/${PROJECT_NAME}.ico;${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.exe.manifest"
    )
endif()

qt_add_executable(${PROJECT_NAME}
    ${${PROJECT_NAME}_SRCS}
    ${${PROJECT_NAME}_RESOURCES}
)

qt_add_qml_module(${PROJECT_NAME}
    URI Ocelot
    VERSION 1.0
    RESOURCE_PREFIX "/qt/qml"
    QML_FILES ${${PROJECT_NAME}_QML}
)

# The interface is written in English and translated into Russian; the compiled
# translation is built from the file below and embedded, so switching language
# needs nothing on disk.
qt_add_translations(${PROJECT_NAME}
    TS_FILES ${CMAKE_CURRENT_SOURCE_DIR}/i18n/ocelot_ru.ts
    RESOURCE_PREFIX "/i18n"
)

if(MINGW)
    add_definitions(-DSPDLOG_WCHAR_FILENAMES)

    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_BINARY_DIR}/external/vpnc-script.js $<TARGET_FILE_DIR:${PROJECT_NAME}>
        COMMENT "Deploying vpnc-script..."
        VERBATIM
    )

    add_dependencies(${PROJECT_NAME}
        vpnc-scripts-${vpnc-scripts-TAG}
    )

    set_target_properties(${PROJECT_NAME} PROPERTIES
        WIN32_EXECUTABLE true
    )

    # Qt writes its own <target>.exe.manifest into the build directory, and the
    # resource compiler resolves the file named in the .rc next to that copy,
    # so it is embedded instead of the manifest kept with the sources; the
    # elevation needed to create the tun device has to be set on the target.
    if(PROJ_ADMIN_PRIV_ELEVATION)
        set_target_properties(${PROJECT_NAME} PROPERTIES
            QT_WINDOWS_APP_PROJECT_EXECUTION_LEVEL "requireAdministrator"
        )
    endif()

    target_link_libraries (${PROJECT_NAME} PRIVATE
        # system libraries
        wsock32
    )
endif()

#code signing
if(SIGN_EXE STREQUAL "true")
    add_custom_command(
        TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND sh -c "${CMAKE_SOURCE_DIR}/contrib/sign.sh \"$<TARGET_FILE:${PROJECT_NAME}>\""
        COMMENT "Signing executable ..."
        VERBATIM
    )
endif()

if(WIN32 AND NOT CMAKE_CROSSCOMPILING)
    add_dependencies(${PROJECT_NAME}
        openconnect-devel-${openconnect-TAG}
        openconnect-${openconnect-TAG}
    )

    target_link_libraries (${PROJECT_NAME} PRIVATE
        # 3rd party dependencies
        openconnect::gmp
        openconnect::gnutls
        openconnect::hogweed
        openconnect::nettle
        openconnect::openconnect
        openconnect::p11-kit
        openconnect::stoken
        openconnect::xml2
    )
else()
    target_link_libraries (${PROJECT_NAME} PRIVATE
        ${OPENCONNECT_LIBRARIES}
        ${GNUTLS_LIBRARY}
    )
endif()

# QtSingleApplication comes from an external project, and linking against the
# imported library does not order the build: its headers can still be missing
# when this target is compiled, which a parallel build turns into a failure.
add_dependencies(${PROJECT_NAME}
    qt-solutions-${qt-solutions-TAG}
)

# common stuff to link...
target_link_libraries (${PROJECT_NAME} PRIVATE
    spdlog::spdlog
    qt-solutions::qtsingleapplication

    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Network
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
)

if(UNIX)
    target_link_libraries(${PROJECT_NAME} PRIVATE
        Threads::Threads
    )
endif()

# install executable
# Windows keeps everything beside the executable, so it installs into the root
# of the prefix. Linux expects the usual directories instead, and an app image
# is built from exactly that layout.
if(UNIX)
    set(_runtime_dest "bin")
else()
    set(_runtime_dest ".")
endif()

install(TARGETS ${PROJECT_NAME}
    RUNTIME DESTINATION ${_runtime_dest} COMPONENT App
    LIBRARY DESTINATION ${_runtime_dest} COMPONENT App
)

# fixup the bundle
get_target_property(QT_LIBRARY_DIR Qt6::Core LOCATION)
get_filename_component(QT_LIBRARY_DIR ${QT_LIBRARY_DIR} PATH)
list(APPEND libSearchDirs ${QT_LIBRARY_DIR})

if(MINGW)
    set(APPS "\${CMAKE_INSTALL_PREFIX}/${PROJECT_NAME}.exe")
    list(APPEND libSearchDirs ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})

    # Qt Platform Plugin
    install(FILES
        ${_qwindows_dll}
        DESTINATION plugins/platforms
        COMPONENT App
    )
    # Qt schannel plugin
    install(FILES
        ${_schannel_dll}
        DESTINATION plugins/tls
        COMPONENT App
    )
    install(FILES
        ${CMAKE_SOURCE_DIR}/nsis/qt.conf
        DESTINATION .
        COMPONENT App
    )

    set(additionalLib ${_qwindows_dll})
    if(Qt6Core_VERSION VERSION_GREATER_EQUAL "6.0")
        install(FILES
            ${_qwinstyle_dylib}
            DESTINATION plugins/styles
            COMPONENT App
        )
    endif()
else()
    # A desktop entry, an icon and the metadata that describes the program are
    # what a Linux desktop needs to show it in a menu at all; an AppImage is
    # then assembled from the installed tree, so these have to be installed
    # rather than built beside the executable.
    configure_file(
        ${CMAKE_SOURCE_DIR}/contrib/linux/ocelot.desktop.in
        ${CMAKE_CURRENT_BINARY_DIR}/ocelot.desktop
        @ONLY
    )
    configure_file(
        ${CMAKE_SOURCE_DIR}/contrib/linux/ocelot.metainfo.xml.in
        ${CMAKE_CURRENT_BINARY_DIR}/${PRODUCT_NAME_COMPANY_DOMAIN}.ocelot.metainfo.xml
        @ONLY
    )

    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/ocelot.desktop
        DESTINATION share/applications
        COMPONENT App
    )
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${PRODUCT_NAME_COMPANY_DOMAIN}.ocelot.metainfo.xml
        DESTINATION share/metainfo
        COMPONENT App
    )
    # The name has to match the Icon= line of the desktop entry, not the file
    # it is copied from.
    install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/Resources/mono_lock.png
        DESTINATION share/icons/hicolor/256x256/apps
        RENAME ocelot.png
        COMPONENT App
    )

    # fixup_bundle below is for the platforms that carry their dependencies;
    # on Linux the libraries come from the distribution, and what the AppImage
    # needs beyond them is gathered when it is built.
    set(APPS "")
endif()

if(MINGW)
    #wintun
    install(FILES
        ${CMAKE_BINARY_DIR}/bin/wintun.dll
        DESTINATION .
        COMPONENT App
    )
endif()

if(APPS)
    install(CODE "
        include(BundleUtilities)
        fixup_bundle(\"${APPS}\" \"${additionalLib}\" \"${libSearchDirs}\")
        " DESTINATION . COMPONENT App
    )
endif()

# Qt's own QML modules, and the plugins they load, are deployed into the
# directories qt.conf points at. The generated deployment script cannot be used
# as it is: it includes QtDeploySupport.cmake, which sets Qt's own layout
# (bin, share/qt6), and the QML plugins then no longer find their libraries.
# The directories are therefore overridden after that file is included.
if(MINGW)
    install(CODE "
        include(\"${QT_DEPLOY_SUPPORT}\")
        set(QT_DEPLOY_BIN_DIR \".\")
        set(QT_DEPLOY_LIB_DIR \".\")
        set(QT_DEPLOY_PLUGINS_DIR \"plugins\")
        set(QT_DEPLOY_QML_DIR \"qml\")
        qt6_deploy_qml_imports(TARGET ${PROJECT_NAME} PLUGINS_FOUND qml_plugins)
        qt6_deploy_runtime_dependencies(
            EXECUTABLE \"\${QT_DEPLOY_PREFIX}/${PROJECT_NAME}.exe\"
            ADDITIONAL_MODULES \${qml_plugins}
            NO_TRANSLATIONS
        )
    " COMPONENT App)
endif()
