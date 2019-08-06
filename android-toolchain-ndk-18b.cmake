# This file is part of OpenOrienteering.

# Copyright 2016-2019 Kai Pastor
#
# Redistribution and use is allowed according to the terms of the BSD license:
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 
# 1. Redistributions of source code must retain the copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author may not be used to endorse or promote products 
#    derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

if(CMAKE_VERSION VERSION_LESS 3.7.0)
	get_filename_component(list_file "${CMAKE_CURRENT_LIST_FILE}" NAME)
	message(WARNING "Skipping '${list_file}': CMake version (${CMAKE_VERSION}) < 3.7")
	return()
endif()

set(ANDROID_TOOLCHAIN_VERSION "ndk-r18b" CACHE STRING
  "Version of the Android toolchain to be used"
)
if(NOT ANDROID_TOOLCHAIN_VERSION STREQUAL "ndk-r18b")
	return() # not this .cmake file
endif()

unset(ANDROID_NDK_VERSION CACHE)
set(ANDROID_NDK_VERSION "${ANDROID_TOOLCHAIN_VERSION}")

set(supported_abis
  arm64-v8a 
  armeabi-v7a  
  x86
  x86_64
)

set(system_arch_arm64-v8a    arm64)
set(system_arch_armeabi-v7a  arm)
set(system_arch_x86          x86)
set(system_arch_x86_64       x86_64)

set(system_name_arm64-v8a    aarch64-linux-android)
set(system_name_armeabi-v7a  arm-linux-androideabi)
set(system_name_x86          i686-linux-android)
set(system_name_x86_64       x86_64-linux-android)

set(system_platform_armeabi-v7a  android-16)
set(system_platform_arm64-v8a    android-21)
set(system_platform_x86          android-16)
set(system_platform_x86_64       android-21)

set(enabled_abis )
foreach(abi ${supported_abis})
	option(ENABLE_${system_name_${abi}} "Enable the ${system_name_${abi}} toolchain" 0)
	if(ENABLE_${system_name_${abi}})
		list(APPEND enabled_abis ${abi})
		set(${system_name_${abi}}_INSTALL_PREFIX "/usr" CACHE STRING
		  "Installation prefix for the Android ${abi} toolchain"
		)
		mark_as_advanced(${system_name_${abi}}_INSTALL_PREFIX)
	endif()
endforeach()
if(NOT enabled_abis)
	return() # *** Early exit ***
endif()

set(ANDROID_KEYSTORE_URL "ANDROID_KEYSTORE_URL-NOTFOUND" CACHE STRING
  "URL of the keystore to be used when signing APK packages."
)
set(ANDROID_KEYSTORE_ALIAS "ANDROID_KEYSTORE_ALIAS-NOTFOUND" CACHE STRING
  "Alias in the keystore to be used when signing APK packages."
)
if(CMAKE_BUILD_TYPE MATCHES Rel)
	if(NOT ANDROID_KEYSTORE_URL OR NOT ANDROID_KEYSTORE_ALIAS)
		# Warn here, fail on build - don't block other toolchains
		message(WARNING "You must configure ANDROID_KEYSTORE_URL and ANDROID_KEYSTORE_ALIAS for signing Android release packages.")
	endif()
endif()

if(NOT DEFINED ANDROID_SDK_ROOT AND NOT "$ENV{ANDROID_SDK_ROOT}" STREQUAL "")
	set(ANDROID_SDK_ROOT "$ENV{ANDROID_SDK_ROOT}")
endif()
if(NOT DEFINED ANDROID_NDK_ROOT AND NOT "$ENV{ANDROID_NDK_ROOT}" STREQUAL "")
	set(ANDROID_NDK_ROOT "$ENV{ANDROID_NDK_ROOT}")
endif()
if(NOT "$ENV{ANDROID_PLATFORM}" STREQUAL "")
	foreach(abi ${supported_abis})
		set(system_platform_${abi} "$ENV{ANDROID_PLATFORM}")
	endforeach()
elseif(DEFINED ANDROID_PLATFORM)
	foreach(abi ${supported_abis})
		set(system_platform_${abi} "${ANDROID_PLATFORM}")
	endforeach()
endif()
if(NOT DEFINED ANDROID_COMPILE_SDK AND NOT "$ENV{ANDROID_COMPILE_SDK}" STREQUAL "")
	set(ANDROID_COMPILE_SDK "$ENV{ANDROID_COMPILE_SDK}")
else()
	set(ANDROID_COMPILE_SDK android-28)
endif()

if(ANDROID_SDK_ROOT AND ANDROID_NDK_ROOT)
	set(sdk_host "") # external SDK and NDK
elseif(APPLE AND CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64")
	set(sdk_host "darwin")
elseif(UNIX AND NOT APPLE AND CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64")
	set(sdk_host "linux")
elseif(NOT ANDROID_SDK_ROOT)
	message(FATAL_ERROR "ANDROID_SDK_ROOT must be set to an external SDK")
elseif(NOT ANDROID_NDK_ROOT)
	message(FATAL_ERROR "ANDROID_NDK_ROOT must be set to an external NDK")
endif()

set(android_toolchain_dependencies )


if(NOT ANDROID_SDK_ROOT)
	# Download SDK tools, platform, platform tools, and build tools.
	set(sdk_tools_version   "4333796")
	set(sdk_tools_darwin_${sdk_tools_version}_hash SHA256=ecb29358bc0f13d7c2fa0f9290135a5b608e38434aad9bf7067d0252c160853e)
	set(sdk_tools_linux_${sdk_tools_version}_hash  SHA256=92ffee5a1d98d856634e8b71132e8a95d96c83a63fde1099be3d86df3106def9)
	set(build_tools_version "28.0.2")
	set(sdk_setup_sh [[
# Generated by ]] "${CMAKE_CURRENT_LIST_FILE}\n" [[
echo y | ./tools/bin/sdkmanager --install "platforms\\;]] "${ANDROID_COMPILE_SDK}" [["
echo y | ./tools/bin/sdkmanager --install "platform-tools"
echo y | ./tools/bin/sdkmanager --install "build-tools\\;]] "${build_tools_version}" [["
yes    | ./tools/bin/sdkmanager --licenses
]]
	)
	set(ANDROID_SDK_INSTALL_ROOT "${PROJECT_BINARY_DIR}/source" CACHE STRING
	  "The directory where to install the downloaded SDK (i.e. the basedir of ANDROID_SDK_ROOT)"
	)
	set(ANDROID_SDK_ROOT "${ANDROID_SDK_INSTALL_ROOT}/android-sdk-${sdk_tools_version}")
	superbuild_package(
	  NAME         android-sdk
	  VERSION      ${sdk_tools_version}
	  
	  SOURCE_WRITE
	    sdk_setup.sh  sdk_setup_sh
	  SOURCE
	    DOWNLOAD_NAME android-sdk-tools-${sdk_host}-${sdk_tools_version}.zip
	    URL           https://dl.google.com/android/repository/sdk-tools-${sdk_host}-${sdk_tools_version}.zip
	    URL_HASH      ${sdk_tools_${sdk_host}_${sdk_tools_version}_hash}
	    DOWNLOAD_NO_EXTRACT 1 # We extract manually from within the source directory.
	    PATCH_COMMAND
	      "${CMAKE_COMMAND}" -E make_directory "${ANDROID_SDK_ROOT}"
	    COMMAND
	      "${CMAKE_COMMAND}" -E chdir "${ANDROID_SDK_ROOT}"
	        "${CMAKE_COMMAND}" -E tar xzf "<DOWNLOADED_FILE>"
	    COMMAND
	      "${CMAKE_COMMAND}" -E chdir "${ANDROID_SDK_ROOT}"
	        sh -e "<SOURCE_DIR>/sdk_setup.sh" # Download missing components.
	)
	list(APPEND android_toolchain_dependencies source:android-sdk-${sdk_tools_version})
endif()

	
if(NOT ANDROID_NDK_ROOT)
	# Download NDK.
	string(REPLACE "ndk-" "" version ${ANDROID_NDK_VERSION})
	set(ndk_r18b_darwin_hash SHA1=98cb9909aa8c2dab32db188bbdc3ac6207e09440)
	set(ndk_r18b_linux_hash  SHA1=500679655da3a86aecf67007e8ab230ea9b4dd7b)
	set(ANDROID_NDK_INSTALL_ROOT "${PROJECT_BINARY_DIR}/source" CACHE STRING
	  "The directory where to install the downloaded NDK (i.e. the basedir of ANDROID_NDK_ROOT)"
	)
	set(ANDROID_NDK_ROOT "${ANDROID_NDK_INSTALL_ROOT}/android-ndk-${version}")
	superbuild_package(
	  NAME         android-ndk
	  VERSION      ${version}
	  
	  SOURCE
	    URL           https://dl.google.com/android/repository/android-ndk-${version}-${sdk_host}-x86_64.zip
	    URL_HASH      ${ndk_${version}_${sdk_host}_hash}
	    DOWNLOAD_NO_EXTRACT 1 # We extract manually from within the source directory.
	    PATCH_COMMAND
	      "${CMAKE_COMMAND}" -E chdir "${ANDROID_NDK_INSTALL_ROOT}"
	        "${CMAKE_COMMAND}" -E tar xzf "<DOWNLOADED_FILE>"
	)
	list(APPEND android_toolchain_dependencies source:android-ndk-${version})
	
	# For GPL compliance, allow building libc++ from source.
	option(ANDROID_BUILD_LIBCXX OFF "Rebuild libc++ for Android from source")
	if(ANDROID_BUILD_LIBCXX)
		if(EXISTS "${SUPERBUILD_DOWNLOAD_DIR}/android-platform.sums")
			message(STATUS "Using android-platform.sums")
			file(STRINGS "${SUPERBUILD_DOWNLOAD_DIR}/android-platform.sums" sums)
			foreach(string IN LISTS sums)
				if(string MATCHES "^([0-9a-f]*)  *(android-platform-[-_.0-9a-z]*).tar.gz")
					set(${CMAKE_MATCH_2}_hash URL_HASH SHA256=${CMAKE_MATCH_1})
				endif()
			endforeach()
		endif()
		# For commit IDs cf. git tags or NDK's prebuilt/linux-x86_64/repo.prop
		superbuild_package(
		  NAME         android-platform-bionic
		  VERSION      ${ANDROID_NDK_VERSION}
		  SOURCE
		    DOWNLOAD_NAME android-platform-bionic_${ANDROID_NDK_VERSION}.tar.gz
		    URL           https://github.com/OpenOrienteering/superbuild/releases/download/v20190622.4/android-platform-bionic_${ANDROID_NDK_VERSION}.tar.gz
		                  https://android.googlesource.com/platform/bionic/+archive/${ANDROID_NDK_VERSION}.tar.gz
		    ${android-platform-bionic_${ANDROID_NDK_VERSION}_hash}
		    DOWNLOAD_NO_EXTRACT 1
		)
		
		superbuild_package(
		  NAME         android-platform-external-libcxx
		  VERSION      ${ANDROID_NDK_VERSION}
		  SOURCE
		    DOWNLOAD_NAME android-platform-external-libcxx_${ANDROID_NDK_VERSION}.tar.gz
		    URL           https://github.com/OpenOrienteering/superbuild/releases/download/v20190622.4/android-platform-external-libcxx_${ANDROID_NDK_VERSION}.tar.gz
		                  https://android.googlesource.com/platform/external/libcxx/+archive/${ANDROID_NDK_VERSION}.tar.gz
		    ${android-platform-external-libcxx_${ANDROID_NDK_VERSION}_hash}
		    DOWNLOAD_NO_EXTRACT 1
		)
	
		superbuild_package(
		  NAME         android-platform-external-libcxxabi
		  VERSION      ${ANDROID_NDK_VERSION}
		  SOURCE
		    DOWNLOAD_NAME android-platform-external-libcxxabi_${ANDROID_NDK_VERSION}.tar.gz
		    URL           https://github.com/OpenOrienteering/superbuild/releases/download/v20190622.4/android-platform-external-libcxxabi_${ANDROID_NDK_VERSION}.tar.gz
		                  https://android.googlesource.com/platform/external/libcxxabi/+archive/${ANDROID_NDK_VERSION}.tar.gz
		    ${android-platform-external-libcxxabi_${ANDROID_NDK_VERSION}_hash}
		    DOWNLOAD_NO_EXTRACT 1
		)
	
		superbuild_package(
		  NAME         android-platform-external-libunwind_llvm
		  VERSION      ${ANDROID_NDK_VERSION}
		  SOURCE
		    DOWNLOAD_NAME android-platform-external-libunwind_llvm_${ANDROID_NDK_VERSION}.tar.gz
		    URL           https://github.com/OpenOrienteering/superbuild/releases/download/v20190622.4/android-platform-external-libunwind_llvm_${ANDROID_NDK_VERSION}.tar.gz
		                  https://android.googlesource.com/platform/external/libunwind_llvm/+archive/${ANDROID_NDK_VERSION}.tar.gz
		    ${android-platform-external-libunwind_llvm_${ANDROID_NDK_VERSION}_hash}
		    DOWNLOAD_NO_EXTRACT 1
		)
	
		superbuild_package(
		  NAME         android-libcxx
		  VERSION      ${ANDROID_NDK_VERSION}
		  DEPENDS
		    source:android-${ANDROID_NDK_VERSION}
		    source:android-platform-bionic-${ANDROID_NDK_VERSION}
		    source:android-platform-external-libcxx-${ANDROID_NDK_VERSION}
		    source:android-platform-external-libcxxabi-${ANDROID_NDK_VERSION}
		    source:android-platform-external-libunwind_llvm-${ANDROID_NDK_VERSION}
		  SOURCE
		    DOWNLOAD_COMMAND
		      "${CMAKE_COMMAND}" -E make_directory "<SOURCE_DIR>/bionic"
		    COMMAND
		      "${CMAKE_COMMAND}" -E chdir "<SOURCE_DIR>/bionic"
		        "${CMAKE_COMMAND}" -E tar xvf "${SUPERBUILD_DOWNLOAD_DIR}/android-platform-bionic_${ANDROID_NDK_VERSION}.tar.gz"
		    COMMAND
		      "${CMAKE_COMMAND}" -E make_directory "<SOURCE_DIR>/external/libcxx"
		    COMMAND
		      "${CMAKE_COMMAND}" -E chdir "<SOURCE_DIR>/external/libcxx"
		        "${CMAKE_COMMAND}" -E tar xvf "${SUPERBUILD_DOWNLOAD_DIR}/android-platform-external-libcxx_${ANDROID_NDK_VERSION}.tar.gz"
		    COMMAND
		      "${CMAKE_COMMAND}" -E make_directory "<SOURCE_DIR>/external/libcxxabi"
		    COMMAND
		      "${CMAKE_COMMAND}" -E chdir "<SOURCE_DIR>/external/libcxxabi"
		        "${CMAKE_COMMAND}" -E tar xvf "${SUPERBUILD_DOWNLOAD_DIR}/android-platform-external-libcxxabi_${ANDROID_NDK_VERSION}.tar.gz"
		    COMMAND
		      "${CMAKE_COMMAND}" -E make_directory "<SOURCE_DIR>/external/libunwind_llvm"
		    COMMAND
		      "${CMAKE_COMMAND}" -E chdir "<SOURCE_DIR>/external/libunwind_llvm"
		        "${CMAKE_COMMAND}" -E tar xvf "${SUPERBUILD_DOWNLOAD_DIR}/android-platform-external-libunwind_llvm_${ANDROID_NDK_VERSION}.tar.gz"
		    COMMAND
		      "${CMAKE_COMMAND}" -E create_symlink "${ANDROID_NDK_ROOT}" "android-${ANDROID_NDK_VERSION}"
		    COMMAND
		      "${CMAKE_COMMAND}" -E make_directory "<SOURCE_DIR>/toolchains/${sdk_host}-x86_64"
		    COMMAND
		      "${CMAKE_COMMAND}" -E create_symlink "${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${sdk_host}-x86_64" "<SOURCE_DIR>/toolchains/${sdk_host}-x86_64/llvm"
		    COMMAND
		      "${CMAKE_COMMAND}" -E create_symlink "${ANDROID_NDK_ROOT}/toolchains/aarch64-linux-android-4.9/prebuilt/${sdk_host}-x86_64" "<SOURCE_DIR>/toolchains/${sdk_host}-x86_64/aarch64-linux-android-4.9"
		    COMMAND
		      "${CMAKE_COMMAND}" -E create_symlink "${ANDROID_NDK_ROOT}/toolchains/arm-linux-androideabi-4.9/prebuilt/${sdk_host}-x86_64" "<SOURCE_DIR>/toolchains/${sdk_host}-x86_64/arm-linux-androideabi-4.9"
		    COMMAND
		      "${CMAKE_COMMAND}" -E create_symlink "${ANDROID_NDK_ROOT}/toolchains/x86-4.9/prebuilt/${sdk_host}-x86_64" "<SOURCE_DIR>/toolchains/${sdk_host}-x86_64/x86-4.9"
		    COMMAND
		      "${CMAKE_COMMAND}" -E create_symlink "${ANDROID_NDK_ROOT}/toolchains/x86_64-4.9/prebuilt/${sdk_host}-x86_64" "<SOURCE_DIR>/toolchains/${sdk_host}-x86_64/x86_64-4.9"
		)
		foreach(abi ${enabled_abis})
			superbuild_package(
			  NAME         android-libcxx-${abi}
			  VERSION      ${ANDROID_NDK_VERSION}
			  SOURCE
			    android-libcxx-${ANDROID_NDK_VERSION}
			  
			  USING ANDROID_NDK_ROOT abi system_platform_${abi}
			  BUILD [[
			    CONFIGURE_COMMAND ""
			    BUILD_COMMAND "${CMAKE_COMMAND}" -E chdir "<SOURCE_DIR>/external/libcxx"
			      bash -e -- "${ANDROID_NDK_ROOT}/ndk-build"
			        "V=1"
			        "APP_ABI=${abi}"
			        "APP_PLATFORM=${system_platform_${abi}}"
			        "APP_MODULES=c++_shared c++_static"
			        "BIONIC_PATH=<SOURCE_DIR>/bionic"
			        "NDK_UNIFIED_SYSROOT_PATH=${ANDROID_NDK_ROOT}/sysroot"
			        "NDK_PLATFORMS_ROOT=${ANDROID_NDK_ROOT}/platforms"
			        "NDK_TOOLCHAINS_ROOT=<SOURCE_DIR>/toolchains"
			        "NDK_NEW_TOOLCHAINS_LAYOUT=true"
			        "NDK_PROJECT_PATH=null"
			        "APP_BUILD_SCRIPT=<SOURCE_DIR>/external/libcxx/Android.mk"
			        "NDK_APPLICATION_MK=<SOURCE_DIR>/external/libcxx/Application.mk"
			        "NDK_OUT=<BINARY_DIR>/libcxx/obj"
			        "NDK_LIBS_OUT=<BINARY_DIR>/libcxx/libs"
			        "LIBCXX_FORCE_REBUILD=true"
			    INSTALL_COMMAND
			      "${CMAKE_COMMAND}" -E copy
				    "libcxx/obj/local/${abi}/libc++abi.a"
			        "libcxx/obj/local/${abi}/libc++_shared.so"
			        "libcxx/obj/local/${abi}/libc++_static.a"
			        $<$<OR:$<STREQUAL:${abi},armeabi-v7a>,$<STREQUAL:${abi},x86>>:
			        "libcxx/obj/local/${abi}/libandroid_support.a"
			        >
			        $<$<STREQUAL:${abi},armeabi-v7a>:
			        "libcxx/obj/local/${abi}/libunwind.a"
			        >
			        "${ANDROID_NDK_ROOT}/sources/cxx-stl/llvm-libc++/libs/${abi}/"
			    COMMAND
			      "${CMAKE_COMMAND}" -E copy
			        "<SOURCE_DIR>/external/libcxx/LICENSE.TXT"
			        "${ANDROID_NDK_ROOT}/sources/cxx-stl/llvm-libc++/NOTICE"
			    COMMAND
			      echo
			        "\\n"
			        "==============================================================================\\n"
			        "libc++ CREDITS.TXT\\n"
			        "==============================================================================\\n"
					>> "${ANDROID_NDK_ROOT}/sources/cxx-stl/llvm-libc++/NOTICE"
			    COMMAND
			      cat
			        "<SOURCE_DIR>/external/libcxx/CREDITS.TXT"
			        >> "${ANDROID_NDK_ROOT}/sources/cxx-stl/llvm-libc++/NOTICE"
			  ]]
			)
		endforeach()
		list(APPEND android_toolchain_dependencies android-libcxx-@abi@-${ANDROID_NDK_VERSION})
	endif()
endif()


# Create the actual toolchains.
foreach(abi ${enabled_abis})
	set(system_name "${system_name_${abi}}")
	
	sb_toolchain_dir(toolchain_dir ${system_name})
	sb_install_dir(install_dir ${system_name})
	
	if(NOT DEFINED ${system_name}_ENV_PATH)
		set(${system_name}_ENV_PATH "${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${sdk_host}-x86_64/bin:${toolchain_dir}/bin:$ENV{PATH}" PARENT_SCOPE)
	endif()
	
	if(NOT DEFINED ${system_name}_INSTALL_PREFIX)
		set(${system_name}_INSTALL_PREFIX "/usr")
	endif()
	
	if(NOT DEFINED ${system_name}_FIND_ROOT_PATH)
		set(${system_name}_FIND_ROOT_PATH [[${INSTALL_DIR}]])
	endif()
	
	set(toolchain [[
# Generated by ]] "${CMAKE_CURRENT_LIST_FILE}\n" [[

# Superbuild configuration
set(SYSTEM_NAME            "]] ${system_name} [[")
set(SUPERBUILD_TOOLCHAIN_TRIPLET ]] ${system_name} [[)
set(TOOLCHAIN_DIR          "]] "${toolchain_dir}" [[")
set(INSTALL_DIR            "]] "${install_dir}" [[")

set(CMAKE_INSTALL_PREFIX   "]] "${${system_name}_INSTALL_PREFIX}" [["
    CACHE PATH             "Run-time install path prefix, prepended onto install directories")
set(CMAKE_STAGING_PREFIX   "${INSTALL_DIR}${CMAKE_INSTALL_PREFIX}"
    CACHE PATH             "Install-time install path prefix, prepended onto install directories")
set(CMAKE_FIND_NO_INSTALL_PREFIX TRUE)

set(ANDROID_SDK_ROOT       "]] "${ANDROID_SDK_ROOT}" [[")
set(ANDROID_NDK_ROOT       "]] "${ANDROID_NDK_ROOT}" [[")
set(ANDROID_ABI            "]] ${abi} [[")
set(ANDROID_PLATFORM       "]] ${system_platform_${abi}} [[")
set(ANDROID_STL            "c++_shared")
set(ANDROID_TOOLCHAIN      "clang")
if("${CMAKE_VERSION}" VERSION_GREATER_EQUAL 3.15)
  set(CMAKE_C_COMPILER_FRONTEND_VARIANT   GNU)
  set(CMAKE_CXX_COMPILER_FRONTEND_VARIANT GNU)
endif()
include(]] "${ANDROID_NDK_ROOT}" [[/build/cmake/android.toolchain.cmake)

# Get rid of NDK root in CMAKE_FIND_ROOT_PATH
set(CMAKE_FIND_ROOT_PATH   "]] "${${system_name}_FIND_ROOT_PATH}" [[")
list(APPEND CMAKE_FIND_ROOT_PATH "${ANDROID_NDK_ROOT}/platforms/android-${ANDROID_NATIVE_API_LEVEL}/arch-]] ${system_arch_${abi}} [[")
set(CMAKE_SYSTEM_LIBRARY_PATH "/usr/lib/${SYSTEM_NAME}")

set(SUPERBUILD_CC           "]] "${toolchain_dir}" [[/bin/${SYSTEM_NAME}-clang")
set(SUPERBUILD_CXX          "]] "${toolchain_dir}" [[/bin/${SYSTEM_NAME}-clang++")

set(ANDROID_KEYSTORE_URL    "]] "${ANDROID_KEYSTORE_URL}" [[")
set(ANDROID_KEYSTORE_ALIAS  "]] "${ANDROID_KEYSTORE_ALIAS}" [[")
set(EXPRESSION_BOOL_SIGN   "$<AND:$<OR:$<CONFIG:Release>,$<CONFIG:RelWithDebInfo>>,$<BOOL:${ANDROID_KEYSTORE_URL}>,$<BOOL:${ANDROID_KEYSTORE_ALIAS}>>")

set(USE_SYSTEM_ZLIB        ON)

set(CMAKE_RULE_MESSAGES    OFF CACHE BOOL "Whether to report a message for each make rule")
set(CMAKE_TARGET_MESSAGES  OFF CACHE BOOL "Whether to report a message for each target")
set(CMAKE_VERBOSE_MAKEFILE ON  CACHE BOOL "Enable verbose output from Makefile builds")
]]
)
	
	set(make_toolchain_sh [[
set -x
set -e
INSTALL_DIR=$1

test -d "${INSTALL_DIR}.saved" && rm -Rf "${INSTALL_DIR}.saved"
mv "${INSTALL_DIR}" "${INSTALL_DIR}.saved"

bash "]] ${ANDROID_NDK_ROOT} [[/build/tools/make-standalone-toolchain.sh" \
  "--arch=]] ${system_arch_${abi}} [[" \
  "--stl=libcxx" \
  "--platform=]] ${system_platform_${abi}} [[" \
  "--install-dir=${INSTALL_DIR}" \
  "--force"

test -d "${INSTALL_DIR}.new" && rm -Rf "${INSTALL_DIR}.new"
mv "${INSTALL_DIR}" "${INSTALL_DIR}.new"

mv "${INSTALL_DIR}.saved" "${INSTALL_DIR}"
"]] ${CMAKE_COMMAND} [[" -E copy_directory "${INSTALL_DIR}.new" "${INSTALL_DIR}"
rm -Rf "${INSTALL_DIR}.new"
]]
	)
	
	string(REPLACE android-libcxx-@abi@ android-libcxx-${abi} dependencies "${android_toolchain_dependencies}")
	
	string(MD5 md5 "${toolchain}")
	
	superbuild_package(
	  NAME         ${system_name}-toolchain
	  VERSION      ${ANDROID_NDK_VERSION}
	  SYSTEM_NAME  ${system_name}
	  
	  DEPENDS      ${dependencies}
	  
	  SOURCE_WRITE
	    toolchain.cmake   toolchain
	    make_toolchain.sh make_toolchain_sh
	  
	  USING
	    md5
	    install_dir
	    system_name
	    ${system_name}_INSTALL_PREFIX
	    ANDROID_NDK_ROOT
	    ANDROID_NDK_VERSION
	    ANDROID_KEYSTORE_URL
	    ANDROID_KEYSTORE_ALIAS
	  
	  BUILD [[
	    CONFIGURE_COMMAND
	      "${CMAKE_COMMAND}" -E echo "Toolchain config checksum: ${md5}"
	    $<$<NOT:$<AND:$<BOOL:${ANDROID_KEYSTORE_URL}>,$<BOOL:${ANDROID_KEYSTORE_ALIAS}>>>:
	      $<$<OR:$<CONFIG:Release>,$<CONFIG:RelWithDebInfo>>:
	        COMMAND "${CMAKE_COMMAND}" -E echo
	          "You must configure ANDROID_KEYSTORE_URL and ANDROID_KEYSTORE_ALIAS for signing Android release packages."
	      >
	      $<$<CONFIG:Release>:
	        COMMAND false
	      >
	    >
	    BUILD_COMMAND
	      bash "<SOURCE_DIR>/make_toolchain.sh"
	        "${INSTALL_DIR}"
	    INSTALL_COMMAND
	      "${CMAKE_COMMAND}" -E copy_if_different
	        "${SOURCE_DIR}/toolchain.cmake" "${INSTALL_DIR}/toolchain.cmake"
	    COMMAND
	      "${CMAKE_COMMAND}" -E copy_if_different
	        "${ANDROID_NDK_ROOT}/sources/cxx-stl/llvm-libc++/NOTICE"
	        "${install_dir}${${system_name}_INSTALL_PREFIX}/share/doc/copyright/libc++-${ANDROID_NDK_VERSION}.txt"
	  ]]
	)
endforeach()
