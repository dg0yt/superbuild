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

function(dpkg_archive_download VAR)
	set(options )
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
	
	string(REGEX REPLACE "(.)$" "\\1/${DPKG_ARCHIVE_FILENAME}" urls ${DPKG_ARCHIVE_BASEURLS})
	
	set(_VCPKG_INTERNAL_NO_HASH_CHECK 1)
	vcpkg_download_distfile(download
	  URLS ${urls}
	  FILENAME "${DPKG_ARCHIVE_FILENAME}"
	  SKIP_SHA512
	)
	
	if(DPKG_ARCHIVE_SIZE)
		file(SIZE "${download}" file_size)
		if(NOT file_size STREQUAL DPKG_ARCHIVE_SIZE)
			message(FATAL_ERROR
			  "\nFile does not have expected size:\n"
			  "        File path: [ ${download} ]\n"
			  "    Expected size: [ ${DPKG_ARCHIVE_SIZE} ]\n"
			  "      Actual size: [ ${file_size} ]\n"
			  "Please delete the file and retry if this file should be downloaded again."
			)
		endif()
	endif()
	
	file(SHA256 "${download}" file_hash)
	if(NOT file_hash STREQUAL DPKG_ARCHIVE_SHA256)
		message(FATAL_ERROR
		  "\nFile does not have expected hash:\n"
		  "        File path: [ ${download} ]\n"
		  "    Expected hash: [ ${DPKG_ARCHIVE_SHA256} ]\n"
		  "      Actual hash: [ ${file_hash} ]\n"
		  "Please delete the file and retry if this file should be downloaded again."
		)
	endif()
	
	set(${VAR} "${download}" PARENT_SCOPE)
endfunction()

function(dpkg_source_download)
	set(options )
	set(oneValueArgs DSCFILE OUT_ARCHIVES OUT_FORMAT)
	set(multipleValuesArgs BASEURLS)
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
		  BASEURLS "${DPKG_DOWNLOAD_BASEURLS}"
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
	set(options )
	set(oneValueArgs OUT_SOURCE_PATH)
	set(multipleValuesArgs ARCHIVES FORMAT)
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
		  PATCHES ${debian_patches}
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
