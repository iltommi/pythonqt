# Helper functions shared by the PythonQt CMake build.

# pythonqt_find_generated_path(<out_var>)
#
# Locates the directory with the generated wrapper sources. Uses
# PYTHONQT_GENERATED_PATH if set, otherwise <source>/generated_cpp,
# <build>/generated_cpp (where pythonqt_generate_wrappers() puts them) and
# finally the checked-in <source>/generated_cpp_<QtMajor><QtMinor> reference
# tree. Sets <out_var> to an empty string if none of them exists.
function(pythonqt_find_generated_path out_var)
  set(_candidates)
  if(PYTHONQT_GENERATED_PATH)
    get_filename_component(_path "${PYTHONQT_GENERATED_PATH}" ABSOLUTE BASE_DIR "${PROJECT_BINARY_DIR}")
    list(APPEND _candidates "${_path}")
  else()
    list(APPEND _candidates
      "${PROJECT_SOURCE_DIR}/generated_cpp"
      "${PROJECT_BINARY_DIR}/generated_cpp"
      "${PROJECT_SOURCE_DIR}/generated_cpp_${QT_VERSION_MAJOR}${QT_VERSION_MINOR}"
    )
  endif()

  set(${out_var} "" PARENT_SCOPE)
  foreach(_dir IN LISTS _candidates)
    if(EXISTS "${_dir}/com_trolltech_qt_core_builtin/com_trolltech_qt_core_builtin.pri")
      set(${out_var} "${_dir}" PARENT_SCOPE)
      return()
    endif()
  endforeach()

  list(JOIN _candidates "\n  - " _looked_in)
  set(PYTHONQT_GENERATED_LOOKED_IN "${_looked_in}" PARENT_SCOPE)
endfunction()

# pythonqt_target_qt_headers(<out_var>)
#
# Sets <out_var> to the include root of the Qt PythonQt is built against (the
# directory containing QtCore/), or to an empty string when the headers are not
# laid out like that (e.g. macOS frameworks). Passed to the generator as QTDIR
# when it was built with another Qt (cross-compiling).
function(pythonqt_target_qt_headers out_var)
  set(_dir "")
  if(QT6_INSTALL_PREFIX AND QT6_INSTALL_HEADERS)
    set(_dir "${QT6_INSTALL_PREFIX}/${QT6_INSTALL_HEADERS}")
  elseif(TARGET ${PYTHONQT_QT}::Core)
    get_target_property(_includes ${PYTHONQT_QT}::Core INTERFACE_INCLUDE_DIRECTORIES)
    foreach(_include IN LISTS _includes)
      if(_include MATCHES "^(.*)/QtCore/?$")
        set(_dir "${CMAKE_MATCH_1}")
        break()
      endif()
    endforeach()
  endif()
  if(NOT _dir OR NOT IS_DIRECTORY "${_dir}/QtCore")
    set(_dir "")
  endif()
  set(${out_var} "${_dir}" PARENT_SCOPE)
endfunction()

# pythonqt_generate_wrappers(<out_var>)
#
# Runs the wrapper generator while CMake is configuring to create
# <build>/generated_cpp. The source lists of the wrappers are only known once
# they exist, so this cannot be a normal build step. Sets <out_var> to the
# generated directory.
#
# The generator is PYTHONQT_GENERATOR_EXECUTABLE when given, otherwise it is
# built in <build>/generator-bootstrap: with the same CMake generator, compiler
# and Qt as the main project, or when cross-compiling with the host compiler
# and the host Qt (QT_HOST_PATH), reading the target Qt headers.
function(pythonqt_generate_wrappers out_var)
  set(_bootstrap_dir "${PROJECT_BINARY_DIR}/generator-bootstrap")
  set(_bin_dir "${_bootstrap_dir}/bin")

  # for cross builds: what to do when the host generator cannot be built
  set(_cross_hint
    "When cross-compiling, the generator is built for the build machine with the host Qt: "
    "set QT_HOST_PATH (and PYTHONQT_HOST_CXX_COMPILER if needed), or pass a prebuilt "
    "generator with -DPYTHONQT_GENERATOR_EXECUTABLE=<path>, or wrappers generated on "
    "another machine with -DPYTHONQT_GENERATED_PATH=<path>/generated_cpp.")
  string(CONCAT _cross_hint ${_cross_hint})

  if(PYTHONQT_GENERATOR_EXECUTABLE)
    if(NOT EXISTS "${PYTHONQT_GENERATOR_EXECUTABLE}")
      message(FATAL_ERROR "PythonQt: PYTHONQT_GENERATOR_EXECUTABLE does not exist: ${PYTHONQT_GENERATOR_EXECUTABLE}")
    endif()
    set(_generator "${PYTHONQT_GENERATOR_EXECUTABLE}")
    message(STATUS "PythonQt: no generated wrappers found, using ${_generator}")
  else()
    if(CMAKE_CROSSCOMPILING)
      message(STATUS "PythonQt: no generated wrappers found, building the generator for the build machine (this takes a while)")
    else()
      message(STATUS "PythonQt: no generated wrappers found, building the generator (this takes a while)")
    endif()

    # forward the toolchain and Qt settings through an initial cache file,
    # which keeps list values such as CMAKE_PREFIX_PATH intact
    set(_init_cache "${_bootstrap_dir}-init.cmake")
    set(_content "")
    set(_env "")
    if(CMAKE_CROSSCOMPILING)
      # host compiler and host Qt: forward none of the target settings, and
      # drop the ones a cross environment (e.g. Fedora's mingw64-cmake) exports
      set(_forward CMAKE_MAKE_PROGRAM)
      if(PYTHONQT_HOST_CXX_COMPILER)
        string(APPEND _content "set(CMAKE_CXX_COMPILER [==[${PYTHONQT_HOST_CXX_COMPILER}]==] CACHE FILEPATH \"\")\n")
      endif()
      if(QT_HOST_PATH)
        string(APPEND _content "set(CMAKE_PREFIX_PATH [==[${QT_HOST_PATH}]==] CACHE STRING \"\")\n")
      endif()
      if(QT_HOST_PATH_CMAKE_DIR)
        string(APPEND _content
          "set(Qt${QT_VERSION_MAJOR}_DIR [==[${QT_HOST_PATH_CMAKE_DIR}/Qt${QT_VERSION_MAJOR}]==] CACHE PATH \"\")\n")
      endif()
      set(_env "${CMAKE_COMMAND}" -E env
        --unset=CC --unset=CXX --unset=CFLAGS --unset=CXXFLAGS --unset=CPPFLAGS --unset=LDFLAGS
        --unset=CMAKE_TOOLCHAIN_FILE --unset=CMAKE_PREFIX_PATH --unset=PKG_CONFIG_PATH)
    else()
      set(_forward
        CMAKE_MAKE_PROGRAM CMAKE_CXX_COMPILER CMAKE_CXX_COMPILER_LAUNCHER CMAKE_TOOLCHAIN_FILE
        CMAKE_PREFIX_PATH CMAKE_OSX_ARCHITECTURES CMAKE_OSX_SYSROOT CMAKE_OSX_DEPLOYMENT_TARGET
        Qt${QT_VERSION_MAJOR}_DIR)
    endif()
    foreach(_var IN LISTS _forward)
      if(${_var})
        string(APPEND _content "set(${_var} [==[${${_var}}]==] CACHE STRING \"\")\n")
      endif()
    endforeach()
    string(APPEND _content
      "set(CMAKE_BUILD_TYPE Release CACHE STRING \"\")\n"
      "set(CMAKE_RUNTIME_OUTPUT_DIRECTORY [==[${_bin_dir}]==] CACHE PATH \"\")\n"
      "set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE [==[${_bin_dir}]==] CACHE PATH \"\")\n"
      "set(PYTHONQT_INSTALL OFF CACHE BOOL \"\")\n"
      "set(PYTHONQT_QT_VERSION_MAJOR ${QT_VERSION_MAJOR} CACHE STRING \"\")\n")
    file(WRITE "${_init_cache}" "${_content}")

    set(_args
      -C "${_init_cache}"
      -S "${PROJECT_SOURCE_DIR}/generator"
      -B "${_bootstrap_dir}"
      -G "${CMAKE_GENERATOR}"
    )
    if(CMAKE_GENERATOR_PLATFORM AND NOT CMAKE_CROSSCOMPILING)
      list(APPEND _args -A "${CMAKE_GENERATOR_PLATFORM}")
    endif()
    if(CMAKE_GENERATOR_TOOLSET AND NOT CMAKE_CROSSCOMPILING)
      list(APPEND _args -T "${CMAKE_GENERATOR_TOOLSET}")
    endif()

    execute_process(
      COMMAND ${_env} "${CMAKE_COMMAND}" ${_args}
      OUTPUT_FILE "${_bootstrap_dir}-configure.log"
      ERROR_FILE "${_bootstrap_dir}-configure.log"
      RESULT_VARIABLE _result
    )
    if(NOT _result EQUAL 0)
      if(CMAKE_CROSSCOMPILING)
        message(FATAL_ERROR "PythonQt: configuring the generator for the build machine failed "
          "(see ${_bootstrap_dir}-configure.log).\n${_cross_hint}")
      endif()
      message(FATAL_ERROR "PythonQt: configuring the generator failed, see ${_bootstrap_dir}-configure.log")
    endif()

    if(CMAKE_CROSSCOMPILING)
      # the generator reads the target headers, so a different host Qt is
      # usually fine, but worth knowing about when the wrappers do not compile
      file(STRINGS "${_bootstrap_dir}-configure.log" _host_qt REGEX "PythonQt generator: using Qt ")
      if(_host_qt MATCHES "using Qt ([0-9.]+)")
        set(_host_qt_version "${CMAKE_MATCH_1}")
        message(STATUS "PythonQt: host Qt for the generator: ${_host_qt_version}")
        if(NOT _host_qt_version VERSION_EQUAL QT_VERSION)
          message(WARNING "PythonQt: the generator is built with the host Qt ${_host_qt_version}, "
            "the library with Qt ${QT_VERSION}. The wrappers are generated from the Qt ${QT_VERSION} "
            "headers, but if they do not compile use a host Qt of the same version.")
        endif()
      endif()
    endif()

    include(ProcessorCount)
    ProcessorCount(_jobs)
    if(_jobs EQUAL 0)
      set(_jobs 2)
    endif()
    execute_process(
      COMMAND ${_env} "${CMAKE_COMMAND}" --build "${_bootstrap_dir}" --config Release --parallel ${_jobs}
      OUTPUT_FILE "${_bootstrap_dir}-build.log"
      ERROR_FILE "${_bootstrap_dir}-build.log"
      RESULT_VARIABLE _result
    )
    if(NOT _result EQUAL 0)
      if(CMAKE_CROSSCOMPILING)
        message(FATAL_ERROR "PythonQt: building the generator for the build machine failed "
          "(see ${_bootstrap_dir}-build.log).\n${_cross_hint}")
      endif()
      message(FATAL_ERROR "PythonQt: building the generator failed, see ${_bootstrap_dir}-build.log")
    endif()

    if(CMAKE_CROSSCOMPILING)
      # CMAKE_EXECUTABLE_SUFFIX is the target's
      if(CMAKE_HOST_WIN32)
        set(_generator "${_bin_dir}/pythonqt_generator.exe")
      else()
        set(_generator "${_bin_dir}/pythonqt_generator")
      endif()
    else()
      set(_generator "${_bin_dir}/pythonqt_generator${CMAKE_EXECUTABLE_SUFFIX}")
    endif()
  endif()

  set(_old_path "$ENV{PATH}")
  set(_old_qtdir "$ENV{QTDIR}")
  set(_cross_generator FALSE)
  if(CMAKE_CROSSCOMPILING OR PYTHONQT_GENERATOR_EXECUTABLE)
    set(_cross_generator TRUE)
  endif()

  if(_cross_generator)
    # the generator was built with another Qt: point it to the headers of the
    # Qt the library is built against (unless QTDIR is already set)
    if("$ENV{QTDIR}" STREQUAL "")
      pythonqt_target_qt_headers(_qt_headers)
      if(_qt_headers)
        set(ENV{QTDIR} "${_qt_headers}")
        message(STATUS "PythonQt: generating from the Qt headers in ${_qt_headers}")
      endif()
    endif()
  else()
    # the generator needs the Qt libraries at runtime (relevant on Windows)
    set(_qt_bin_dir "")
    if(QT6_INSTALL_PREFIX AND QT6_INSTALL_BINS)
      set(_qt_bin_dir "${QT6_INSTALL_PREFIX}/${QT6_INSTALL_BINS}")
    elseif(TARGET ${PYTHONQT_QT}::qmake)
      foreach(_prop IMPORTED_LOCATION IMPORTED_LOCATION_RELEASE IMPORTED_LOCATION_DEBUG)
        get_target_property(_qmake ${PYTHONQT_QT}::qmake ${_prop})
        if(_qmake)
          get_filename_component(_qt_bin_dir "${_qmake}" DIRECTORY)
          break()
        endif()
      endforeach()
    endif()
    if(_qt_bin_dir)
      if(WIN32)
        set(ENV{PATH} "${_qt_bin_dir};$ENV{PATH}")
      else()
        set(ENV{PATH} "${_qt_bin_dir}:$ENV{PATH}")
      endif()
    endif()
  endif()

  message(STATUS "PythonQt: generating wrappers into ${PROJECT_BINARY_DIR}/generated_cpp")
  separate_arguments(_generator_args NATIVE_COMMAND "${PYTHONQT_GENERATOR_ARGS}")
  execute_process(
    COMMAND "${_generator}" "--output-directory=${PROJECT_BINARY_DIR}" ${_generator_args}
    WORKING_DIRECTORY "${PROJECT_BINARY_DIR}"
    OUTPUT_FILE "${PROJECT_BINARY_DIR}/generate_wrappers.log"
    ERROR_FILE "${PROJECT_BINARY_DIR}/generate_wrappers.log"
    RESULT_VARIABLE _result
  )
  set(ENV{PATH} "${_old_path}")
  set(ENV{QTDIR} "${_old_qtdir}")

  set(_dir "${PROJECT_BINARY_DIR}/generated_cpp")
  if(NOT _result EQUAL 0 OR NOT EXISTS "${_dir}/com_trolltech_qt_core_builtin/com_trolltech_qt_core_builtin.pri")
    message(FATAL_ERROR "PythonQt: generating the wrappers failed, see ${PROJECT_BINARY_DIR}/generate_wrappers.log")
  endif()

  set(${out_var} "${_dir}" PARENT_SCOPE)
endfunction()

# pythonqt_read_generated_module(<module> <sources_out_var> [REQUIRED])
#
# Reads the source and header lists of a generated wrapper module (e.g.
# com_trolltech_qt_core) from the .pri file written by the generator.
# Sets <sources_out_var> to an empty list if the module was not generated,
# unless REQUIRED is given.
function(pythonqt_read_generated_module module out_var)
  cmake_parse_arguments(PARSE_ARGV 2 arg "REQUIRED" "" "")

  set(_dir "${PYTHONQT_GENERATED_DIR}/${module}")
  set(_pri "${_dir}/${module}.pri")
  if(NOT EXISTS "${_pri}")
    if(arg_REQUIRED)
      message(FATAL_ERROR "Generated wrapper module '${module}' not found: ${_pri}")
    endif()
    set(${out_var} "" PARENT_SCOPE)
    return()
  endif()

  # re-run CMake when the generator rewrites the file list
  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_pri}")

  file(READ "${_pri}" _content)
  string(REGEX MATCHALL "\\$\\$PWD/[^ \t\r\n\\\\]+" _entries "${_content}")
  set(_files)
  foreach(_entry IN LISTS _entries)
    string(REPLACE "$$PWD" "${_dir}" _file "${_entry}")
    list(APPEND _files "${_file}")
  endforeach()
  list(REMOVE_DUPLICATES _files)

  set(${out_var} ${_files} PARENT_SCOPE)
endfunction()

# pythonqt_add_generated_sources(<target> <files>...)
#
# Adds generated wrapper sources to <target>, which must have AUTOMOC enabled.
# By default AUTOMOC compiles the moc files of all headers in a single
# translation unit, which breaks with the many Qt headers the wrappers include
# (and the wrapper headers have no include guards). Like qmake, compile each
# moc file on its own instead, through a small shim in the build directory.
function(pythonqt_add_generated_sources target)
  set(_shim_dir "${CMAKE_CURRENT_BINARY_DIR}/${target}_mocs")
  set(_shims)
  set(_include_dirs)
  foreach(_file IN LISTS ARGN)
    if(NOT _file MATCHES "\\.h$")
      continue()
    endif()
    file(STRINGS "${_file}" _qobject REGEX "Q_OBJECT" LIMIT_COUNT 1)
    if(NOT _qobject)
      continue()
    endif()
    get_filename_component(_dir "${_file}" DIRECTORY)
    get_filename_component(_name "${_file}" NAME_WE)
    set(_shim "${_shim_dir}/moc_${_name}_shim.cpp")
    file(CONFIGURE OUTPUT "${_shim}"
      CONTENT "// generated by CMake, do not edit\n#include \"moc_${_name}.cpp\"\n"
      @ONLY)
    list(APPEND _shims "${_shim}")
    list(APPEND _include_dirs "${_dir}")
  endforeach()
  list(REMOVE_DUPLICATES _include_dirs)

  target_sources(${target} PRIVATE ${ARGN} ${_shims})
  # lets AUTOMOC find the header for each '#include "moc_<name>.cpp"'
  target_include_directories(${target} PRIVATE ${_include_dirs})

  source_group("Generated Files" FILES ${ARGN})
  source_group("Generated Files\\moc" FILES ${_shims})
endfunction()

# pythonqt_set_warning_flags(<target>)
#
# Applies the warning flags used by the PythonQt sources.
function(pythonqt_set_warning_flags target)
  if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(${target} PRIVATE -Wno-deprecated-declarations -Wuninitialized -Winit-self -pedantic)
  endif()
  if(MSVC AND CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    target_compile_options(${target} PRIVATE -Wno-unused-command-line-argument)
  endif()
endfunction()

# pythonqt_enable_big_objects(<target>)
#
# Works around "number of sections exceeded object file format limit" errors
# with the large generated wrapper sources.
function(pythonqt_enable_big_objects target)
  if(MSVC)
    target_compile_options(${target} PRIVATE /bigobj)
  elseif(MINGW)
    target_compile_options(${target} PRIVATE -Wa,-mbig-obj)
  endif()
endfunction()

# pythonqt_no_undefined(<target>)
#
# Forces the linker to complain about undefined references in shared libraries.
function(pythonqt_no_undefined target)
  get_target_property(_type ${target} TYPE)
  if(NOT _type STREQUAL "SHARED_LIBRARY")
    return()
  endif()
  # (the Apple linker already does this by default)
  if((UNIX AND NOT APPLE) OR MINGW)
    target_link_options(${target} PRIVATE "LINKER:--no-undefined")
  endif()
endfunction()

# pythonqt_write_pkgconfig(<target> <description>)
#
# Generates and installs a pkg-config file for <target> (Unix only).
function(pythonqt_write_pkgconfig target description)
  if(NOT UNIX OR NOT PYTHONQT_INSTALL)
    return()
  endif()
  get_target_property(_name ${target} OUTPUT_NAME)
  set(PC_NAME "${_name}")
  set(PC_DESCRIPTION "${description}")
  set(PC_LIBNAME "${_name}$<$<CONFIG:Debug>:${CMAKE_DEBUG_POSTFIX}>")
  configure_file(${PROJECT_SOURCE_DIR}/cmake/PythonQt.pc.in ${CMAKE_CURRENT_BINARY_DIR}/${_name}.pc.in @ONLY)
  file(GENERATE
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>/${_name}.pc
    INPUT ${CMAKE_CURRENT_BINARY_DIR}/${_name}.pc.in
  )
  install(FILES ${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>/${_name}.pc
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig
  )
endfunction()
