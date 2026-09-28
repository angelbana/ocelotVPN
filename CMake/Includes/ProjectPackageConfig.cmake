# CPack Project Config file
# This file is included once per CPack Generator run

if(CPACK_GENERATOR STREQUAL "NSIS")

    # When building NSIS installers, supply project and openconnect's version in the resulting installer filename
    # The resulting installer file name will be of the form
    # ocelot-<OCG version>-oc-<OC version>-<platform>.exe

    if(CPACK_OCG_OPENCONNECT_FOUND)
        set(OC_VERSION "${CPACK_OCG_OPENCONNECT_VERSION}")
	#message(STATUS "Working in found openconnect mode. ${OC_VERSION}")
    else()
        if (NOT EXISTS "${CPACK_OCG_BINARY_DIR}/external/lib/pkgconfig/openconnect.pc")
            message(FATAL "pkg-config file not found")
        endif()

	# Rely on the exact version specified in pkg-config file.
	# This is normally the version set in autoconf, but we alter it for when
	# packaging openconnect for use in ocelot's external builds

        file(STRINGS "${CPACK_OCG_BINARY_DIR}/external/lib/pkgconfig/openconnect.pc" MYVAR REGEX "Version: (.*)")
        string(REGEX REPLACE "^Version: (.*)$" "\\1" OC_VERSION "${MYVAR}")

	#message(STATUS "Working in external openconnect mode. ${OC_VERSION}")
    endif()

    # Use the exact version produced by git-revision instead of CPACK_PACKAGE_VERSION
    file(STRINGS "${CPACK_OCG_BINARY_DIR}/src/config.h" MYVAR REGEX "#define PROJECT_VERSION \"(.*)\"")

    # there are many lines with the PROJECT_VERSION, due to way the file was generated; use the last
    list(LENGTH MYVAR MYVAR_COUNT)
    if(MYVAR_COUNT GREATER 1)
        list(GET MYVAR -1 MYVAR)
    endif()

    string(REGEX REPLACE "^#define PROJECT_VERSION \"(.*)\"$" "\\1" OCG_VERSION "${MYVAR}")

    # Replace all occurences of "-" with "." in version string, so that there is a clean separation between constituents
    string(REPLACE "-" "." OC_VERSION "${OC_VERSION}")
    string(REPLACE "-" "." OCG_VERSION "${OCG_VERSION}")

    message(STATUS "Generated installer name: '${CPACK_PACKAGE_NAME}-${OCG_VERSION}-oc-${OC_VERSION}-${CPACK_SYSTEM_NAME}'")
    set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-${OCG_VERSION}-oc-${OC_VERSION}-${CPACK_SYSTEM_NAME}")

endif()
