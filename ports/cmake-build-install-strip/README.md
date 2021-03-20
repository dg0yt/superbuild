# cmake-build-install-strip

This port contains a cmake function which calls the cmake build and install
targets via `vcpkg_cmake_build`. It generates separate log files for build
and install step. For release build, the actual install step target is
"install/strip".

## Exported functions

 * `cmake_build_install_strip`

## Synopsis:

~~~
vcpkg_cmake_configure(
  SOURCE_PATH ${source_path}
  PREFER_NINJA
)

cmake_build_install_strip()
~~~
