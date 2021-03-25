#!/bin/sh

# Copyright 2021 Kai Pastor <dg0yt@darc.de>

# This scripts builds the vcpkg tool from source with selected patches
# and moves the resulting binary to the current working directory.

set -e

mkdir -p vcpkg-tool
cd vcpkg-tool
git -c init.defaultBranch=main init .
git fetch https://github.com/microsoft/vcpkg-tool.git main
git checkout FETCH_HEAD
git fetch https://github.com/dg0yt/vcpkg-tool.git shallow-registries
git merge --no-ff --no-edit FETCH_HEAD
cmake . -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=0 -DVCPKG_ALLOW_APPLE_CLANG=1
cmake --build .
cd ..
if [ -e vcpkg-tool/vcpkg.exe ]; then
    cp vcpkg-tool/vcpkg.exe .
elif [ -e vcpkg-tool/vcpkg ]; then
    cp vcpkg-tool/vcpkg .
else
    echo "Failed to create vcpkg tool."
    false
fi

