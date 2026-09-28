# --------------------------------------------------------------------------------------------------
# vpnc-scripts
# --------------------------------------------------------------------------------------------------
include(PatchFile)

ExternalProject_Add(vpnc-scripts-${vpnc-scripts-TAG}
    PREFIX ${CMAKE_BINARY_DIR}/external/

    UPDATE_DISCONNECTED 0
    UPDATE_COMMAND ""

    GIT_REPOSITORY https://gitlab.com/openconnect/vpnc-scripts.git
    GIT_TAG ${vpnc-scripts-TAG}
    #git shallow is not supported for commit hashes
    GIT_SHALLOW 0
    
    BUILD_IN_SOURCE 1

    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    # Our own copy is installed instead of the cloned one: it carries the split
    # DNS handling upstream does not have. The clone is still made, because the
    # generic (non-Windows) script is taken from it.
    INSTALL_COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_SOURCE_DIR}/contrib/vpnc-script-win.js
        ${CMAKE_BINARY_DIR}/external/vpnc-script.js
)

install(FILES  ${CMAKE_BINARY_DIR}/external/vpnc-script.js
   DESTINATION .
   COMPONENT vpnc_script
)
