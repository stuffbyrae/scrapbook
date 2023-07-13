#!/bin/zsh

cd build
cmake -DCMAKE_TOOLCHAIN_FILE="$PLAYDATE_SDK_PATH/C_API/buildsupport/arm.cmake" --fresh ..
# cmake --fresh ..
make
cd ..