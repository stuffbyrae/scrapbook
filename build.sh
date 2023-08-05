#!/bin/sh

mkdir -p build
cd build
cmake -DCMAKE_TOOLCHAIN_FILE="$PLAYDATE_SDK_PATH/C_API/buildsupport/arm.cmake" --fresh ..
make
cd ..