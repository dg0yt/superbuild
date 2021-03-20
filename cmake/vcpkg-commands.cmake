# Copyright 2021 Kai Pastor

# This file creates targets which run vcpkg commands
#  vcpkg-list
#  vcpkg-search
#  vcpkg-update
#
# For each <port> in VCPKG_PORTS, it creates
#  <port>-install
#  <port>-remove
# 
# These 'install' targets run in "editable" mode, i.e. ignoring the cache, and
# retaining the source directory. Before the vcpkg install step, a vcpkg remove
# --recurse step is executed for the package.
#
# The 'remove' targets execute a vcpkg remove --recurse step, followed by
# removal of the port's directory from the buildtrees directory.


foreach(command list search update)
	add_custom_target(vcpkg-${command}
	  DEPENDS vcpkg-tool
	  COMMAND ${VCPKG_COMMAND} ${command} 
	  VERBATIM
	)
endforeach()

message(STATUS "The following ports are available via CMake targets (<PORT>-install/remove):")
foreach(port ${VCPKG_PORTS})
	message(STATUS "  ${port}")
	string(REGEX REPLACE " .*" "" port "${port}")
	string(MAKE_C_IDENTIFIER "${port}" port_id)
	add_custom_target("${port_id}-install"
	  DEPENDS vcpkg-tool
	  COMMAND ${VCPKG_COMMAND} remove --recurse "${port}"
	  COMMAND ${VCPKG_COMMAND} install --editable "${port}"
	  VERBATIM
	)
	add_custom_target("${port_id}-remove"
	  DEPENDS vcpkg-tool
	  COMMAND ${VCPKG_COMMAND} remove --recurse "${port}"
	  COMMAND "${CMAKE_COMMAND}" -E remove_directory "${VCPKG_ROOT}/buildtrees/${port}"
	  VERBATIM
	)
endforeach()
