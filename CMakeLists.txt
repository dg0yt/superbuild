# Copyright 2021 Kai Pastor <dg0yt@darc.de>

cmake_minimum_required(VERSION 3.7 FATAL_ERROR)

if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.19")
    cmake_policy(SET CMP0114 NEW)
endif()

project(dpkg-ports VERSION 0.1.0 LANGUAGES NONE)

set(VCPKG_GIT_TAG "master" CACHE STRING "Vcpkg repo head")
option(VCPKG_DEBUG "Enable vcpkg debug output" OFF)
option(VCPKG_DISABLE_METRICS  "Disable vcpkg telemetry" ON)
option(VCPKG_FORMAT_MANIFEST  "Re-format manifest when building" ON)
option(VCPKG_INSTALL_EDITABLE "Build packages in editable mode" ON)
option(VCPKG_UPDATE_DISCONNECTED "Disables updates and rebuilds of vcpkg" ON)


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
ExternalProject_Add(vcpkg-root
  EXCLUDE_FROM_ALL 1
  GIT_REPOSITORY "https://github.com/microsoft/vcpkg"
  GIT_TAG "${VCPKG_GIT_TAG}"
  UPDATE_DISCONNECTED "${VCPKG_UPDATE_DISCONNECTED}"
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ${vcpkg_configure_metrics}
  BUILD_COMMAND "" #
  INSTALL_COMMAND ""
)
ExternalProject_Add_StepTargets(vcpkg-root update)
ExternalProject_Get_Property(vcpkg-root SOURCE_DIR)
set(VCPKG_ROOT "${SOURCE_DIR}")

# vcpkg tool
add_custom_command(OUTPUT "vcpkg-tool.stamp"
  COMMAND ${vcpkg_bootstrap}
  COMMAND "${CMAKE_COMMAND}" -E touch "${CMAKE_CURRENT_BINARY_DIR}/vcpkg-tool.stamp"
  WORKING_DIRECTORY "${VCPKG_ROOT}"
)
add_custom_target(vcpkg-tool
  DEPENDS
    "vcpkg-tool.stamp"
	vcpkg-root
)

# vcpkg configuration
get_filename_component(DPKG_PORTS_PATH "${CMAKE_CURRENT_SOURCE_DIR}" ABSOLUTE)
find_package(Git REQUIRED)
configure_file("cmake/update-configuration.cmake.in" "${CMAKE_CURRENT_BINARY_DIR}/update-configuration.cmake" @ONLY)
add_custom_target(vcpkg-configuration
  COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_BINARY_DIR}/update-configuration.cmake"
  SOURCES
    cmake/options.in
	cmake/update-configuration.cmake.in
	cmake/update-version.cmake.in
	cmake/vcpkg-configuration.json.in
  DEPENDS vcpkg-root
)

# vcpkg completely
add_custom_target(vcpkg
  DEPENDS vcpkg vcpkg-root vcpkg-tool vcpkg-configuration
)

# targets
set(all_ports "")
configure_file("cmake/update-version.cmake.in" "${CMAKE_CURRENT_BINARY_DIR}/update-version.cmake" @ONLY)
file(GLOB ports RELATIVE "${DPKG_PORTS_PATH}/ports" "${DPKG_PORTS_PATH}/ports/*")
set(vcpkg_install_options "")
if(VCPKG_DEBUG)
    list(APPEND vcpkg_install_options --debug)
endif()
if(INSTALL_EDITABLE)
    list(APPEND vcpkg_install_options --editable)
endif()
foreach(port IN LISTS ports)
    file(GLOB sources
      "${DPKG_PORTS_PATH}/ports/${port}/portfile.cmake"
      "${DPKG_PORTS_PATH}/ports/${port}/vcpkg.json"
    )
    if(sources MATCHES ";")
        string(APPEND all_ports "${port}\n")
    endif()
    add_custom_target("${port}"
      COMMAND ${vcpkg} remove --recurse "${port}" @options
      COMMAND ${vcpkg} install ${vcpkg_install_options} "${port}" @options
      COMMAND "${CMAKE_COMMAND}" -E copy "${DPKG_PORTS_PATH}/ports/${port}/vcpkg.json" "${CMAKE_CURRENT_BINARY_DIR}/${port}-vcpkg.json"
      COMMAND ${vcpkg} format-manifest "${CMAKE_CURRENT_BINARY_DIR}/${port}-vcpkg.json"
      COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${CMAKE_CURRENT_BINARY_DIR}/${port}-vcpkg.json" "${DPKG_PORTS_PATH}/ports/${port}/vcpkg.json"
      COMMAND "${CMAKE_COMMAND}" "-DPORT=${port}" -P "${CMAKE_CURRENT_BINARY_DIR}/update-version.cmake"
      WORKING_DIRECTORY "${VCPKG_ROOT}"
      SOURCES ${sources}
	  DEPENDS vcpkg
    )
endforeach()
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/all_ports" "${all_ports}")
add_custom_target(all-ports
  COMMAND ${vcpkg} remove --recurse @options @all_ports
  COMMAND ${vcpkg} install @options @all_ports
  WORKING_DIRECTORY "${VCPKG_ROOT}"
  SOURCES "versions/baseline.json"
  DEPENDS vcpkg
)
