# Copyright 2021 Kai Pastor <dg0yt@darc.de>

cmake_minimum_required(VERSION 3.7 FATAL_ERROR)

if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.19")
    cmake_policy(SET CMP0114 NEW)
endif()

project(dpkg-ports VERSION 0.1.0 LANGUAGES NONE)

set(VCPKG_GIT_TAG "master" CACHE STRING "Vcpkg repo head")
option(VCPKG_DISABLE_METRICS "Disable vcpkg telemetry" ON)
option(VCPKG_UPDATE_DISCONNECTED "Disables updates and rebuilds of vcpkg" ON)
option(VCPKG_DEBUG "Enable vcpkg debug output" OFF)

option(INSTALL_EDITABLE ON "Build packages in editable mode")
option(FORMAT_MANIFEST ON "Re-format manifest when building")


include(ExternalProject)

if(CMAKE_HOST_WIN32)
    set(vcpkg_bootstrap [[.\bootstrap-vcpkg.bat]])
    set(vcpkg [[.\vcpkg]])
else()
    set(vcpkg_bootstrap [[./bootstrap-vcpkg.sh]])
    set(vcpkg [[./vcpkg]])
endif()

if(VCPKG_DISABLE_METRICS)
    set(vcpkg_configure_metrics "${CMAKE_COMMAND}" -E touch "<SOURCE_DIR>/vcpkg.disable-metrics")
    list(APPEND vcpkg_bootstrap "-disableMetrics")
else()
    set(vcpkg_configure_metrics "${CMAKE_COMMAND}" -E remove -f "<SOURCE_DIR>/vcpkg.disable-metrics")
endif()	

# vcpkg repo
ExternalProject_Add(x-vcpkg-root
  EXCLUDE_FROM_ALL 1
  GIT_REPOSITORY "https://github.com/microsoft/vcpkg"
  GIT_TAG "${VCPKG_GIT_TAG}"
  UPDATE_DISCONNECTED "${VCPKG_UPDATE_DISCONNECTED}"
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ${vcpkg_configure_metrics}
  BUILD_COMMAND "" #
  INSTALL_COMMAND ""
)
ExternalProject_Add_StepTargets(x-vcpkg-root update)
ExternalProject_Get_Property(x-vcpkg-root SOURCE_DIR)
set(VCPKG_ROOT "${SOURCE_DIR}")

# vcpkg tool
add_custom_command(OUTPUT "x-vcpkg-tool.stamp"
  COMMAND ${vcpkg_bootstrap}
  COMMAND "${CMAKE_COMMAND}" -E touch "${CMAKE_CURRENT_BINARY_DIR}/x-vcpkg-tool.stamp"
  WORKING_DIRECTORY "${VCPKG_ROOT}"
)
add_custom_target(x-vcpkg-tool ALL DEPENDS "x-vcpkg-tool.stamp")
add_dependencies(x-vcpkg-tool x-vcpkg-root)

# vcpkg configuration
get_filename_component(DPKG_PORTS_PATH "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
find_package(Git REQUIRED)
configure_file("update-configuration.cmake.in" "${CMAKE_CURRENT_BINARY_DIR}/update-configuration.cmake" @ONLY)
add_custom_target(x-vcpkg-configuration
  COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_BINARY_DIR}/update-configuration.cmake"
)
add_dependencies(x-vcpkg-configuration x-vcpkg-root)

# vcpkg completely
add_custom_target(x-vcpkg ALL)
add_dependencies(x-vcpkg x-vcpkg-root x-vcpkg-tool x-vcpkg-configuration)

# targets
file(GLOB ports RELATIVE "${DPKG_PORTS_PATH}/ports" "${DPKG_PORTS_PATH}/ports/*")
set(vcpkg_install_options "")
if(VCPKG_DEBUG)
    list(APPEND vcpkg_install_options --debug)
endif()
if(INSTALL_EDITABLE)
    list(APPEND vcpkg_install_options --editable)
endif()
foreach(port IN LISTS ports)
	file(GLOB sources "${DPKG_PORTS_PATH}/ports/${port}/*")
	if(NOT EXISTS "${DPKG_PORTS_PATH}/ports/${port}/portfile.cmake")
		add_custom_target("${port}" SOURCES ${sources})
		continue()
	endif()
    add_custom_target("${port}"
      COMMAND ${vcpkg} x-add-version "${port}"
         #"--vcpkg-root=${CMAKE_CURRENT_SOURCE_DIR}/.."
         "--x-builtin-ports-root=${CMAKE_CURRENT_SOURCE_DIR}/../ports"
         "--x-builtin-registry-versions-dir=${CMAKE_CURRENT_SOURCE_DIR}/../versions"
      COMMAND ${vcpkg} remove --recurse "${port}" @options
      COMMAND ${vcpkg} install ${vcpkg_install_options} "${port}" @options
	  COMMAND "${CMAKE_COMMAND}" -E copy "${DPKG_PORTS_PATH}/ports/${port}/vcpkg.json" "${CMAKE_CURRENT_BINARY_DIR}/${port}-vcpkg.json"
      COMMAND ${vcpkg} format-manifest "${CMAKE_CURRENT_BINARY_DIR}/${port}-vcpkg.json"
	  COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${CMAKE_CURRENT_BINARY_DIR}/${port}-vcpkg.json" "${DPKG_PORTS_PATH}/ports/${port}/vcpkg.json"
      WORKING_DIRECTORY "${VCPKG_ROOT}"
      SOURCES ${sources}
    )
    add_dependencies("${port}" x-vcpkg)
endforeach()

