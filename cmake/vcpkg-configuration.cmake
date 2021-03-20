# Copyright 2021 Kai Pastor

# This file sets the following variables:
#  VCPKG_ROOT               Directory of the vcpkg root
#  VCPKG_EXECUTABLE         Filepath of the vcpkg tool
#  VCPKG_COMMAND            Command line to invoke the vcpkg tool, including
#                           setup of the environment
#  VCPKG_PORTS              List of ports in the default registry
#
# It creates a a vcpkg-configuration.json file and the following target
#  vcpkg-configuration      Copies vcpkg-configuration.json to VCPKG_ROOT
#
# The configuration is taken from the following variables:
#
#  REGISTRY_DEFAULT_ROOT      Location of the local registry (directory or git repository)
#  REGISTRY_EXTRA             Extra registries to be looked up via REGISTRY_<ID>_ROOT/_PACKAGES
#
# For each <ID> listed in REGISTRY_EXTRA, the following variables are read:
#  REGISTRY_<ID>_ROOT         Location of the <ID> registry
#  REGISTRY_<ID>_PACKAGES     Packages to be taken from that registry


function(get_registry_kind VAR root)
	if(NOT EXISTS "${root}")
		set(${VAR} "git" PARENT_SCOPE)
		return()
	endif()
	file(READ "${root}/versions/baseline.json" baseline_json)
	string(JSON first_port ERROR_VARIABLE json_error MEMBER "${baseline_json}" "default" 0)
	string(REGEX REPLACE "^(.).*" "\\1" first_letter "${first_port}")
	if(EXISTS "${root}/versions/${first_letter}-/${first_port}.json")
		file(READ "${root}/versions/${first_letter}-/${first_port}.json" versions_json)
		if(versions_json MATCHES "\"git-tree\"[^\"]*:")
			set(${VAR} "git" PARENT_SCOPE)
			return()
		endif()
	endif()
	set(${VAR} "filesystem" PARENT_SCOPE)
endfunction()

function(make_registry_json VAR)
	set(options DEFAULT)
    set(oneValueArgs ROOT)
    set(multipleValuesArgs PACKAGES)
    cmake_parse_arguments(PARSE_ARGV 1 REGISTRY "${options}" "${oneValueArgs}" "${multipleValuesArgs}")
	
	if(NOT DEFINED REGISTRY_ROOT)
        message(FATAL_ERROR "make_registry_json requires a REGISTRY_ROOT argument.")
	endif()
    if(REGISTRY_DEFAULT AND DEFINED REGISTRY_PACKAGES)
        message(FATAL_ERROR "make_registry_json arguments DEFAULT and PACKAGES are mutually exclusive.")
    endif()
	if(NOT REGISTRY_DEFAULT AND NOT DEFINED REGISTRY_PACKAGES)
        message(FATAL_ERROR "make_registry_json requires either the DEFAULT option or a PACKAGES argument.")
	endif()
	
	string(CONFIGURE "${REGISTRY_ROOT}" root @ONLY)
	get_registry_kind(kind "${root}")
	if(kind STREQUAL "git")
		set(key "repository")
	else()
		set(key "path")
	endif()
	
	if(REGISTRY_DEFAULT)
		set(packages "")
	else()
		string(REGEX REPLACE ";" [[","]] packages ", \"packages\": [\"${REGISTRY_PACKAGES}\"]")
	endif()
	
	string(CONFIGURE "{ \"kind\": \"@kind@\", \"@key@\": \"@root@\" @packages@ }"
	  json @ONLY
	)
	set(${VAR} "${json}" PARENT_SCOPE)
endfunction()

function(get_ports VAR root)
	if(NOT EXISTS "${root}")
		set(${VAR} PARENT_SCOPE)
		return()
	endif()
	set(available_ports )
	file(READ "${root}/versions/baseline.json" baselines)
	foreach(baseline "default")
		string(JSON ports GET "${baselines}" "${baseline}")
		string(JSON count LENGTH "${ports}")
		if(count EQUAL 0)
			continue()
		endif()
		math(EXPR last "${count} - 1")
		foreach(i RANGE 0 ${last})
			string(JSON package MEMBER "${ports}" ${i})
			string(JSON version GET "${ports}" "${package}" "baseline")
			string(JSON port_version ERROR_VARIABLE ignored GET "$ports" "${package}" "port-version")
			string(REGEX REPLACE "^(....................)([^ ]*).*" "\\1\\2" padded_name "${package}                  ")
			if(port_version)
				list(APPEND available_ports "${padded_name} ${version}#${port_version}")
			else()
				list(APPEND available_ports "${padded_name} ${version}")
			endif()
		endforeach()
	endforeach()
	list(SORT available_ports)
	set(${VAR} ${available_ports} PARENT_SCOPE)
endfunction()



set(VCPKG_ROOT "${PROJECT_BINARY_DIR}/vcpkg")
set(VCPKG_EXECUTABLE "${PROJECT_BINARY_DIR}/vcpkg/vcpkg${CMAKE_EXECUTABLE_SUFFIX}")

find_program(system_cmake cmake)
if(system_cmake STREQUAL CMAKE_COMMAND)
	set(set_path )
else()
	get_filename_component(cmake_directory "${CMAKE_COMMAND}" DIRECTORY)
	set(set_path "PATH=${cmake_directory}:$ENV{PATH}")
endif()
set(VCPKG_COMMAND
  "${CMAKE_COMMAND}" -E env "PATH=${cmake_directory}:$ENV{PATH}" "VCPKG_FEATURE_FLAGS=registries"
  "${VCPKG_EXECUTABLE}"
)

make_registry_json(default_registry DEFAULT ROOT "${REGISTRY_DEFAULT_ROOT}")
string(JSON json SET "{}" "default-registry" "${default_registry}")
set(i 0)
foreach(name ${REGISTRY_EXTRA})
	if(NOT REGISTRY_${name}_ROOT)
		continue()
	endif()
	if(i EQUAL 0)
		string(JSON json SET "${json}" "registries" "[]")
	endif()
	make_registry_json(registry ROOT "${REGISTRY_${name}_ROOT}"
	  PACKAGES ${REGISTRY_${name}_PACKAGES}
	)
	string(JSON json SET "${json}" "registries" ${i} "${registry}")
	math(EXPR i "${i} + 1")
endforeach()

file(WRITE "${PROJECT_BINARY_DIR}/vcpkg-configuration.json" "${json}")

add_custom_target(vcpkg-configuration
  COMMAND "${CMAKE_COMMAND}" -E copy_if_different
    "${PROJECT_BINARY_DIR}/vcpkg-configuration.json" "${VCPKG_ROOT}"
)

get_ports(VCPKG_PORTS "${REGISTRY_DEFAULT_ROOT}")
