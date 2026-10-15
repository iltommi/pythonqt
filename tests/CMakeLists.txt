#-----------------------------------------------------------------------------
# PythonQt unit tests

find_package(${PYTHONQT_QT} REQUIRED COMPONENTS Test Widgets)

set(PYTHONQT_TEST_PLATFORM "offscreen" CACHE STRING
  "Qt platform plugin used when running the tests through CTest (empty to use the default)")

add_executable(PythonQtTest
  PythonQtTestCleanup.h
  PythonQtTests.h
  PythonQtTestCleanup.cpp
  PythonQtTestMain.cpp
  PythonQtTests.cpp
)

set_target_properties(PythonQtTest PROPERTIES
  AUTOMOC ON
  MACOSX_BUNDLE OFF
)

target_compile_definitions(PythonQtTest PRIVATE QT_NO_CAST_TO_ASCII)

target_link_libraries(PythonQtTest PRIVATE
  PythonQt::PythonQt
  PythonQt::QtAll
  ${PYTHONQT_QT}::Test
  ${PYTHONQT_QT}::Widgets
)

pythonqt_set_warning_flags(PythonQtTest)

set(test_args)
if(PYTHONQT_TEST_PLATFORM)
  list(APPEND test_args -platform ${PYTHONQT_TEST_PLATFORM})
endif()

add_test(NAME PythonQtTest COMMAND PythonQtTest ${test_args})

if(WIN32 AND Python3_RUNTIME_LIBRARY_DIRS AND CMAKE_VERSION VERSION_GREATER_EQUAL 3.22)
  # make the Python DLL available to the test executable
  set(path_modifications)
  foreach(dir IN LISTS Python3_RUNTIME_LIBRARY_DIRS)
    file(TO_NATIVE_PATH "${dir}" dir)
    list(APPEND path_modifications "PATH=path_list_prepend:${dir}")
  endforeach()
  set_tests_properties(PythonQtTest PROPERTIES ENVIRONMENT_MODIFICATION "${path_modifications}")
endif()
