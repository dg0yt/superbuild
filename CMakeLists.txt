# Copyright 2021 Kai Pastor

cmake_minimum_required(VERSION 3.19)
project(OpenOrienteering-vcpkg)

if(WIN32 AND NOT MINGW)
	message(WARNING "Unsupported configuration")
endif()


# Options for vcpkg configuration

set(REGISTRY_DEFAULT_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/registry" CACHE STRING
  "Location of the local registry (directory or git repository)"
)
set(REGISTRY_EXTRA "VCPKG;XYZ" CACHE STRING
  "Extra registries to be looked up via REGISTRY_<ID>_ROOT/_PACKAGES"
)
set(REGISTRY_VCPKG_ROOT "@VCPKG_ROOT@" CACHE STRING
  "Location of the vcpkg registry"
)
set(REGISTRY_VCPKG_PACKAGES "vcpkg-cmake;vcpkg-cmake-config" CACHE STRING
  "Packages taken from the vcpkg registry"
)
set(REGISTRY_XYZ_ROOT "NOTFOUND" CACHE STRING
  "Location of another registry"
)
set(REGISTRY_XYZ_PACKAGES "" CACHE STRING
  "Packages taken from that registry"
)


# Options for vcpkg bootstrapping

set(VCPKG_GIT_TAG "31534bd59bc5587d268012ae14d14c41a508ae81" CACHE STRING
  "Tag of the vcpkg repository to be checked out"
)
set(VCPKG_TOOL_GIT_TAG "f4e6bc1e06ec64ab40d6f2085ed504feb8d12165" CACHE STRING
  "Tag of the vcpkg tool repository to be checked out"
)
option(VCPKG_UPDATE_DISCONNECTED "Disables updates and rebuilds of vcpkg" ON)
option(VCPKG_DISABLE_METRICS "Disable transfer of vcpkg metrics to Microsoft" ON)
option(VCPKG_BUILD_TESTS "Build vcpkg-tool tests" OFF)
if(APPLE)
	option(VCPKG_ALLOW_APPLE_CLANG "Build vcpkg-tool with Apple Clang" ON)
else()
	set(VCPKG_ALLOW_APPLE_CLANG OFF)
endif()


# Project setup

include("cmake/vcpkg-configuration.cmake")
include("cmake/vcpkg-bootstrap.cmake")
include("cmake/vcpkg-commands.cmake")
