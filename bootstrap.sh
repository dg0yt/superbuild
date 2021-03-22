#!/bin/sh

# Copyright 2021 Kai Pastor <dg0yt@darc.de>

set -e

if [ ! -d "$1" ]; then
    echo "The first argument must be the absolute path of the default vcpkg filesystem registry."
    exit 1
fi

if [ -z "${VCPKG_INSTALLATION_ROOT}" ]; then
    VCPKG_INSTALLATION_ROOT="${PWD}/vcpkg-root"
    if [ ! -d "${VCPKG_INSTALLATION_ROOT}" ]; then
        git clone "https://github.com/microsoft/vcpkg.git" vcpkg-root
    fi
fi

mkdir -p vcpkg-tool
cd vcpkg-tool
git init .
git fetch https://github.com/microsoft/vcpkg-tool.git main
git checkout FETCH_HEAD
git fetch https://github.com/dg0yt/vcpkg-tool.git registry-packages
git merge --no-ff --no-edit FETCH_HEAD
git fetch https://github.com/dg0yt/vcpkg-tool.git shallow-registries
git merge --no-ff --no-edit FETCH_HEAD
cmake . -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=0 -DVCPKG_ALLOW_APPLE_CLANG=1
cmake --build .
cd ..

test -e scripts || ln -s "${VCPKG_INSTALLATION_ROOT}/scripts" .
test -e triplets || ln -s "${VCPKG_INSTALLATION_ROOT}/triplets" .
if [ -f vcpkg-tool/vcpkg.exe ]; then
    test -e vcpkg.exe || ln -s vcpkg-tool/vcpkg.exe .
else
    test -e vcpkg || ln -s vcpkg-tool/vcpkg .
fi

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

echo "Set VCPKG_ROOT=\"${PWD}\" before using ${PWD}/vcpkg"

