# Copyright 2021 Kai Pastor

# https://tracker.debian.org/pkg/base-files

set(VCPKG_POLICY_EMPTY_PACKAGE enabled)

dpkg_from_dsc(
  OUT_SOURCE_PATH source_path
  DSCFILE   base-files_11.1.dsc
  SHA512    4aa64b6a066e71b4edeb68f9640911c83a6b1f9d8f98b93160dbd7b81a18e3a5969986549936df156089cc196e48523c1121f2e8fc131862254f1f8af4ef04eb
  SNAPSHOT  20210411T023434Z
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
