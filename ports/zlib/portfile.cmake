# Copyright 2021 Kai Pastor

# https://tracker.debian.org/pkg/zlib
# https://tracker.debian.org/pkg/libz-mingw-w64

dpkg_source_download(
  OUT_ARCHIVES debian
  DSCFILE "libz-mingw-w64_1.2.11+dfsg-2.dsc"
  BASEURLS "https://snapshot.debian.org/archive/debian/20210320T204911Z/pool/main/libz/libz-mingw-w64/"
)

dpkg_source_extract(
  OUT_SOURCE_PATH source_path
  ARCHIVES ${debian}
)

vcpkg_cmake_configure(
  SOURCE_PATH ${source_path}
  PREFER_NINJA
  OPTIONS
    -Wno-dev
    -DSKIP_BUILD_EXAMPLES=ON
  OPTIONS_DEBUG
    -DSKIP_INSTALL_HEADERS=ON
)

cmake_build_install_strip()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

vcpkg_fixup_pkgconfig()

file(INSTALL ${source_path}/debian/copyright
  DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT}
)
