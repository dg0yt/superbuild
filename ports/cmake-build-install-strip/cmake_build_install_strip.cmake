# Copyright 2021 Kai Pastor
#
# This file interacts closely with vcpkg_cmake_build and replaces the call to
# vcpkg_cmake_install in order to ensure stripping for VCPKG_BUILD_TYPE release.
# That's why it is implemented closely similar to vcpkg_cmake_build.cmake /
# vcpkg_cmake_install.cmake from 
#   https://github.com/microsoft/vcpkg/tree/master/ports/vcpkg-cmake
# which are Copyright 2021 Microsoft and licensed under the same MIT license.

if(Z_CMAKE_BUILD_INSTALL_STRIP_INSTALL_GUARD)
    return()
endif()
set(Z_CMAKE_BUILD_INSTALL_STRIP_INSTALL_GUARD ON CACHE INTERNAL "include guard")

function(cmake_build_install_strip)
	cmake_parse_arguments(PARSE_ARGV 0 "arg" "DISABLE_PARALLEL;ADD_BIN_TO_PATH" "" "")
	if(DEFINED arg_UNPARSED_ARGUMENTS)
		message(FATAL_ERROR "cmake_build_install_strip was passed extra arguments: ${arg_UNPARSED_ARGUMENTS}")
	endif()
	
	set(args)
	foreach(arg IN ITEMS DISABLE_PARALLEL ADD_BIN_TO_PATH)
		if(arg_${arg})
			list(APPEND args "${arg}")
		endif()
	endforeach()
	
	vcpkg_cmake_build(${args})
	
	set(buildtypes ${VCPKG_BUILD_TYPE})
	if(NOT buildtypes)
		set(buildtypes debug release)
	endif()
	foreach(VCPKG_BUILD_TYPE IN LISTS buildtypes)
		set(install_target "install")
		if(VCPKG_BUILD_TYPE STREQUAL "release")
			set(install_target "install/strip")
		endif()
		vcpkg_cmake_build(
		  LOGFILE_BASE install
		  TARGET "${install_target}"
		  ${args}
		)
	endforeach()
endfunction()
