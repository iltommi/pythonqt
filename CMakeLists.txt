cmake_minimum_required(VERSION 3.18)

project(PythonQt
  VERSION 3.2.0
  DESCRIPTION "Dynamic Python binding for the Qt framework"
  HOMEPAGE_URL "https://github.com/MeVisLab/pythonqt"
  LANGUAGES CXX
)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)
include(PythonQtHelpers)

#-----------------------------------------------------------------------------
# Options
#
# A plain 'cmake -B <dir> && cmake --build <dir>' builds everything: when no
# generated wrappers are found, the generator is built and run while
# configuring (see PYTHONQT_GENERATE_MISSING_WRAPPERS). The two steps can also
# be done separately:
#   1. configure with -DPYTHONQT_BUILD_RUNTIME=OFF, build, then run the
#      generator (e.g. 'cmake --build <dir> --target generate_wrappers')
#   2. configure with -DPYTHONQT_BUILD_GENERATOR=OFF (or leave it ON) and build.

option(PYTHONQT_BUILD_GENERATOR "Build the wrapper generator (pythonqt_generator)" ON)
option(PYTHONQT_BUILD_RUNTIME "Build the PythonQt library, PythonQt_QtAll, tests and examples" ON)

# Static linking can also be requested through the PYTHONQT_STATIC environment variable.
if(DEFINED ENV{PYTHONQT_STATIC} AND NOT "$ENV{PYTHONQT_STATIC}" STREQUAL "")
  set(_pythonqt_shared_default OFF)
else()
  set(_pythonqt_shared_default ON)
endif()
option(PYTHONQT_BUILD_SHARED "Build PythonQt and PythonQt_QtAll as shared libraries" ${_pythonqt_shared_default})
option(PYTHONQT_BUILD_QTALL "Build the PythonQt_QtAll extension library" ON)
option(PYTHONQT_BUILD_TESTS "Build the PythonQt unit tests" ON)
option(PYTHONQT_BUILD_EXAMPLES "Build the PythonQt examples" ON)
option(PYTHONQT_INSTALL "Generate install rules" ON)

set(PYTHONQT_QT_VERSION_MAJOR "" CACHE STRING "Qt major version to build against (5 or 6); empty means autodetect, preferring Qt 6")
set(PYTHONQT_GENERATED_PATH "" CACHE PATH
  "Directory containing the generated wrappers; empty means <source>/generated_cpp, <build>/generated_cpp or <source>/generated_cpp_<QtMajor><QtMinor>")
option(PYTHONQT_GENERATE_MISSING_WRAPPERS
  "Build and run the generator while configuring when no generated wrappers are found" ON)
set(PYTHONQT_GENERATOR_ARGS "" CACHE STRING
  "Additional arguments for pythonqt_generator (e.g. --include-paths=...)")

if(NOT PYTHONQT_BUILD_GENERATOR AND NOT PYTHONQT_BUILD_RUNTIME)
  message(FATAL_ERROR "Both PYTHONQT_BUILD_GENERATOR and PYTHONQT_BUILD_RUNTIME are OFF: nothing to build.")
endif()

#-----------------------------------------------------------------------------
# Global build settings

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS Debug Release RelWithDebInfo MinSizeRel)
endif()

# Qt 6 raises this to C++17 through its usage requirements.
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# for all debug builds, add "_d" extension to libraries
set(CMAKE_DEBUG_POSTFIX "_d")

if(NOT CMAKE_RUNTIME_OUTPUT_DIRECTORY)
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/bin)
endif()
if(NOT CMAKE_LIBRARY_OUTPUT_DIRECTORY)
  set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)
endif()
if(NOT CMAKE_ARCHIVE_OUTPUT_DIRECTORY)
  set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)
endif()

if(APPLE)
  set(CMAKE_INSTALL_RPATH "@loader_path/../${CMAKE_INSTALL_LIBDIR}")
elseif(UNIX)
  set(CMAKE_INSTALL_RPATH "$ORIGIN/../${CMAKE_INSTALL_LIBDIR}")
endif()
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH ON)

#-----------------------------------------------------------------------------
# Qt

if(PYTHONQT_QT_VERSION_MAJOR)
  find_package(QT NAMES Qt${PYTHONQT_QT_VERSION_MAJOR} REQUIRED COMPONENTS Core)
else()
  find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Core)
endif()
set(PYTHONQT_QT Qt${QT_VERSION_MAJOR})
message(STATUS "PythonQt: using Qt ${QT_VERSION}")

#-----------------------------------------------------------------------------
# Generator

if(PYTHONQT_BUILD_GENERATOR)
  add_subdirectory(generator)

  set(PYTHONQT_GENERATOR_OUTPUT_DIRECTORY "${PROJECT_SOURCE_DIR}" CACHE PATH
    "Directory in which the 'generate_wrappers' target creates the generated_cpp folder")
  separate_arguments(_pythonqt_generator_args NATIVE_COMMAND "${PYTHONQT_GENERATOR_ARGS}")

  add_custom_target(generate_wrappers
    COMMAND pythonqt_generator --output-directory=${PYTHONQT_GENERATOR_OUTPUT_DIRECTORY} ${_pythonqt_generator_args}
    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
    COMMENT "Generating PythonQt wrappers into ${PYTHONQT_GENERATOR_OUTPUT_DIRECTORY}/generated_cpp"
    VERBATIM
    USES_TERMINAL
  )
endif()

if(NOT PYTHONQT_BUILD_RUNTIME)
  return()
endif()

#-----------------------------------------------------------------------------
# Python
#
# PYTHON_VERSION (<major>.<minor>) and PYTHON_DIR/PYTHON_PATH (root of the
# Python installation) are honoured both as CMake variables and as environment
# variables. Python3_ROOT_DIR, Python3_EXECUTABLE etc. work as usual.

if(NOT DEFINED PYTHON_VERSION AND DEFINED ENV{PYTHON_VERSION})
  set(PYTHON_VERSION "$ENV{PYTHON_VERSION}")
endif()
if(NOT Python3_ROOT_DIR)
  foreach(_var PYTHON_DIR PYTHON_PATH)
    if(${_var})
      set(Python3_ROOT_DIR "${${_var}}")
    elseif(DEFINED ENV{${_var}} AND NOT "$ENV{${_var}}" STREQUAL "")
      set(Python3_ROOT_DIR "$ENV{${_var}}")
    endif()
    if(Python3_ROOT_DIR)
      break()
    endif()
  endforeach()
endif()
if(NOT DEFINED Python3_FIND_FRAMEWORK)
  # do not prefer the macOS system framework over e.g. Homebrew or pyenv
  set(Python3_FIND_FRAMEWORK LAST)
endif()

if(PYTHON_VERSION)
  if(NOT PYTHON_VERSION MATCHES "^3\\.[0-9]+$")
    message(FATAL_ERROR "Failed to parse PYTHON_VERSION:\"${PYTHON_VERSION}\" (expected 3.<minor>, Python >= 3.x is required)")
  endif()
  find_package(Python3 ${PYTHON_VERSION} EXACT REQUIRED COMPONENTS Interpreter Development.Embed)
else()
  find_package(Python3 REQUIRED COMPONENTS Interpreter Development.Embed)
endif()
set(PYTHONQT_PYTHON_VERSION "${Python3_VERSION_MAJOR}.${Python3_VERSION_MINOR}")
message(STATUS "PythonQt: using Python ${Python3_VERSION} (${Python3_EXECUTABLE})")

# Recorded in PythonQtConfig.cmake, so that consumers use the same Python
# installation and applications can find what they have to ship
set(PYTHONQT_PYTHON_LIBRARY "${Python3_LIBRARY_RELEASE}")
if(NOT PYTHONQT_PYTHON_LIBRARY)
  set(PYTHONQT_PYTHON_LIBRARY "${Python3_LIBRARY_DEBUG}")
endif()
set(PYTHONQT_PYTHON_RUNTIME_LIBRARY "${Python3_RUNTIME_LIBRARY_RELEASE}")
if(NOT PYTHONQT_PYTHON_RUNTIME_LIBRARY)
  set(PYTHONQT_PYTHON_RUNTIME_LIBRARY "${PYTHONQT_PYTHON_LIBRARY}")
endif()
list(GET Python3_INCLUDE_DIRS 0 PYTHONQT_PYTHON_INCLUDE_DIR)
set(PYTHONQT_PYTHON_HOME "")
set(PYTHONQT_PYTHON_STDLIB "")
execute_process(
  COMMAND "${Python3_EXECUTABLE}" -c "import sys, sysconfig; print(sys.base_prefix); print(sysconfig.get_path('stdlib'))"
  OUTPUT_VARIABLE _pythonqt_python_paths
  RESULT_VARIABLE _pythonqt_python_result
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
if(_pythonqt_python_result EQUAL 0)
  string(REPLACE "\r" "" _pythonqt_python_paths "${_pythonqt_python_paths}")
  string(REPLACE "\n" ";" _pythonqt_python_paths "${_pythonqt_python_paths}")
  list(GET _pythonqt_python_paths 0 PYTHONQT_PYTHON_HOME)
  list(GET _pythonqt_python_paths 1 PYTHONQT_PYTHON_STDLIB)
  file(TO_CMAKE_PATH "${PYTHONQT_PYTHON_HOME}" PYTHONQT_PYTHON_HOME)
  file(TO_CMAKE_PATH "${PYTHONQT_PYTHON_STDLIB}" PYTHONQT_PYTHON_STDLIB)
else()
  message(WARNING "PythonQt: could not query the Python prefix from ${Python3_EXECUTABLE}")
endif()

#-----------------------------------------------------------------------------
# Generated wrappers

pythonqt_find_generated_path(PYTHONQT_GENERATED_DIR)
if(NOT PYTHONQT_GENERATED_DIR)
  if(PYTHONQT_GENERATE_MISSING_WRAPPERS AND NOT PYTHONQT_GENERATED_PATH)
    pythonqt_generate_wrappers(PYTHONQT_GENERATED_DIR)
  else()
    message(FATAL_ERROR
      "No generated wrapper sources for Qt ${QT_VERSION}.\n"
      "Looked in:\n  - ${PYTHONQT_GENERATED_LOOKED_IN}\n"
      "Enable -DPYTHONQT_GENERATE_MISSING_WRAPPERS=ON to generate them while configuring, or generate them first:\n"
      "  cmake -S . -B build-generator -DPYTHONQT_BUILD_RUNTIME=OFF\n"
      "  cmake --build build-generator --target generate_wrappers\n"
      "Or pass an explicit path:\n"
      "  cmake -DPYTHONQT_GENERATED_PATH=/abs/path/to/generated_cpp ...")
  endif()
endif()
message(STATUS "PythonQt: using generated sources files from ${PYTHONQT_GENERATED_DIR}")

#-----------------------------------------------------------------------------
# Targets

add_subdirectory(src)

if(PYTHONQT_BUILD_QTALL)
  add_subdirectory(extensions/PythonQt_QtAll)
elseif(PYTHONQT_BUILD_TESTS OR PYTHONQT_BUILD_EXAMPLES)
  message(FATAL_ERROR "PYTHONQT_BUILD_TESTS and PYTHONQT_BUILD_EXAMPLES require PYTHONQT_BUILD_QTALL")
endif()

if(PYTHONQT_BUILD_TESTS)
  enable_testing()
  add_subdirectory(tests)
endif()

if(PYTHONQT_BUILD_EXAMPLES)
  add_subdirectory(examples)
endif()

#-----------------------------------------------------------------------------
# Package

if(PYTHONQT_INSTALL)
  set(PYTHONQT_INSTALL_CMAKEDIR ${CMAKE_INSTALL_LIBDIR}/cmake/PythonQt)

  # Qt components needed by the exported targets (collected by the subdirectories)
  get_property(PYTHONQT_QT_DEPENDENCIES GLOBAL PROPERTY PYTHONQT_QT_DEPENDENCIES)
  list(REMOVE_DUPLICATES PYTHONQT_QT_DEPENDENCIES)
  list(JOIN PYTHONQT_QT_DEPENDENCIES " " PYTHONQT_QT_DEPENDENCIES)

  install(EXPORT PythonQtTargets
    NAMESPACE PythonQt::
    DESTINATION ${PYTHONQT_INSTALL_CMAKEDIR}
  )

  configure_package_config_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/PythonQtConfig.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/PythonQtConfig.cmake
    INSTALL_DESTINATION ${PYTHONQT_INSTALL_CMAKEDIR}
  )
  write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/PythonQtConfigVersion.cmake
    COMPATIBILITY SameMajorVersion
  )
  install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/PythonQtConfig.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/PythonQtConfigVersion.cmake
    DESTINATION ${PYTHONQT_INSTALL_CMAKEDIR}
  )
endif()
