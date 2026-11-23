# --------------------------------------------------------------------------------------------------
# qt-solutions
# --------------------------------------------------------------------------------------------------
set(QT_SOLUTIONS_SOURCE_DIR "" CACHE PATH "Local writable checkout of qt-solutions")

if(QT_SOLUTIONS_SOURCE_DIR)
    set(_qt_solutions_source_args
        SOURCE_DIR "${QT_SOLUTIONS_SOURCE_DIR}"
        DOWNLOAD_COMMAND ${CMAKE_COMMAND} -E true
    )
    set(_qt_solutions_source_dir "${QT_SOLUTIONS_SOURCE_DIR}")
else()
    set(_qt_solutions_source_args
        GIT_REPOSITORY https://code.qt.io/qt-solutions/qt-solutions.git
        GIT_TAG ${qt-solutions-TAG}
        GIT_SHALLOW 1
    )
    set(_qt_solutions_source_dir "${CMAKE_BINARY_DIR}/external/src/qt-solutions-${qt-solutions-TAG}")
endif()

ExternalProject_Add(qt-solutions-${qt-solutions-TAG}
    PREFIX ${CMAKE_BINARY_DIR}/external/
    INSTALL_DIR ${CMAKE_BINARY_DIR}/external
    CMAKE_ARGS "${CMAKE_ARGS};-DQt6_DIR=${Qt6_DIR};-DCMAKE_BUILD_TYPE=Release;-DCMAKE_INSTALL_PREFIX:PATH=<INSTALL_DIR>"
    
    UPDATE_DISCONNECTED 0
    UPDATE_COMMAND ""
    
    ${_qt_solutions_source_args}
    
    BUILD_IN_SOURCE 1
        
    PATCH_COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_SOURCE_DIR}/CMake/Includes/CMakeLists_qt-solutions.cmake.in
        "${_qt_solutions_source_dir}/CMakeLists.txt"
    CMAKE_COMMAND ${CMAKE_CROSS_COMMAND}

    # Note: ninja-1.8.2 & cmake-3.10.2 failed in find/install this dependency wo next 2 lines :(
    BUILD_BYPRODUCTS ${CMAKE_BINARY_DIR}/external/lib/libqtsingleapplication.a
    INSTALL_COMMAND ${CMAKE_COMMAND} --build . --target install
)

add_library(qt-solutions::qtsingleapplication STATIC IMPORTED)
set_target_properties(qt-solutions::qtsingleapplication PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_BINARY_DIR}/external/include"
    IMPORTED_LOCATION ${CMAKE_BINARY_DIR}/external/lib/libqtsingleapplication.a
)
set_property(TARGET qt-solutions::qtsingleapplication PROPERTY
    DEPENDS qt-solutions-${qt-solutions-TAG}
)
