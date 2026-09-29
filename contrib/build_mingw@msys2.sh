#
# Sample build script & release package preparation for OpenConnect-GUI project
# with MINGW64 on MSYS2 toolchain
#
# It should be used only as illustration how to build application
# and create an installer package
#
# (c) 2016-2021, Lubomir Carik
#

SAVE_PWD=$(pwd)
BUILD_TYPE="${BUILD_TYPE:-Debug}"
BUILD_DIR="${BUILD_DIR:-build-$MSYSTEM/ocelot}"
TARGET="${TARGET:-package}"

if [ -n "${SIGN_EXE}" ];then
EXTRA_BUILD_OPTS="${EXTRA_BUILD_OPTS} -DSIGN_EXE=${SIGN_EXE}"
fi

#root directory is the parent of the directory containing the build script
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd )"

#sanity check for root dir
if [ ! -d ${ROOT_DIR}/external ]; then
    echo "Root Directory not set correctly: ${ROOT_DIR}"
    exit 1
fi

echo "Starting under $MSYSTEM build environment ($ROOT_DIR)..."

if [ "$1" == "--head" ]; then
    export OC_TAG=master
else
    export OC_TAG=v9.12
fi

echo "======================================================================="
echo " Installing Signing dependencies..."
echo "======================================================================="

# jq is asked for by its plain name: MSYS2 no longer builds a mingw-w64 one,
# and the copy in the msys repository is what the signing script runs anyway.
pacman --needed --noconfirm -S \
	zip \
	unzip \
	coreutils \
	jq \
	mingw-w64-x86_64-curl

if [ -z "$QT6" ];then
    echo "======================================================================="
    echo " Installing CMake / QT6 dependencies..."
    echo "======================================================================="

    pacman --needed --noconfirm -S \
        mingw-w64-x86_64-cmake \
        mingw-w64-x86_64-nsis \
        mingw-w64-x86_64-qt6-base \
        mingw-w64-x86_64-qt6-declarative
fi

echo "======================================================================="
echo " Preparing sandbox..."
echo "======================================================================="
[ -d "${BUILD_DIR}" ] || mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

set -e

echo "======================================================================="
echo " Generating project..."
echo "======================================================================="
cmake -G "MinGW Makefiles" \
    -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
    -Dopenconnect-TAG=${OC_TAG} \
    ${EXTRA_BUILD_OPTS} \
    -S ${ROOT_DIR} -B .

echo "======================================================================="
echo " Compiling..."
echo "======================================================================="
CORES=$(getconf _NPROCESSORS_ONLN)
cmake --build . --config "$BUILD_TYPE" -- -j${CORES}

echo "======================================================================="
echo " Packaging..."
echo "======================================================================="
cmake --build . --config "$BUILD_TYPE" --target ${TARGET} -- -j${CORES}

if [ "${SIGN_EXE}" = "true" ];then
    set -e
    for file in ocelot*.exe;do
	if [[ $file != ocelot*signed*.exe ]]; then
            ${ROOT_DIR}/contrib/sign.sh "${file}"
            sha512sum "${file}" > "${file}.sha512"
        fi
    done
    set +e
fi

cd ${SAVE_PWD}
