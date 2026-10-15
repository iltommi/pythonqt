#-----------------------------------------------------------------------------
# PythonQt_QtAll: wrappers for the Qt modules
#
# PYTHONQTALL_CONFIG selects the wrapped modules, e.g.
#   -DPYTHONQTALL_CONFIG="PythonQtCore;PythonQtGui;PythonQtMultimedia"
# (the PYTHONQTALL_CONFIG environment variable is used as a fallback). When it
# is empty, every module whose Qt component and generated wrappers are
# available is enabled.

set(PYTHONQTALL_CONFIG "$ENV{PYTHONQTALL_CONFIG}" CACHE STRING
  "List of PythonQt_QtAll modules to build (e.g. PythonQtCore;PythonQtGui); empty means all available")

# <config name> | <define suffix> | <generated module> | <Qt components> | <Qt5 only>
#   | <extra Qt6 components> | <optional extra Qt6 components>
set(qtall_modules
  # on Qt 6 the generator wraps the QtOpenGL(Widgets) classes as part of QtGui
  "PythonQtCore|CORE|com_trolltech_qt_core|Core|0||"
  "PythonQtGui|GUI|com_trolltech_qt_gui|Gui,Widgets,PrintSupport|0||OpenGL,OpenGLWidgets"
  "PythonQtSvg|SVG|com_trolltech_qt_svg|Svg|0|SvgWidgets|"
  "PythonQtSql|SQL|com_trolltech_qt_sql|Sql|0||"
  "PythonQtNetwork|NETWORK|com_trolltech_qt_network|Network|0||"
  "PythonQtOpengl|OPENGL|com_trolltech_qt_opengl|OpenGL,Xml|1||"
  "PythonQtXml|XML|com_trolltech_qt_xml|Xml|0||"
  "PythonQtXmlpatterns|XMLPATTERNS|com_trolltech_qt_xmlpatterns|XmlPatterns|0||"
  "PythonQtMultimedia|MULTIMEDIA|com_trolltech_qt_multimedia|Multimedia,MultimediaWidgets|0||"
  "PythonQtQml|QML|com_trolltech_qt_qml|Qml|0||"
  "PythonQtQuick|QUICK|com_trolltech_qt_quick|Quick,QuickWidgets|0||"
  "PythonQtUiTools|UITOOLS|com_trolltech_qt_uitools|UiTools|0||"
  "PythonQtWebEngineWidgets|WEBENGINEWIDGETS|com_trolltech_qt_webenginewidgets|WebEngineWidgets|0||"
  "PythonQtWebKit|WEBKIT|com_trolltech_qt_webkit|WebKit,WebKitWidgets|0||"
)

string(REPLACE " " ";" requested_modules "${PYTHONQTALL_CONFIG}")
list(REMOVE_ITEM requested_modules "")
if(requested_modules)
  message(STATUS "PythonQt_QtAll: using given configuration: ${requested_modules}")
else()
  message(STATUS "PythonQt_QtAll: using default configuration")
endif()
set(unknown_modules ${requested_modules})

set(qtall_defines)
set(qtall_sources)
set(qtall_qt_targets)
set(qtall_enabled)

foreach(entry IN LISTS qtall_modules)
  string(REPLACE "|" ";" entry "${entry}")
  list(GET entry 0 name)
  list(GET entry 1 define)
  list(GET entry 2 generated_module)
  list(GET entry 3 components)
  list(GET entry 4 qt5_only)
  list(GET entry 5 qt6_components)
  list(GET entry 6 optional_components)
  string(REPLACE "," ";" components "${components}")
  if(QT_VERSION_MAJOR GREATER_EQUAL 6)
    string(REPLACE "," ";" qt6_components "${qt6_components}")
    list(APPEND components ${qt6_components})
    string(REPLACE "," ";" optional_components "${optional_components}")
  else()
    set(optional_components)
  endif()

  if(requested_modules)
    list(FIND requested_modules ${name} index)
    if(index EQUAL -1)
      continue()
    endif()
    list(REMOVE_ITEM unknown_modules ${name})
    set(required REQUIRED)
  else()
    if(qt5_only AND QT_VERSION_MAJOR GREATER_EQUAL 6)
      # module is empty in Qt6
      continue()
    endif()
    set(required QUIET)
  endif()

  find_package(${PYTHONQT_QT} ${required} COMPONENTS ${components})
  set(found TRUE)
  foreach(component IN LISTS components)
    if(NOT TARGET ${PYTHONQT_QT}::${component})
      set(found FALSE)
    endif()
  endforeach()
  if(NOT found)
    continue()
  endif()
  foreach(component IN LISTS optional_components)
    find_package(${PYTHONQT_QT} QUIET COMPONENTS ${component})
    if(TARGET ${PYTHONQT_QT}::${component})
      list(APPEND components ${component})
    endif()
  endforeach()

  pythonqt_read_generated_module(${generated_module} module_sources)
  if(NOT module_sources)
    # same as qmake: the module is enabled, but there is nothing to wrap
    message(STATUS "PythonQt_QtAll: no generated wrappers for ${name}")
  endif()

  list(APPEND qtall_enabled ${name})
  list(APPEND qtall_defines PYTHONQT_WITH_${define})
  list(APPEND qtall_sources ${module_sources})
  foreach(component IN LISTS components)
    list(APPEND qtall_qt_targets ${PYTHONQT_QT}::${component})
  endforeach()
  set_property(GLOBAL APPEND PROPERTY PYTHONQT_QT_DEPENDENCIES ${components})
endforeach()

if(unknown_modules)
  message(FATAL_ERROR "PythonQt_QtAll: unknown modules in PYTHONQTALL_CONFIG: ${unknown_modules}")
endif()
list(REMOVE_DUPLICATES qtall_qt_targets)
message(STATUS "PythonQt_QtAll: enabled modules: ${qtall_enabled}")

if(PYTHONQT_BUILD_SHARED)
  set(library_type SHARED)
else()
  set(library_type STATIC)
endif()

add_library(PythonQt_QtAll ${library_type}
  PythonQt_QtAll.h
  PythonQt_QtAll.cpp
)
add_library(PythonQt::QtAll ALIAS PythonQt_QtAll)

set_target_properties(PythonQt_QtAll PROPERTIES
  OUTPUT_NAME "PythonQt_QtAll-Qt${QT_VERSION_MAJOR}-Python${PYTHONQT_PYTHON_VERSION}"
  EXPORT_NAME QtAll
  VERSION ${PROJECT_VERSION}
  SOVERSION ${PROJECT_VERSION_MAJOR}
  AUTOMOC ON
)

pythonqt_add_generated_sources(PythonQt_QtAll ${qtall_sources})

target_compile_definitions(PythonQt_QtAll PRIVATE
  PYTHONQT_QTALL_EXPORTS
  ${qtall_defines}
)

target_include_directories(PythonQt_QtAll PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/PythonQt>
)

target_link_libraries(PythonQt_QtAll
  PUBLIC
    PythonQt
  PRIVATE
    ${qtall_qt_targets}
)

pythonqt_set_warning_flags(PythonQt_QtAll)
pythonqt_enable_big_objects(PythonQt_QtAll)
pythonqt_no_undefined(PythonQt_QtAll)

#-----------------------------------------------------------------------------
# Install

if(PYTHONQT_INSTALL)
  install(TARGETS PythonQt_QtAll
    EXPORT PythonQtTargets
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  )
  install(FILES PythonQt_QtAll.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/PythonQt)

  pythonqt_write_pkgconfig(PythonQt_QtAll "Dynamic Python binding for the Qt framework")
endif()
