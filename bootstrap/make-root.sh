#!/bin/sh

# Copyright 2021 Kai Pastor <dg0yt@darc.de>

# This scripts operates in the current working directory and creates a
# vcpkg root configured to use the versions and ports in the directory
# passed via the first parameter as default registry, together with
# selected packages from Microsofts registry which either is found in
# VCPKG_INSTALLATION_ROOT, or will be cloned from
# https://github.com/microsoft/vcpkg.git

set -e

if [ ! -d "$1" ]; then
    echo "The first argument must be the absolute path of the default vcpkg filesystem registry."
    exit 1
fi

if [ -z "${VCPKG_INSTALLATION_ROOT}" ]; then
    echo "VCPKG_INSTALLATION_ROOT is empty."
    VCPKG_INSTALLATION_ROOT="${PWD}/vcpkg-root"
    echo "Using ${VCPKG_INSTALLATION_ROOT}"
    if [ ! -d "${VCPKG_INSTALLATION_ROOT}" ]; then
        git -c init.defaultBranch=main clone "https://github.com/microsoft/vcpkg.git" vcpkg-root
    fi
fi

test -e scripts || ln -s "${VCPKG_INSTALLATION_ROOT}/scripts" .
test -e triplets || ln -s "${VCPKG_INSTALLATION_ROOT}/triplets" .

cat > vcpkg-configuration.json <<END_CONFIG
{
  "default-registry": {
    "kind": "filesystem",
    "path": "$1"
  },
  "registries": [
    {
      "kind": "git",
      "repository": "${VCPKG_INSTALLATION_ROOT}",
      "packages": [ "vcpkg-cmake", "vcpkg-cmake-config", "libiconv" ]
    }
  ]
}
END_CONFIG

echo "Set VCPKG_ROOT=\"${PWD}\" before using vcpkg."

