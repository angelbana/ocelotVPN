#
# Sample script to checkout & build 'openconnect' project
# with MINGW64 on MSYS2 toolchain
#
# It should be used only as illustration how to build application
# and create an installer package
#
# (c) 2018-2021, Lubomir Carik
#

SAVE_PWD=$(pwd)
BUILD_DIR="${BUILD_DIR:-build-$MSYSTEM}"

if [ "$MSYSTEM" == "MINGW64" ]; then
    export BUILD_ARCH=x86_64
    export MINGW_PREFIX=/mingw64
    WINTUN_ARCH=amd64
elif [ "$MSYSTEM" == "MINGW32" ]; then
    export BUILD_ARCH=i686
    export MINGW_PREFIX=/mingw32
    WINTUN_ARCH=x86
else
    echo "Unknown MSYS2 build environment..."
    exit -1
fi

export STOKEN_TAG=v0.92
WINTUN_VERSION=0.14.1

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

echo "OpenConnect: $OC_TAG"
echo "stoken: $STOKEN_TAG"
echo "wintun: $WINTUN_VERSION"
echo ""

export OC_URL=https://gitlab.com/openconnect/openconnect.git
export STOKEN_URL=https://github.com/stoken-dev/stoken

echo "======================================================================="
echo " Preparing sandbox..."
echo "======================================================================="

if [ "$STOKEN_TAG" != "v0.92" ]; then
    BUILD_STOKEN=yes
fi
BUILD_STOKEN=${BUILD_STOKEN:-no}

echo "======================================================================="
echo " Installing dependencies..."
echo "======================================================================="

set -e

# jq is asked for by its plain name: MSYS2 no longer builds a mingw-w64 one,
# and the copy in the msys repository is what the signing script runs anyway.
pacman --needed --noconfirm -S \
    git \
    unzip \
    p7zip \
    jq \
    base-devel \
    autotools \
    mingw-w64-x86_64-toolchain \
    mingw-w64-${BUILD_ARCH}-gcc \
    mingw-w64-${BUILD_ARCH}-make \
    mingw-w64-${BUILD_ARCH}-gnutls \
    mingw-w64-${BUILD_ARCH}-libidn2 \
    mingw-w64-${BUILD_ARCH}-libunistring \
    mingw-w64-${BUILD_ARCH}-nettle \
    mingw-w64-${BUILD_ARCH}-gmp \
    mingw-w64-${BUILD_ARCH}-p11-kit \
    mingw-w64-${BUILD_ARCH}-zlib \
    "mingw-w64-${BUILD_ARCH}-libxml2>=2.14" \
    mingw-w64-${BUILD_ARCH}-zlib \
    mingw-w64-${BUILD_ARCH}-lz4 \
    mingw-w64-${BUILD_ARCH}-nsis \
    mingw-w64-${BUILD_ARCH}-libproxy

set +e

[ -d "${BUILD_DIR}" ] || mkdir "${BUILD_DIR}"
cd "${BUILD_DIR}"

#CORES=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || sysctl -n hw.ncpu || echo "$NUMBER_OF_PROCESSORS")
CORES=$(getconf _NPROCESSORS_ONLN)

if [ "x$BUILD_STOKEN" = "xno" ]; then
    echo "======================================================================="
    echo " Installing stoken..."
    echo "======================================================================="
    pacman --needed --noconfirm -S \
        mingw-w64-${BUILD_ARCH}-stoken
else
    echo "======================================================================="
    echo " Building stoken..."
    echo "======================================================================="
    [ -d stoken ] || git clone -b ${STOKEN_TAG} ${STOKEN_URL}
    cd stoken

    git clean -fdx
    git reset --hard ${STOKEN_TAG}

    set -e

    ./autogen.sh

    set +e

    [ -d build-${BUILD_ARCH} ] || mkdir build-${BUILD_ARCH}
    cd build-${BUILD_ARCH}
    set -e
    ../configure --disable-dependency-tracking --without-tomcrypt --without-gtk
    mingw32-make -j${CORES}
    mingw32-make install
    cd ../../
    set +e
fi

echo "======================================================================="
echo " Building openconnect..."
echo "======================================================================="
[ -d openconnect ] || git clone -b ${OC_TAG} ${OC_URL}

set -e
cd openconnect
set +e

git clean -fdx
git reset --hard ${OC_TAG}

set -e
echo "hash:"
git rev-parse --short HEAD | tee ../openconnect-${OC_TAG}_$MSYSTEM.hash

# For openconnect we need wintun locally to avoid downloading
# which is unreliable.
#WINTUNFILE=$(cat Makefile.am|grep ^WINTUNDRIVER |cut -d '=' -f 2|sed 's/^\s//')
#echo "Copying ${WINTUNFILE} for openconnect"
#cp ../../wintun/${WINTUNFILE} .

./autogen.sh
set +e

[ -d build-${BUILD_ARCH} ] || mkdir build-${BUILD_ARCH}
cd build-${BUILD_ARCH}

set -e

#disable libproxy since libproxy >= 0.5 has a lot of dependencies that expand the attack surface
#see https://gitlab.com/openconnect/openconnect-gui/-/merge_requests/259#note_1713843295
#contrib/compat carries a replacement for the sec_api headers, which
#mingw-w64 >= 14 no longer ships; openconnect's compat.c still includes them
CFLAGS="${CFLAGS} -O2 -g -Wno-error=incompatible-pointer-types -I${ROOT_DIR}/contrib/compat" ../configure --disable-dependency-tracking --with-gnutls --without-openssl --without-libpskc --without-libproxy --with-vpnc-script=vpnc-script-win.js

#Make only openconnect.exe; openconnect 12.x fails when generating the nsis installer and
#we do not use the installer or other created artifacts.
mingw32-make -j${CORES} openconnect.exe

#openconnect.pc has the version specified in autoconf
#we want to have the exact version reported by running openconnect --version
#so we hack openconnect.pc a little
sed -i 's|\(Version: \).*|\1'$(cat version.c | sed 's/.* = "v\(.*\)";/\1/')'|' openconnect.pc

cd ../../
set +e

#
# Sample script to create a package from build 'openconnect' project
# incl. all dependencies (hardcoded paths!)
#
echo "======================================================================="
echo " Packaging..."
echo "======================================================================="

rm -rf pkg
mkdir -p pkg/nsis && cd pkg/nsis

set -e

cp ${MINGW_PREFIX}/bin/libffi-8.dll .
cp ${MINGW_PREFIX}/bin/libgcc_*-1.dll .
cp ${MINGW_PREFIX}/bin/libgmp-10.dll .
cp ${MINGW_PREFIX}/bin/libgnutls-30.dll .
cp ${MINGW_PREFIX}/bin/libhogweed-7.dll .
cp ${MINGW_PREFIX}/bin/libintl-8.dll .
cp ${MINGW_PREFIX}/bin/libnettle-9.dll .
cp ${MINGW_PREFIX}/bin/libp11-kit-0.dll .
cp ${MINGW_PREFIX}/bin/libtasn1-6.dll .
cp ${MINGW_PREFIX}/bin/libwinpthread-1.dll .
cp ${MINGW_PREFIX}/bin/libxml2-16.dll .
cp ${MINGW_PREFIX}/bin/zlib1.dll .
cp ${MINGW_PREFIX}/bin/libstoken-1.dll .
cp ${MINGW_PREFIX}/bin/liblz4.dll .
cp ${MINGW_PREFIX}/bin/libiconv-2.dll .
cp ${MINGW_PREFIX}/bin/libunistring-5.dll .
cp ${MINGW_PREFIX}/bin/libidn2-0.dll .
cp ${MINGW_PREFIX}/bin/liblzma-5.dll .
cp ${MINGW_PREFIX}/bin/libbrotlicommon.dll .
cp ${MINGW_PREFIX}/bin/libbrotlidec.dll .
cp ${MINGW_PREFIX}/bin/libzstd.dll .
cp ${MINGW_PREFIX}/bin/libbrotlienc.dll .
cp ../../openconnect/build-${BUILD_ARCH}/.libs/libopenconnect-5.dll .
#cp ../../openconnect/build-${BUILD_ARCH}/.libs/wintun.dll .
cp ../../openconnect/build-${BUILD_ARCH}/.libs/openconnect.exe .

echo "Getting vpnc-script from https://gitlab.com/openconnect/vpnc-scripts/..."

curl --no-progress-meter  -o vpnc-script-win.js https://gitlab.com/openconnect/vpnc-scripts/-/raw/master/vpnc-script-win.js

echo "Extracting wintun.dll..."
unzip -j ${ROOT_DIR}/wintun/wintun-${WINTUN_VERSION}.zip "wintun/bin/${WINTUN_ARCH}/wintun.dll" -d .

cd ../../

set +e


mkdir -p pkg/lib && cd pkg/lib
set -e
cp ${MINGW_PREFIX}/lib/libgmp.dll.a .
cp ${MINGW_PREFIX}/lib/libgnutls.dll.a .
cp ${MINGW_PREFIX}/lib/libhogweed.dll.a .
cp ${MINGW_PREFIX}/lib/libnettle.dll.a .
cp ${MINGW_PREFIX}/lib/libp11-kit.dll.a .
cp ${MINGW_PREFIX}/lib/libxml2.dll.a .
cp ${MINGW_PREFIX}/lib/libz.dll.a .
cp ${MINGW_PREFIX}/lib/libstoken.dll.a .
cp ${MINGW_PREFIX}/lib/liblz4.dll.a .
cp ${MINGW_PREFIX}/lib/libiconv.dll.a .
cp ${MINGW_PREFIX}/lib/libunistring.dll.a .
cp ${MINGW_PREFIX}/lib/libidn2.dll.a .
cp ${MINGW_PREFIX}/lib/liblzma.dll.a .
cp ../../openconnect/build-${BUILD_ARCH}/.libs/libopenconnect.dll.a .

cd ../../
set +e

mkdir -p pkg/lib/pkgconfig && cd pkg/lib/pkgconfig

set -e

cp ${MINGW_PREFIX}/lib/pkgconfig/gnutls.pc .
cp ${MINGW_PREFIX}/lib/pkgconfig/hogweed.pc .
cp ${MINGW_PREFIX}/lib/pkgconfig/libxml-2.0.pc .
cp ${MINGW_PREFIX}/lib/pkgconfig/nettle.pc .
cp ${MINGW_PREFIX}/lib/pkgconfig/zlib.pc .
cp ${MINGW_PREFIX}/lib/pkgconfig/stoken.pc .
cp ../../../openconnect/build-${BUILD_ARCH}/openconnect.pc .
cd ../../../

mkdir -p pkg/include && cd pkg/include
cp -R ${MINGW_PREFIX}/include/gnutls/ .
cp -R ${MINGW_PREFIX}/include/libxml2/ .
cp -R ${MINGW_PREFIX}/include/nettle/ .
cp -R ${MINGW_PREFIX}/include/p11-kit-1/p11-kit/ .
cp ${MINGW_PREFIX}/include/gmp.h .
cp ${MINGW_PREFIX}/include/zconf.h .
cp ${MINGW_PREFIX}/include/zlib.h .
cp ${MINGW_PREFIX}/include/stoken.h .
cp ../../openconnect/openconnect.h .
cd ../../

export MINGW_PREFIX=

cd pkg/nsis
7za a -tzip -mx=9 -sdel ../../openconnect-${OC_TAG}_$MSYSTEM.zip *
cd ../
rmdir -v nsis
7za a -tzip -mx=9 -sdel ../openconnect-devel-${OC_TAG}_$MSYSTEM.zip *
cd ../

set +e

rmdir -v pkg


if [ "x$BUILD_STOKEN" = "xyes" ]; then
    echo "======================================================================="
    echo " Uninstalling system-wide stoken..."
    echo "======================================================================="
    #uninstall stoken; we just build it for the library
    cd stoken/build-${BUILD_ARCH}
    mingw32-make install
    cd ../..
fi

set -e

echo "List of system-wide used packages versions:" \
    > openconnect-${OC_TAG}_$MSYSTEM.txt
echo "openconnect-${OC_TAG}" \
    >> openconnect-${OC_TAG}_$MSYSTEM.txt
echo "stoken-${STOKEN_TAG}" \
    >> openconnect-${OC_TAG}_$MSYSTEM.txt
pacman -Q \
    mingw-w64-${BUILD_ARCH}-gnutls \
    mingw-w64-${BUILD_ARCH}-libidn2 \
    mingw-w64-${BUILD_ARCH}-libunistring \
    mingw-w64-${BUILD_ARCH}-nettle \
    mingw-w64-${BUILD_ARCH}-gmp \
    mingw-w64-${BUILD_ARCH}-p11-kit \
    mingw-w64-${BUILD_ARCH}-libxml2 \
    mingw-w64-${BUILD_ARCH}-zlib \
    mingw-w64-${BUILD_ARCH}-lz4 \
    mingw-w64-${BUILD_ARCH}-libproxy \
    >> openconnect-${OC_TAG}_$MSYSTEM.txt

sha512sum.exe openconnect-${OC_TAG}_$MSYSTEM.zip > openconnect-${OC_TAG}_$MSYSTEM.zip.sha512
sha512sum.exe openconnect-devel-${OC_TAG}_$MSYSTEM.zip > openconnect-devel-${OC_TAG}_$MSYSTEM.zip.sha512

mv -vu openconnect-*.zip openconnect-*.txt openconnect-*.zip.sha512 openconnect-${OC_TAG}_$MSYSTEM.hash ${ROOT_DIR}/external

set +e

cd ${SAVE_PWD}
