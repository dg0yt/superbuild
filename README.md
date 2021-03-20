This project provides bootstrapping of vcpkg (in the build directory) with
the following customizations:
 - additional patches to the vcpkg tool
 - vcpkg configuration with a local directory as default registry
   (kind: "filesystem") and selected packages from vcpkg.
 - vcpkg commands as cmake build targets, for use in in IDEs and at the
   command line.
   
This project enables using vcpkg with a more strict control over package
recipes and sources. It includes an empty default registry. Via cmake
configuration, users are expected to set the actual default registry.
See CMakeLists.txt for configuration options.

Registries in vcpkg are an experimental feature. For more information, see
vcpkg's "Registries: Take 2" specification: 
https://github.com/microsoft/vcpkg/blob/master/docs/specifications/registries-2.md
