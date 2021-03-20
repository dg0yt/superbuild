# Copyright 2021 Kai Pastor

# https://tracker.debian.org/pkg/zlib
# https://tracker.debian.org/pkg/libz-mingw-w64

dpkg_from_dsc(
  OUT_SOURCE_PATH source_path
  DSCFILE   "libz-mingw-w64_1.2.11+dfsg-2.dsc"
  SHA512    9cc7ed7147210fadb35f2ecf0eaf24c86cbcf6c1cd332dda32d901d14321555a37b2d364c5eee68bd822d46eaad9837fa10fce9d65b7aad2567a20be274e5d6f
  SNAPSHOT  20210320T204911Z
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

vcpkg_cmake_install()
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

file(INSTALL "${source_path}/debian/copyright"
  DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)
