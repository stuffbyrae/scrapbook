#!/bin/sh

mkdir -p build
cd build
cmake -DCMAKE_TOOLCHAIN_FILE="../../PlaydateSDK/C_API/buildsupport/arm.cmake" --fresh ..
make
cd ..