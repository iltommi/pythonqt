#-----------------------------------------------------------------------------
# PythonQt library

find_package(${PYTHONQT_QT} REQUIRED COMPONENTS Core Gui Widgets)
set_property(GLOBAL APPEND PROPERTY PYTHONQT_QT_DEPENDENCIES Core Gui Widgets)

set(headers
  PythonQt.h
  PythonQtStdDecorators.h
  PythonQtClassInfo.h
  PythonQtImporter.h
  PythonQtObjectPtr.h
  PythonQtProperty.h
  PythonQtSignal.h
  PythonQtSlot.h
  PythonQtSlotDecorator.h
  PythonQtStdIn.h
  PythonQtStdOut.h
  PythonQtMisc.h
  PythonQtMethodInfo.h
  PythonQtImportFileInterface.h
  PythonQtConversion.h
  PythonQtSignalReceiver.h
  PythonQtInstanceWrapper.h
  PythonQtClassWrapper.h
  PythonQtCppWrapperFactory.h
  PythonQtQFileImporter.h
  PythonQtVariants.h
  PythonQtSystem.h
  PythonQtUtils.h
  PythonQtBoolResult.h
  PythonQtThreadSupport.h
  PythonQtPythonInclude.h
)

set(gui_headers
  gui/PythonQtScriptingConsole.h
)

set(sources
  PythonQtStdDecorators.cpp
  PythonQt.cpp
  PythonQtClassInfo.cpp
  PythonQtImporter.cpp
  PythonQtObjectPtr.cpp
  PythonQtProperty.cpp
  PythonQtStdIn.cpp
  PythonQtStdOut.cpp
  PythonQtSignal.cpp
  PythonQtSlot.cpp
  PythonQtSlotDecorator.cpp
  PythonQtMisc.cpp
  PythonQtMethodInfo.cpp
  PythonQtConversion.cpp
  PythonQtSignalReceiver.cpp
  PythonQtInstanceWrapper.cpp
  PythonQtQFileImporter.cpp
  PythonQtClassWrapper.cpp
  PythonQtBoolResult.cpp
  gui/PythonQtScriptingConsole.cpp
  PythonQtThreadSupport.cpp
)

pythonqt_read_generated_module(com_trolltech_qt_core_builtin core_builtin_sources REQUIRED)
pythonqt_read_generated_module(com_trolltech_qt_gui_builtin gui_builtin_sources REQUIRED)

if(PYTHONQT_BUILD_SHARED)
  set(library_type SHARED)
else()
  set(library_type STATIC)
endif()

add_library(PythonQt ${library_type}
  ${headers}
  ${gui_headers}
  ${sources}
)
add_library(PythonQt::PythonQt ALIAS PythonQt)

set_target_properties(PythonQt PROPERTIES
  OUTPUT_NAME "PythonQt-Qt${QT_VERSION_MAJOR}-Python${PYTHONQT_PYTHON_VERSION}"
  EXPORT_NAME PythonQt
  VERSION ${PROJECT_VERSION}
  SOVERSION ${PROJECT_VERSION_MAJOR}
  AUTOMOC ON
)

pythonqt_add_generated_sources(PythonQt ${core_builtin_sources} ${gui_builtin_sources})

target_compile_definitions(PythonQt PRIVATE
  PYTHONQT_EXPORTS
  PYTHONQT_CATCH_ALL_EXCEPTIONS
)
if(NOT PYTHONQT_BUILD_SHARED)
  # on Windows the headers would otherwise declare the symbols as imported from a dll
  target_compile_definitions(PythonQt PUBLIC PYTHONQT_STATIC)
endif()

# gui/ is also listed so that both "gui/PythonQtScriptingConsole.h" and
# "PythonQtScriptingConsole.h" work
target_include_directories(PythonQt PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/gui>
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/PythonQt>
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/PythonQt/gui>
)

target_link_libraries(PythonQt
  PUBLIC
    ${PYTHONQT_QT}::Core
    ${PYTHONQT_QT}::Gui
    ${PYTHONQT_QT}::Widgets
    Python3::Python
)

# PythonQt.cpp needs <private/qmetaobjectbuilder_p.h>
if(QT_VERSION_MAJOR EQUAL 6)
  if(QT_VERSION VERSION_GREATER_EQUAL 6.9)
    # using the private API is intentional, do not warn about it
    set(QT_NO_PRIVATE_MODULE_WARNING ON)
    find_package(Qt6 REQUIRED COMPONENTS CorePrivate)
    if(NOT PYTHONQT_BUILD_SHARED)
      set_property(GLOBAL APPEND PROPERTY PYTHONQT_QT_DEPENDENCIES CorePrivate)
    endif()
  endif()
  target_link_libraries(PythonQt PRIVATE Qt6::CorePrivate)
else()
  target_include_directories(PythonQt PRIVATE ${Qt5Core_PRIVATE_INCLUDE_DIRS})
endif()

pythonqt_set_warning_flags(PythonQt)
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  target_compile_options(PythonQt PRIVATE -Wno-error=missing-field-initializers)
elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  target_compile_options(PythonQt PRIVATE -Wno-error=sometimes-uninitialized)
endif()
pythonqt_enable_big_objects(PythonQt)
pythonqt_no_undefined(PythonQt)

#-----------------------------------------------------------------------------
# Install

if(PYTHONQT_INSTALL)
  install(TARGETS PythonQt
    EXPORT PythonQtTargets
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  )
  install(FILES ${headers} DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/PythonQt)
  install(FILES ${gui_headers} DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/PythonQt/gui)

  pythonqt_write_pkgconfig(PythonQt "Dynamic Python binding for the Qt framework")
endif()
