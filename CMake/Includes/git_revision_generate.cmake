#create a pretty commit id using git
#uses 'git describe --tags', so tags are required in the repo
#create a tag with 'git tag <name>' and 'git push --tags'

if(IS_DIRECTORY ${GIT_ROOT_DIR}/.git)
    execute_process(
        COMMAND ${GIT_EXECUTABLE} describe --tags --dirty
        WORKING_DIRECTORY ${GIT_ROOT_DIR}
        RESULT_VARIABLE res_var
        OUTPUT_VARIABLE GIT_COM_ID
        ERROR_QUIET
    )

    if(res_var EQUAL 0)
        string(STRIP "${GIT_COM_ID}" GIT_COMMIT_ID)
        string(REGEX REPLACE "^v" "" GIT_COMMIT_ID "${GIT_COMMIT_ID}")
    else()
        # No tags yet, which is the ordinary state of a repository before its
        # first release. The version is then the one the project declares,
        # said plainly: a row of question marks in an About screen helps no
        # one, and the old code crashed the build here instead.
        execute_process(
            COMMAND ${GIT_EXECUTABLE} status --porcelain --untracked-files=no
            WORKING_DIRECTORY ${GIT_ROOT_DIR}
            OUTPUT_VARIABLE git_changes
            ERROR_QUIET
        )
        if("${git_changes}" STREQUAL "")
            set(GIT_COMMIT_ID "${PROJECT_VERSION}-dev")
        else()
            set(GIT_COMMIT_ID "${PROJECT_VERSION}-dev-dirty")
        endif()
    endif()

    # check number of digits in version string
    string(REPLACE "." ";" GIT_COMMIT_ID_VLIST ${GIT_COMMIT_ID})
    list(LENGTH GIT_COMMIT_ID_VLIST GIT_COMMIT_ID_VLIST_COUNT)

    # no.: major
    string(REGEX REPLACE "^v([0-9]+)\\..*" "\\1" VERSION_MAJOR "${GIT_COMMIT_ID}")
    # no.: minor
    string(REGEX REPLACE "^v[0-9]+\\.([0-9]+).*" "\\1" VERSION_MINOR "${GIT_COMMIT_ID}")

    if(${GIT_COMMIT_ID_VLIST_COUNT} STREQUAL "2")
        # no. patch
        set(VERSION_PATCH "0")
        # SHA1 string + git 'dirty' flag
        string(REGEX REPLACE "^v[0-9]+\\.[0-9]+(.*)" "\\1" VERSION_SHA1 "${GIT_COMMIT_ID}")
    else()
        # no. patch
        string(REGEX REPLACE "^v[0-9]+\\.[0-9]+\\.([0-9]+).*" "\\1" VERSION_PATCH "${GIT_COMMIT_ID}")
        # SHA1 string + git 'dirty' flag
        string(REGEX REPLACE "^v[0-9]+\\.[0-9]+\\.[0-9]+(.*)" "\\1" VERSION_SHA1 "${GIT_COMMIT_ID}")
    endif()

    set(PROJECT_VERSION "${GIT_COMMIT_ID}")
    message(STATUS "Version: ${PROJECT_VERSION} [git]")
else()
    message(STATUS "Version: ${PROJECT_VERSION} [cmake]")
endif()

if(PROJ_ADMIN_PRIV_ELEVATION)
    set(UAC_FLAG "")
else()
    set(UAC_FLAG "//")
endif()

message(STATUS "Processing resource file...")
file(READ ${INPUT_DIR}/${PROJECT_NAME}.rc.in rc_temporary)
string(CONFIGURE ${rc_temporary} rc_updated)
file(WRITE ${OUTPUT_DIR}/${PROJECT_NAME}.rc.tmp ${rc_updated})
execute_process(
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    ${OUTPUT_DIR}/${PROJECT_NAME}.rc.tmp ${OUTPUT_DIR}/${PROJECT_NAME}.rc
)

message(STATUS "Processing config.h file...")
file(READ ${OUTPUT_DIR}/config.h config_temp)
string(FIND "${config_temp}" "undef PROJECT_VERSION" ALREADY_UPDATED)

if(${ALREADY_UPDATED} LESS 0)
file(APPEND ${OUTPUT_DIR}/config.h "#undef PROJECT_VERSION\n#define PROJECT_VERSION \"${PROJECT_VERSION}\"\n")
endif()
