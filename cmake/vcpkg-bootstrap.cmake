# Copyright 2021 Kai Pastor

# This file creates the following targets:
#  vcpkg-root               Setup a vcpkg root at VCPKG_ROOT
#  vcpkg-tool               Bootstrap the vcpkg tool from source,
#                           with additonal patches.
#
# The configuration is taken from the following variables:
#  VCPKG_ROOT               Directory of the vcpkg root
#  VCPKG_GIT_TAG            Tag of the vcpkg repository to be checked out
#  VCPKG_TOOL_GIT_TAG       Tag of the vcpkg tool repository to be checked out
#  VCPKG_UPDATE_DISCONNECTED Disables updates and rebuilds of vcpkg
#  VCPKG_DISABLE_METRICS    Disable transfer of vcpkg metrics to Microsoft
#  VCPKG_BUILD_TESTS        Build vcpkg-tool tests
#  VCPKG_ALLOW_APPLE_CLANG  Build vcpkg-tool with Apple Clang (macOS only)


include(ExternalProject)
set_directory_properties(PROPERTIES EP_BASE "${CMAKE_CURRENT_BINARY_DIR}/external")

if (VCPKG_DISABLE_METRICS)
	set(vcpkg_configure_metrics touch "<SOURCE_DIR>/vcpkg.disable-metrics")
else()
	set(vcpkg_configure_metrics remove -f "<SOURCE_DIR>/vcpkg.disable-metrics")
endif()	
ExternalProject_Add(vcpkg-root
  EXCLUDE_FROM_ALL 1
  GIT_REPOSITORY "https://github.com/microsoft/vcpkg"
  GIT_TAG "${VCPKG_GIT_TAG}"
  UPDATE_DISCONNECTED "${VCPKG_UPDATE_DISCONNECTED}"
  SOURCE_DIR "${VCPKG_ROOT}"
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND
    "${CMAKE_COMMAND}" -E ${vcpkg_configure_metrics}
)

add_dependencies(vcpkg-configuration vcpkg-root)

ExternalProject_Add(vcpkg-tool
  EXCLUDE_FROM_ALL 1
  DEPENDS
    vcpkg-root
	vcpkg-configuration
  GIT_REPOSITORY "https://github.com/microsoft/vcpkg-tool"
  GIT_TAG "${VCPKG_TOOL_GIT_TAG}"
  UPDATE_DISCONNECTED "${VCPKG_UPDATE_DISCONNECTED}"
  PATCH_COMMAND
    patch -p1 < ${PROJECT_SOURCE_DIR}/patches/Use-only-named-packages-from-extra-registries.patch
  COMMAND
    patch -p1 < ${PROJECT_SOURCE_DIR}/patches/Don-t-build-tls12-download-with-MINGW.patch
  COMMAND
    patch -p1 < ${PROJECT_SOURCE_DIR}/patches/Choose-MinGW-triplets-when-building-vcpkg-with-MinGW.patch
  CMAKE_GENERATOR Ninja
  CMAKE_ARGS
    -DCMAKE_BUILD_TYPE=Release
	"-DBUILD_TESTING=${VCPKG_BUILD_TESTS}"
	"-DVCPKG_DEVELOPMENT_WARNINGS=OFF"
	"-DVCPKG_ALLOW_APPLE_CLANG=${VCPKG_ALLOW_APPLE_CLANG}"
  INSTALL_COMMAND
    "${CMAKE_COMMAND}" -E copy_if_different
      "<BINARY_DIR>/vcpkg${CMAKE_EXECUTABLE_SUFFIX}"
	  "${VCPKG_EXECUTABLE}"
  TEST_COMMAND
    ${VCPKG_COMMAND} --debug update
  COMMAND
    ${VCPKG_COMMAND} --debug search
  TEST_AFTER_INSTALL 1
)
