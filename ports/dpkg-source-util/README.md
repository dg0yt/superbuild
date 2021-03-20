# dpkg-source-util

This port contains cmake functions for dealing with Debian source packages,
leveraging .dsc files, source tarballs, patches and debian/copyright.

## Exported functions

 * `dpkg_source_download`
 * `dpkg_source_extract`

## Synopsis:

~~~
dpkg_source_download(
  OUT_ARCHIVES debian
  DSCFILE "xz-utils_5.2.4-1.dsc"
  BASEURLS "https://snapshot.debian.org/archive/debian/20190128T030507Z/pool/main/x/xz-utils"
)

dpkg_source_extract(
  OUT_SOURCE_PATH source_path
  ARCHIVES ${debian}
)

# Configure and build <source_path> as usual.

file(INSTALL ${source_path}/debian/copyright
  DESTINATION ${CURRENT_PACKAGES_DIR}/share/xz-utils
)
~~~
