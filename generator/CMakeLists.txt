cmake_minimum_required(VERSION 3.18)

#-----------------------------------------------------------------------------
project(PythonQtGenerator LANGUAGES CXX)
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# Setup Qt (also when the generator is configured on its own)

if(NOT PYTHONQT_QT)
  if(PYTHONQT_QT_VERSION_MAJOR)
    find_package(QT NAMES Qt${PYTHONQT_QT_VERSION_MAJOR} REQUIRED COMPONENTS Core)
  else()
    find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Core)
  endif()
  set(PYTHONQT_QT Qt${QT_VERSION_MAJOR})
endif()

find_package(${PYTHONQT_QT} REQUIRED COMPONENTS Core Xml)

if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 11)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
endif()

#-----------------------------------------------------------------------------
# Sources

set(parser_sources
  parser/ast.cpp
  parser/lexer.cpp
  parser/list.cpp
  parser/parser.cpp
  parser/smallobject.cpp
  parser/control.cpp
  parser/visitor.cpp
  parser/default_visitor.cpp
  parser/dumptree.cpp
  parser/tokens.cpp
  parser/binder.cpp
  parser/codemodel.cpp
  parser/type_compiler.cpp
  parser/name_compiler.cpp
  parser/declarator_compiler.cpp
  parser/class_compiler.cpp
  parser/codemodel_finder.cpp
  parser/compiler_utils.cpp
)

set(parser_headers
  parser/ast.h
  parser/lexer.h
  parser/list.h
  parser/parser.h
  parser/rxx_allocator.h
  parser/rpp-allocator.h
  parser/smallobject.h
  parser/tokens.h
  parser/symbol.h
  parser/control.h
  parser/visitor.h
  parser/default_visitor.h
  parser/dumptree.h
  parser/binder.h
  parser/codemodel.h
  parser/codemodel_fwd.h
  parser/type_compiler.h
  parser/name_compiler.h
  parser/declarator_compiler.h
  parser/class_compiler.h
  parser/codemodel_finder.h
  parser/compiler_utils.h
)

set(simplecpp_sources
  simplecpp/simplecpp.cpp
  simplecpp/simplecpp.h
)

set(sources
  generator.cpp
  main.cpp
  reporthandler.cpp
  typeparser.cpp
  typesystem.cpp
  asttoxml.cpp
  fileout.cpp
  generatorset.cpp
  metajava.cpp
  customtypes.cpp
  abstractmetabuilder.cpp
  abstractmetalang.cpp
  prigenerator.cpp
  generatorsetqtscript.cpp
  metaqtscriptbuilder.cpp
  metaqtscript.cpp
  shellgenerator.cpp
  shellimplgenerator.cpp
  shellheadergenerator.cpp
  setupgenerator.cpp
)

set(headers
  generator.h
  reporthandler.h
  typeparser.h
  typesystem.h
  asttoxml.h
  fileout.h
  generatorset.h
  metajava.h
  customtypes.h
  abstractmetabuilder.h
  abstractmetalang.h
  prigenerator.h
  generatorsetqtscript.h
  metaqtscriptbuilder.h
  metaqtscript.h
  shellgenerator.h
  shellimplgenerator.h
  shellheadergenerator.h
  setupgenerator.h
)

# qtscript_masterinclude.h, build_all.txt and the typesystem files are
# compiled into the executable
set(qrc_sources
  generator.qrc
)

#-----------------------------------------------------------------------------
# Build the executable

add_executable(pythonqt_generator
  ${sources}
  ${headers}
  ${parser_sources}
  ${parser_headers}
  ${simplecpp_sources}
  ${qrc_sources}
)

set_target_properties(pythonqt_generator PROPERTIES
  AUTOMOC ON
  AUTORCC ON
  MACOSX_BUNDLE OFF
)

target_include_directories(pythonqt_generator PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${CMAKE_CURRENT_SOURCE_DIR}/parser
  ${CMAKE_CURRENT_SOURCE_DIR}/simplecpp
)

target_compile_definitions(pythonqt_generator PRIVATE
  RXX_ALLOCATOR_INIT_0
  QT_NO_CAST_TO_ASCII
)

target_link_libraries(pythonqt_generator PRIVATE
  ${PYTHONQT_QT}::Core
  ${PYTHONQT_QT}::Xml
)

if(MSVC)
  # Disable warning C4996 (deprecated declarations)
  target_compile_options(pythonqt_generator PRIVATE /wd4996)
  if(MSVC_VERSION GREATER 1599 AND NOT CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    # Disable warnings for external headers
    target_compile_options(pythonqt_generator PRIVATE /external:anglebrackets /external:W0 /external:templates-)
  endif()
endif()
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
  target_compile_options(pythonqt_generator PRIVATE -Wno-deprecated-declarations -pedantic -Winit-self -Wuninitialized)
endif()
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  target_compile_options(pythonqt_generator PRIVATE -Wno-nested-anon-types -Wno-gnu-anonymous-struct -Wno-unused-private-field)
  if(MSVC)
    target_compile_options(pythonqt_generator PRIVATE -Wno-language-extension-token -Wno-microsoft-enum-value)
  endif()
endif()

source_group("Resources" FILES ${qrc_sources})

#-----------------------------------------------------------------------------
# Install

if(NOT DEFINED PYTHONQT_INSTALL OR PYTHONQT_INSTALL)
  include(GNUInstallDirs)
  install(TARGETS pythonqt_generator RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
endif()
