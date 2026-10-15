#-----------------------------------------------------------------------------
# PythonQt examples

find_package(${PYTHONQT_QT} REQUIRED COMPONENTS Widgets)

# pythonqt_add_example(<name> [QTALL] SOURCES <files>...)
function(pythonqt_add_example name)
  cmake_parse_arguments(PARSE_ARGV 1 arg "QTALL" "" "SOURCES")

  add_executable(${name} ${arg_SOURCES})
  set_target_properties(${name} PROPERTIES
    AUTOMOC ON
    AUTORCC ON
    MACOSX_BUNDLE OFF
  )
  target_link_libraries(${name} PRIVATE
    PythonQt::PythonQt
    ${PYTHONQT_QT}::Widgets
  )
  if(arg_QTALL)
    target_link_libraries(${name} PRIVATE PythonQt::QtAll)
  endif()
  pythonqt_set_warning_flags(${name})
endfunction()

pythonqt_add_example(CPPPyWrapperExample
  SOURCES
    CPPPyWrapperExample/CPPPyWrapperExample.cpp
    CPPPyWrapperExample/CPPPyWrapperExample.qrc
)

pythonqt_add_example(PyGettingStarted
  SOURCES
    PyGettingStarted/main.cpp
    PyGettingStarted/PyGettingStarted.qrc
)

pythonqt_add_example(PyCPPWrapperExample
  SOURCES
    PyCPPWrapperExample/CustomObjects.h
    PyCPPWrapperExample/CustomObjects.cpp
    PyCPPWrapperExample/main.cpp
    PyCPPWrapperExample/PyCPPWrapperExample.qrc
)

pythonqt_add_example(PyCustomMetaTypeExample
  SOURCES
    PyCustomMetaTypeExample/CustomObject.h
    PyCustomMetaTypeExample/CustomObject.cpp
    PyCustomMetaTypeExample/main.cpp
    PyCustomMetaTypeExample/PyCustomMetaTypeExample.qrc
)

pythonqt_add_example(PyGuiExample QTALL
  SOURCES
    PyGuiExample/main.cpp
    PyGuiExample/PyGuiExample.qrc
)

pythonqt_add_example(PyDecoratorsExample
  SOURCES
    PyDecoratorsExample/PyExampleDecorators.h
    PyDecoratorsExample/PyExampleDecorators.cpp
    PyDecoratorsExample/main.cpp
    PyDecoratorsExample/PyDecoratorsExample.qrc
)

pythonqt_add_example(PyScriptingConsole QTALL
  SOURCES
    PyScriptingConsole/PyExampleObject.h
    PyScriptingConsole/PyExampleObject.cpp
    PyScriptingConsole/main.cpp
    PyScriptingConsole/PyScriptingConsole.qrc
)

pythonqt_add_example(PyLauncher QTALL
  SOURCES
    PyLauncher/main.cpp
)
