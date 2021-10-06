#!/bin/sh -e

# value from: https://musl.cc/ (without -cross or -native)
export CROSS_HOST="${CROSS_HOST:-arm-linux-musleabi}"
# value from openssl source: ./Configure LIST
case "${CROSS_HOST}" in
arm-linux*)
  export OPENSSL_COMPILER=linux-armv4
  ;;
aarch64-linux*)
  export OPENSSL_COMPILER=linux-aarch64
  ;;
mips-linux* | mipsel-linux*)
  export OPENSSL_COMPILER=linux-mips32
  ;;
mips64-linux*)
  export OPENSSL_COMPILER=linux64-mips64
  ;;
x86_64-linux*)
  export OPENSSL_COMPILER=linux-x86_64
  ;;
*)
  export OPENSSL_COMPILER=gcc
  ;;
esac
export CROSS_ROOT="${CROSS_ROOT:-/cross_root}"
export USE_ZLIB_NG="${USE_ZLIB_NG:-1}"
if [ ! "${CI}" = true ]; then
  sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/' /etc/apk/repositories
fi
apk add g++ \
  git \
  make \
  libtool \
  tar \
  jq \
  pkgconfig \
  file \
  perl \
  tcl \
  autoconf \
  automake \
  patch \
  gettext-dev \
  ca-certificates-bundle
mkdir -p "${CROSS_ROOT}" /usr/src/zlib \
  /usr/src/zlib-ng \
  /usr/src/xz \
  /usr/src/openssl \
  /usr/src/libressl \
  /usr/src/libxml2 \
  /usr/src/sqlite \
  /usr/src/c-ares \
  /usr/src/libssh2 \
  /usr/src/libuv \
  /usr/src/jemalloc \
  /usr/src/aria2

TARGET_ARCH="${CROSS_HOST%%-*}"
TARGET_HOST="${CROSS_HOST#*-}"
case "${TARGET_ARCH}" in
"armel"*)
  TARGET_ARCH=armel
  ;;
"arm"*)
  TARGET_ARCH=arm
  ;;
esac
case "${TARGET_HOST}" in
*"mingw"*)
  TARGET_HOST=win
  apk add wine
  export WINEPREFIX=/tmp/
  RUNNER_CHECKER="wine64"
  ;;
*)
  TARGET_HOST=linux
  apk add "qemu-${TARGET_ARCH}"
  RUNNER_CHECKER="qemu-${TARGET_ARCH}"
  ;;
esac

export PATH="${CROSS_ROOT}/bin:${PATH}"
export CROSS_PREFIX="${CROSS_ROOT}/${CROSS_HOST}"
export PKG_CONFIG_PATH="${CROSS_PREFIX}/lib64/pkgconfig:${CROSS_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}"
export LDFLAGS="-L${CROSS_PREFIX}/lib64 -L${CROSS_PREFIX}/lib -s -static --static"
SELF_DIR="$(dirname "$(realpath "${0}")")"
BUILD_INFO="${SELF_DIR}/build_info.md"

echo "## Build Info - ${CROSS_HOST}" >"${BUILD_INFO}"
echo "Building using these dependencies:" >>"${BUILD_INFO}"

# toolchain
[ ! -f "${SELF_DIR}/${CROSS_HOST}-cross.tgz" ] && wget -c -O "${SELF_DIR}/${CROSS_HOST}-cross.tgz" "https://musl.cc/${CROSS_HOST}-cross.tgz"
tar -axf "${SELF_DIR}/${CROSS_HOST}-cross.tgz" --transform='s|^\./||S' --strip-components=1 -C "${CROSS_ROOT}"

# zlib
if [ x"${USE_ZLIB_NG}" = x"1" ]; then
  if [ ! -f "${SELF_DIR}/zlib-ng.tar.gz" ]; then
    zlib_ng_latest_url="$(wget -qO- https://api.github.com/repos/zlib-ng/zlib-ng/releases | jq -r '.[0].tarball_url')"
    wget -c -O "${SELF_DIR}/zlib-ng.tar.gz" "${zlib_ng_latest_url}"
  fi
  tar -zxf "${SELF_DIR}/zlib-ng.tar.gz" --strip-components=1 -C /usr/src/zlib-ng
  cd /usr/src/zlib-ng
  CHOST="${CROSS_HOST}" ./configure --prefix="${CROSS_PREFIX}" --static --zlib-compat
  make -j$(nproc)
  make install
  zlib_ng_ver="$(grep Version: "${CROSS_PREFIX}/lib/pkgconfig/zlib.pc")"
  echo "- zlib-ng: ${zlib_ng_ver}, source: ${zlib_ng_latest_url:-cached zlib-ng}" >>"${BUILD_INFO}"
  # Fix mingw build sharedlibdir lost issue
  sed -i 's@^sharedlibdir=.*@sharedlibdir=${libdir}@' "${CROSS_PREFIX}/lib/pkgconfig/zlib.pc"
else
  if [ ! -f "${SELF_DIR}/zlib.tar.gz" ]; then
    zlib_latest_url="$(wget -qO- https://zlib.net/ | grep -i '\s*<a href=".*"$' | sed -n 2p | awk -F'"' '{print $2}')"
    wget -c -O "${SELF_DIR}/zlib.tar.gz" "${zlib_latest_url}"
  fi
  tar -zxf "${SELF_DIR}/zlib.tar.gz" --strip-components=1 -C /usr/src/zlib
  cd /usr/src/zlib
  if [ x"${TARGET_HOST}" = xwin ]; then
    make -f win32/Makefile.gcc BINARY_PATH="${CROSS_PREFIX}/bin" INCLUDE_PATH="${CROSS_PREFIX}/include" LIBRARY_PATH="${CROSS_PREFIX}/lib" SHARED_MODE=0 PREFIX="${CROSS_HOST}-" -j$(nproc) install
  else
    CHOST="${CROSS_HOST}" ./configure --prefix="${CROSS_PREFIX}" --static
    make -j$(nproc)
    make install
  fi
  zlib_ver="$(grep Version: "${CROSS_PREFIX}/lib/pkgconfig/zlib.pc")"
  echo "- zlib: ${zlib_ver}, source: ${zlib_latest_url:-cached zlib}" >>"${BUILD_INFO}"
fi

# xz
if [ ! -f "${SELF_DIR}/xz.tar.gz" ]; then
  xz_latest_url="https://sourceforge.net/projects/lzmautils/files/latest/download"
  wget -c -O "${SELF_DIR}/xz.tar.gz" "${xz_latest_url}"
fi
tar -zxf "${SELF_DIR}/xz.tar.gz" --strip-components=1 -C /usr/src/xz
cd /usr/src/xz
./configure --host="${CROSS_HOST}" --prefix="${CROSS_PREFIX}" --enable-silent-rules --enable-static --disable-shared
make -j$(nproc)
make install
xz_ver="$(grep Version: "${CROSS_PREFIX}/lib/pkgconfig/liblzma.pc")"
echo "- xz: ${xz_ver}, source: ${xz_latest_url:-cached xz}" >>"${BUILD_INFO}"

# Windows will use Wintls, not openssl
if [ x"${TARGET_HOST}" != xwin ]; then
  if [ x"${USE_LIBRESSL}" = x1 ]; then
    # libressl
    if [ ! -f "${SELF_DIR}/libressl.tar.gz" ]; then
      libressl_filename="$(wget -qO- https://cdn.openbsd.org/pub/OpenBSD/LibreSSL/ | grep -o 'href="libressl-.*tar.gz"' | tail -1 | grep -o '[^"]*.tar.gz')"
      libressl_latest_url="https://cdn.openbsd.org/pub/OpenBSD/LibreSSL/${libressl_filename}"
      # libressl_latest_url="https://github.com/libressl-portable/portable/archive/refs/heads/master.tar.gz"
      wget -c -O "${SELF_DIR}/libressl.tar.gz" "${libressl_latest_url}"
    fi
    tar -zxf "${SELF_DIR}/libressl.tar.gz" --strip-components=1 -C /usr/src/libressl
    cd /usr/src/libressl
    if [ ! -f "./configure" ]; then
      ./autogen.sh
    fi
    ./configure --host="${CROSS_HOST}" --prefix="${CROSS_PREFIX}" --enable-silent-rules --enable-static --disable-shared
    make -j$(nproc)
    make install_sw
    libressl_ver="$(grep Version: "${CROSS_PREFIX}/lib/pkgconfig/openssl.pc")"
    echo "- libressl: ${libressl_ver}, source: ${libressl_latest_url:-cached libressl}" >>"${BUILD_INFO}"
  else
    # openssl
    if [ ! -f "${SELF_DIR}/openssl.tar.gz" ]; then
      openssl_filename="$(wget -qO- https://www.openssl.org/source/ | grep -o 'href="openssl-3.*tar.gz"' | grep -o '[^"]*.tar.gz')"
      openssl_latest_url="https://www.openssl.org/source/${openssl_filename}"
      wget -c -O "${SELF_DIR}/openssl.tar.gz" "${openssl_latest_url}"
    fi
    tar -zxf "${SELF_DIR}/openssl.tar.gz" --strip-components=1 -C /usr/src/openssl
    cd /usr/src/openssl
    ./Configure -static --cross-compile-prefix="${CROSS_HOST}-" --prefix="${CROSS_PREFIX}" "${OPENSSL_COMPILER}"
    make -j$(nproc)
    make install_sw
    openssl_ver="$(grep Version: "${CROSS_PREFIX}"/lib*/pkgconfig/openssl.pc)"
    echo "- openssl: ${openssl_ver}, source: ${openssl_latest_url:-cached openssl}" >>"${BUILD_INFO}"
  fi
fi

# libxml2
if [ ! -f "${SELF_DIR}/libxml2.tar.gz" ]; then
  libxml2_latest_url="http://xmlsoft.org/sources/LATEST_LIBXML2"
  wget -c -O "${SELF_DIR}/libxml2.tar.gz" "${libxml2_latest_url}"
fi
tar -zxf "${SELF_DIR}/libxml2.tar.gz" --strip-components=1 -C /usr/src/libxml2
cd /usr/src/libxml2
CC="${CROSS_HOST}-gcc" ./configure --host="${CROSS_HOST%-musl*}" --prefix="${CROSS_PREFIX}" --enable-silent-rules --without-python --without-icu --enable-static --disable-shared
make -j$(nproc)
make install
libxml2_ver="$(grep Version: "${CROSS_PREFIX}/lib/pkgconfig/"libxml-*.pc)"
echo "- libxml2: ${libxml2_ver}, source: ${libxml2_latest_url:-cached libxml2}" >>"${BUILD_INFO}"

# sqlite
if [ ! -f "${SELF_DIR}/sqlite.tar.gz" ]; then
  sqlite_latest_url="https://github.com/sqlite/sqlite/archive/release.tar.gz"
  wget -c -O "${SELF_DIR}/sqlite.tar.gz" "${sqlite_latest_url}"
fi
tar -zxf "${SELF_DIR}/sqlite.tar.gz" --strip-components=1 -C /usr/src/sqlite
cd /usr/src/sqlite
if [ x"${TARGET_HOST}" = x"win" ]; then
  ln -sf mksourceid.exe mksourceid
  SQLITE_EXT_CONF="config_TARGET_EXEEXT=.exe"
fi
./configure --host="${CROSS_HOST}" --prefix="${CROSS_PREFIX}" --enable-static --disable-shared "${SQLITE_EXT_CONF}"
make -j$(nproc)
make install
sqlite_ver="$(grep Version: "${CROSS_PREFIX}/lib/pkgconfig/"sqlite*.pc)"
echo "- sqlite: ${sqlite_ver}, source: ${sqlite_latest_url:-cached sqlite}" >>"${BUILD_INFO}"

# c-ares
if [ ! -f "${SELF_DIR}/c-ares.tar.gz" ]; then
  cares_suffix_url="$(wget -qO- https://c-ares.haxx.se/ | grep -o 'href=".*tar.gz"' | grep -o '[^"]*tar.gz')"
  cares_latest_url="https://c-ares.haxx.se${cares_suffix_url}"
  # cares_latest_url="https://github.com/c-ares/c-ares/archive/main.tar.gz"
  wget -c -O "${SELF_DIR}/c-ares.tar.gz" "${cares_latest_url}"
fi
tar -zxf "${SELF_DIR}/c-ares.tar.gz" --strip-components=1 -C /usr/src/c-ares
cd /usr/src/c-ares
if [ ! -f "./configure" ]; then
  autoreconf -i
fi
./configure --host="${CROSS_HOST}" --prefix="${CROSS_PREFIX}" --enable-static --disable-shared --enable-silent-rules --disable-tests
make -j$(nproc)
make install
cares_ver="$(grep Version: "${CROSS_PREFIX}/lib/pkgconfig/libcares.pc")"
echo "- c-ares: ${cares_ver}, source: ${cares_latest_url:-cached c-ares}" >>"${BUILD_INFO}"

# libssh2
if [ ! -f "${SELF_DIR}/libssh2.tar.gz" ]; then
  libssh2_suffix_url="$(wget -qO- https://www.libssh2.org/ | grep -o 'href=".*tar.gz"' | grep -o '[^"]*libssh2.*tar.gz')"
  libssh2_latest_url="https://www.libssh2.org/${libssh2_suffix_url}"
  wget -c -O "${SELF_DIR}/libssh2.tar.gz" "${libssh2_latest_url}"
fi
tar -zxf "${SELF_DIR}/libssh2.tar.gz" --strip-components=1 -C /usr/src/libssh2
cd /usr/src/libssh2
./configure --host="${CROSS_HOST}" --prefix="${CROSS_PREFIX}" --enable-static --disable-shared --enable-silent-rules #"${LIBSSH2_EXT_CONF}"
make -j$(nproc)
make install
libssh2_ver="$(grep Version: "${CROSS_PREFIX}/lib/pkgconfig/libssh2.pc")"
echo "- libssh2: ${libssh2_ver}, source: ${libssh2_latest_url:-cached libssh2}" >>"${BUILD_INFO}"

# libuv
if [ ! -f "${SELF_DIR}/libuv.tar.gz" ]; then
  libuv_latest_url="$(wget -qO- https://api.github.com/repos/libuv/libuv/tags | jq -r '.[0].tarball_url')"
  wget -c -O "${SELF_DIR}/libuv.tar.gz" "${libuv_latest_url}"
fi
tar -zxf "${SELF_DIR}/libuv.tar.gz" --strip-components=1 -C /usr/src/libuv
cd /usr/src/libuv
./autogen.sh
./configure --host="${CROSS_HOST}" --prefix="${CROSS_PREFIX}" --enable-static --disable-shared --enable-silent-rules
make -j$(nproc)
make install
libuv_ver="$(grep Version: "${CROSS_PREFIX}/lib/pkgconfig/libuv.pc")"
echo "- libuv: ${libuv_ver}, source: ${libuv_latest_url:-cached libuv}" >>"${BUILD_INFO}"

# jemalloc
if [ ! -f "${SELF_DIR}/jemalloc.tar.bz2" ]; then
  jemalloc_tag="$(wget -qO- https://api.github.com/repos/jemalloc/jemalloc/tags | jq -r '.[0].name')"
  jemalloc_latest_url="https://github.com/jemalloc/jemalloc/releases/download/${jemalloc_tag}/jemalloc-${jemalloc_tag}.tar.bz2"
  wget -c -O "${SELF_DIR}/jemalloc.tar.bz2" "${jemalloc_latest_url}"
fi
tar -jxf "${SELF_DIR}/jemalloc.tar.bz2" --strip-components=1 -C /usr/src/jemalloc
cd /usr/src/jemalloc
./configure --host="${CROSS_HOST}" --prefix="${CROSS_PREFIX}" --enable-static --disable-shared CXXFLAGS='-std=c++11'
make -j$(nproc)
make install
jemalloc_ver="$(grep Version: "${CROSS_PREFIX}/lib/pkgconfig/jemalloc.pc")"
echo "- jemalloc: ${jemalloc_ver}, source: ${jemalloc_latest_url:-cached jemalloc}" >>"${BUILD_INFO}"

# aria2
if [ ! -f "${SELF_DIR}/aria2.tar.gz" ]; then
  if [ -n "${ARIA2_VER}" ]; then
    aria2_latest_url="https://github.com/aria2/aria2/releases/download/release-${ARIA2_VER}/aria2-${ARIA2_VER}.tar.gz"
  else
    aria2_latest_url="https://github.com/aria2/aria2/archive/master.tar.gz"
  fi
  wget -c -O "${SELF_DIR}/aria2.tar.gz" "${aria2_latest_url}"
fi
tar -zxf "${SELF_DIR}/aria2.tar.gz" --strip-components=1 -C /usr/src/aria2
cd /usr/src/aria2
if [ ! -f ./configure ]; then
  autoreconf -i
fi
if [ x"${TARGET_HOST}" = xwin ]; then
  ARIA2_EXT_CONF='--without-openssl'
else
  ARIA2_EXT_CONF='--with-ca-bundle=/etc/ssl/certs/ca-certificates.crt'
fi
./configure --host="${CROSS_HOST}" --prefix="${CROSS_PREFIX}" --enable-static --disable-shared --enable-silent-rules ARIA2_STATIC=yes --with-libuv --with-jemalloc ${ARIA2_EXT_CONF}
make -j$(nproc)
make install
echo "- aria2: source: ${aria2_latest_url:-cached aria2}" >>"${BUILD_INFO}"
echo >>"${BUILD_INFO}"

# get release
cp -v "${CROSS_PREFIX}/bin/"aria2* "${SELF_DIR}"

echo "============= ARIA2 VER INFO ==================="
ARIA2_VER_INFO="$("${RUNNER_CHECKER}" "${CROSS_PREFIX}/bin/"aria2c* --version 2>/dev/null)"
echo "${ARIA2_VER_INFO}"
echo "================================================"

echo "aria2 version info:" >>"${BUILD_INFO}"
echo '```txt' >>"${BUILD_INFO}"
echo "${ARIA2_VER_INFO}" >>"${BUILD_INFO}"
echo '```' >>"${BUILD_INFO}"

echo "============= ARIA2 TEST DOWNLOAD =============="
# Seems wine does not support WinTLS until now, which will cause wine aria2c.exe be failed.
# But in fact it works in real Windows, so I just skip Windows test.
if [ x"${TARGET_HOST}" != xwin ]; then
  "${RUNNER_CHECKER}" "${CROSS_PREFIX}/bin/"aria2c* --http-accept-gzip=true https://github.com/ -d /tmp -o test
fi
echo "================================================"
