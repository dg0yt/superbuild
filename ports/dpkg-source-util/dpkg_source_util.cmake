# Copyright 2021 Kai Pastor

if(Z_DPKG_SOURCE_UTIL_INSTALL_GUARD)
	return()
endif()
set(Z_DPKG_SOURCE_UTIL_INSTALL_GUARD ON CACHE INTERNAL "include guard")

function(debian_get_patches var archive)
	set(patches )
	set(series )
	if (EXISTS "${archive}/patches/series")
		file(STRINGS "${archive}/patches/series" series)
	endif()
	foreach(line ${series})
		string(STRIP "${line}" line)
		if(NOT line MATCHES "^#")
			list(APPEND patches "${line}")
		endif()
	endforeach()
	set(${var} ${patches} PARENT_SCOPE)
endfunction()

function(dpkg_check_archive)
	set(options SILENT_EXIT)
	set(oneValueArgs OUT_RESULT FILENAME SHA256 SIZE)
	set(multipleValuesArgs "")
	cmake_parse_arguments(PARSE_ARGV 0 DCA "${options}" "${oneValueArgs}" "${multipleValuesArgs}")
	
	if(NOT DEFINED DCA_FILENAME)
		message(FATAL_ERROR "dpkg_check_archive requires a FILENAME argument.")
	endif()
	if(NOT DEFINED DCA_SHA256)
		message(FATAL_ERROR "dpkg_check_archive requires a SHA256 argument.")
	endif()
	if(DCA_SILENT_EXIT AND NOT DEFINED DCA_OUT_RESULT)
		message(FATAL_ERROR "dpkg_check_archive requires a an OUT_RESULT argument when SILENT_EXIT is used.")
	endif()

	if(DCA_SILENT_EXIT)
		set(message_class STATUS)
	else()
		set(message_class FATAL_ERROR)
	endif()
	
	set(result TRUE)
	if(DCA_SIZE)
		file(SIZE "${download}" file_size)
		if(NOT file_size STREQUAL DCA_SIZE)
			message(${message_class}
			  "File does not have expected size:\n"
			  "        File path: [ ${download} ]\n"
			  "    Expected size: [ ${DCA_SIZE} ]\n"
			  "      Actual size: [ ${file_size} ]"
			)
			set(result FALSE)
		endif()
	endif()
	
	file(SHA256 "${download}" file_hash)
	if(NOT file_hash STREQUAL DCA_SHA256)
		message(${message_class}
		  "File does not have expected hash:\n"
		  "        File path: [ ${download} ]\n"
		  "    Expected hash: [ ${DCA_SHA256} ]\n"
		  "      Actual hash: [ ${file_hash} ]"
		)
		set(result FALSE)
	endif()

	if(DCA_OUT_RESULT)
		set(${DCA_OUT_RESULT} "${result}" PARENT_SCOPE)
	endif()
endfunction()

function(dpkg_archive_download VAR)
	set(options "")
	set(oneValueArgs FILENAME SHA256 SIZE)
	set(multipleValuesArgs BASEURLS)
	cmake_parse_arguments(PARSE_ARGV 1 DPKG_ARCHIVE "${options}" "${oneValueArgs}" "${multipleValuesArgs}")
	
	if(NOT DEFINED DPKG_ARCHIVE_FILENAME)
		message(FATAL_ERROR "dpkg_archive_download requires a FILENAME argument.")
	endif()
	if(NOT DEFINED DPKG_ARCHIVE_BASEURLS)
		message(FATAL_ERROR "dpkg_archive_download requires a BASEURLS argument.")
	endif()
	if(NOT DEFINED DPKG_ARCHIVE_SHA256)
		message(FATAL_ERROR "dpkg_archive_download requires a SHA256 argument.")
	endif()
	
	list(TRANSFORM DPKG_ARCHIVE_BASEURLS
	  APPEND "${DPKG_ARCHIVE_FILENAME}"
	  OUTPUT_VARIABLE urls
	)
	
	# Two attempts in order to avoid assumptions about download location.
	set(_VCPKG_INTERNAL_NO_HASH_CHECK 1)
	foreach(check_arg IN ITEMS "SILENT_EXIT" "")
		vcpkg_download_distfile(download
		  URLS ${urls}
		  FILENAME "${DPKG_ARCHIVE_FILENAME}"
		  SKIP_SHA512
		)
		dpkg_check_archive(
		  FILENAME   "${download}"
		  SHA256     "${DPKG_ARCHIVE_SHA256}"
		  SIZE       "${DPKG_ARCHIVE_SIZE}"
		  OUT_RESULT success
		  ${check_arg}
		)
		if(NOT success AND EXISTS "${download}")
			message(STATUS "Removing invalid '${download}'.")
			file(REMOVE "${download}")
		endif()
	endforeach()
	set(${VAR} "${download}" PARENT_SCOPE)
endfunction()

function(dpkg_source_download)
	set(options "")
	set(oneValueArgs DSCFILE OUT_ARCHIVES OUT_FORMAT VENDOR)
	set(multipleValuesArgs BASEURLS PATCHES)
	cmake_parse_arguments(PARSE_ARGV 0 DPKG_DOWNLOAD "${options}" "${oneValueArgs}" "${multipleValuesArgs}")
	
	if(NOT DEFINED DPKG_DOWNLOAD_OUT_ARCHIVES)
		message(FATAL_ERROR "dpkg_source_download requires an OUT_ARCHIVES argument.")
	endif()
	if(NOT DEFINED DPKG_DOWNLOAD_DSCFILE)
		message(FATAL_ERROR "dpkg_source_download requires a DSCFILE argument.")
	endif()
	if(NOT DEFINED DPKG_DOWNLOAD_BASEURLS)
		message(FATAL_ERROR "dpkg_source_download requires a BASEURLS argument.")
	endif()
	
	get_filename_component(file "${DPKG_DOWNLOAD_DSCFILE}" ABSOLUTE BASE_DIR "${CURRENT_PORT_DIR}")
	file(STRINGS "${file}" lines)
	
	set(in_checksums FALSE)
	set(archives )
	set(downloads )
	set(format )
	foreach(line IN LISTS lines)
		if(line MATCHES "^Format: *(.*[^ ]) *$")
			set(format "${CMAKE_MATCH_1}")
		elseif(line MATCHES "^Checksums-Sha256:")
			set(in_checksums TRUE)
		elseif(in_checksums AND line MATCHES "^ ")
			list(APPEND archives "${line}")
		elseif(in_checksums)
			break()
		endif()
	endforeach()
	foreach(archive IN LISTS archives)
		string(REGEX MATCH "^ *([^ ]*)  *([^ ]*)  *([^ ]*)" unused "${archive}")
		dpkg_archive_download(download
		  BASEURLS ${DPKG_DOWNLOAD_BASEURLS}
		  SHA256   "${CMAKE_MATCH_1}"
		  SIZE     "${CMAKE_MATCH_2}"
		  FILENAME "${CMAKE_MATCH_3}"
		)
		list(APPEND downloads "${download}")
	endforeach()
	
	set(${DPKG_DOWNLOAD_OUT_ARCHIVES} "${downloads}" PARENT_SCOPE)
	if(DEFINED DPKG_DOWNLOAD_OUT_FORMAT)
		set(${DPKG_DOWNLOAD_OUT_FORMAT} "${format}" PARENT_SCOPE)
	endif()
endfunction()

# Cf. dpkg-source -x,
# Cf. https://manpages.debian.org/testing/dpkg-dev/dpkg-source.1.en.html
function(dpkg_source_extract)
	set(options "")
	set(oneValueArgs OUT_SOURCE_PATH)
	set(multipleValuesArgs ARCHIVES FORMAT PATCHES)
	cmake_parse_arguments(PARSE_ARGV 0 DPKG_SOURCE "${options}" "${oneValueArgs}" "${multipleValuesArgs}")
	
	if(NOT DEFINED DPKG_SOURCE_OUT_SOURCE_PATH)
		message(FATAL_ERROR "dpkg_source_extract requires an OUT_SOURCE_PATH argument.")
	endif()
	if(NOT DEFINED DPKG_SOURCE_ARCHIVES)
		message(FATAL_ERROR "dpkg_source_extract requires an ARCHIVES argument.")
	endif()
	if(NOT DEFINED DPKG_SOURCE_FORMAT)
		set(DPKG_SOURCE_FORMAT "3.0 (quilt)")  # Reasonable default
	endif()
	
	# Unsupported: detached upstream signature
	list(FILTER DPKG_SOURCE_ARCHIVES EXCLUDE REGEX "\\.asc$")
	
	if(DPKG_SOURCE_FORMAT STREQUAL "3.0 (native)")
		set(orig_component "${DPKG_SOURCE_ARCHIVES}")
		list(FILTER orig_component INCLUDE REGEX "\\.tar\\.")
		list(FILTER DPKG_SOURCE_ARCHIVES EXCLUDE REGEX "\\.tar\\.")
		vcpkg_extract_source_archive_ex(
		  OUT_SOURCE_PATH root
		  ARCHIVE ${orig_component}
		  REF "orig"
		)
	elseif(DPKG_SOURCE_FORMAT STREQUAL "3.0 (quilt)")
		foreach(component "orig" "debian")
			set(${component}_component "${DPKG_SOURCE_ARCHIVES}")
			list(FILTER ${component}_component INCLUDE REGEX "\\.${component}\\.tar\\.")
			list(FILTER DPKG_SOURCE_ARCHIVES EXCLUDE REGEX "\\.${component}\\.tar\\.")
		endforeach()
		
		vcpkg_extract_source_archive_ex(
		  OUT_SOURCE_PATH debian
		  ARCHIVE ${debian_component}
		  REF "debian"
		)
		debian_get_patches(debian_patches ${debian})
		vcpkg_extract_source_archive_ex(
		  OUT_SOURCE_PATH root
		  ARCHIVE ${orig_component}
		  REF "orig"
		  PATCHES ${debian_patches} ${DPKG_SOURCE_PATCHES}
		)
		if(EXISTS "${root}/debian")
			file(REMOVE_RECURSE "${root}/debian")
		endif()
		file(RENAME "${debian}" "${root}/debian")
	else()
		message(FATAL_ERROR "Unsupported source package format: ${DPKG_SOURCE_FORMAT}")
	endif()
	
	if(DPKG_SOURCE_ARCHIVES)
		message(WARNING "Unhandled sidecar files: ${DPKG_SOURCE_ARCHIVES}")
	endif()
	
	set(${DPKG_SOURCE_OUT_SOURCE_PATH} "${root}" PARENT_SCOPE)
endfunction()

#[===[
# dpkg_from_dsc

Download and cache a a dsc file and all files it references.

## Usage
```cmake
dpkg_from_dsc(
    OUT_SOURCE_PATH <OUT_VARIABLE>
    DSCFILE <pkg_1.0.1-1.dsc>
    SHA512 <5981de...>
    COMPONENT <main>
    SNAPSHOT <20190128T030507Z>
    PATCHES <relocatable.patch>
)
```
## Parameters
### OUT_SOURCE_PATH
This variable will be set to the full path to the extracted and patched archive.
The result can then immediately be passed in to `vcpkg_cmake_configure` etc.

### DSCFILE
The name of the dsc file.

### SHA512
The expected hash for the dsc file.

If this doesn't match the downloaded version, the build will be terminated with a message describing the mismatch.

### COMPONENT
The component of the Debian distribution where the package is found (`main`, `contrib` or `non-free`).
If unset, the default value is `main`.

### BASE_URLS
Provide base URLs which should be tried first.

These URLs must be complete including trailing slash so that only the filename needs to be appended.

### NO_DEFAULT_URLS
This flag disables the download from the standard Debian servers.

Use this option when the package is not or no longer in a current Debian distribution.

### SNAPSHOT
The timestamp/directory of snapshots.debian.org where this package can be found
even when it is no longer on the regular debian servers.
If set, the snapshot service is used when the package is no longer available on the main servers.

### PATCHES
A list of patches to be applied to the extracted sources in addition to Debian's patches

Relative paths are based on the port directory.

]===]
function(dpkg_from_dsc)
	set(options NO_DEFAULT_URLS)
	set(oneValueArgs OUT_SOURCE_PATH DSCFILE SHA512 COMPONENT SNAPSHOT)
	set(multipleValuesArgs BASE_URLS PATCHES)
	cmake_parse_arguments(PARSE_ARGV 0 DPKG_FROM_DSC "${options}" "${oneValueArgs}" "${multipleValuesArgs}")
	
	if(NOT DEFINED DPKG_FROM_DSC_OUT_SOURCE_PATH)
		message(FATAL_ERROR "dpkg_from_dsc requires an OUT_SOURCE_PATH argument.")
	endif()
	if(NOT DEFINED DPKG_FROM_DSC_DSCFILE)
		message(FATAL_ERROR "dpkg_from_dsc requires an DSCFILE argument.")
	endif()
	if(NOT DEFINED DPKG_FROM_DSC_SHA512)
		message(FATAL_ERROR "dpkg_from_dsc requires an SHA512 argument.")
	endif()

	if(NOT DEFINED DPKG_FROM_DSC_COMPONENT)
		set(DPKG_FROM_DSC_COMPONENT "main")
	endif()

	string(REGEX REPLACE "^(lib[a-z0-9]|[a-z0-9]).*" "\\1" dir "${DPKG_FROM_DSC_DSCFILE}")
	string(REGEX REPLACE "^([^_]+)_.*" "\\1" package "${DPKG_FROM_DSC_DSCFILE}")
	set(subpath "${DPKG_FROM_DSC_COMPONENT}/${dir}/${package}")
	
	set(base_urls "")
	if(DCI_BASE_URLS)
		list(APPEND base_urls ${DCI_BASE_URLS})
	endif()
	if(NOT DCI_NO_DEFAULT_URLS)
		list(APPEND "https://ftp.debian.org/debian/pool/${subpath}/")
	endif()
	if(DPKG_FROM_DSC_SNAPSHOT)
		list(APPEND base_urls "https://snapshot.debian.org/archive/debian/${DPKG_FROM_DSC_SNAPSHOT}/pool/${subpath}/")
	endif()

	foreach(base_url IN LISTS base_urls)
		set(dsc_file FALSE)
		vcpkg_download_distfile(dsc_file
		  URLS "${base_url}/${DPKG_FROM_DSC_DSCFILE}"
		  FILENAME "${DPKG_FROM_DSC_DSCFILE}"
		  SHA512 "${DPKG_FROM_DSC_SHA512}"
		  SILENT_EXIT
		)
		if(dsc_file)
			break()
		else()
			list(REMOVE_ITEM base_urls "${base_url}")
		endif()
	endforeach()
	if(NOT dsc_file)
		message(FATAL_ERROR "Unable to download '${DPKG_FROM_DSC_DSCFILE}' from ${base_urls}.")
	endif()
	dpkg_source_download(
	  OUT_ARCHIVES archives
	  OUT_FORMAT format
	  DSCFILE "${dsc_file}"
	  BASEURLS ${base_urls}
	)
	dpkg_source_extract(
	  OUT_SOURCE_PATH root
	  ARCHIVES ${archives}
	  FORMAT  "${format}"
	  PATCHES ${DPKG_FROM_DSC_PATCHES}
	)
	set(${DPKG_FROM_DSC_OUT_SOURCE_PATH} "${root}" PARENT_SCOPE)
endfunction()

