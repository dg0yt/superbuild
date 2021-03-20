# Copyright 2021 Kai Pastor

# https://tracker.debian.org/pkg/base-files

dpkg_source_download(
  OUT_FORMAT format
  OUT_ARCHIVES debian
  DSCFILE "base-files_11.dsc"
  BASEURLS "https://snapshot.debian.org/archive/debian/20190709T152105Z/pool/main/b/base-files/"
)

dpkg_source_extract(
  OUT_SOURCE_PATH source_path
  FORMAT   ${format}
  ARCHIVES ${debian}
)

file(GLOB files "${source_path}/licenses/*")
foreach(file ${files})
	get_filename_component(filename "${file}" NAME)
	file(
	  INSTALL "${file}"
	  DESTINATION ${CURRENT_PACKAGES_DIR}/share/common-licenses
	)
endforeach()

file(
  INSTALL "${CMAKE_CURRENT_LIST_DIR}/copyright"
  DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)

set(VCPKG_POLICY_EMPTY_PACKAGE enabled)
