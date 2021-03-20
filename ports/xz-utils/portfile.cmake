# Copyright 2021 Kai Pastor

# https://tracker.debian.org/pkg/xz-utils

dpkg_source_download(
  OUT_ARCHIVES debian
  DSCFILE "xz-utils_5.2.4-1.dsc"
  BASEURLS "https://snapshot.debian.org/archive/debian/20190128T030507Z/pool/main/x/xz-utils"
)

dpkg_source_extract(
  OUT_SOURCE_PATH source_path
  ARCHIVES ${debian}
)

vcpkg_configure_make(
  SOURCE_PATH "${source_path}"
  OPTIONS
    --disable-lzma-links
)

vcpkg_install_make()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

file(INSTALL ${source_path}/debian/copyright
  DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT}
)
