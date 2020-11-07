#!/bin/sh -e

# value from: https://musl.cc/ (without -cross or -native)
export CROSS_HOST="${CROSS_HOST:-arm-linux-musleabi}"
# value from openssl source: ./Configure LIST
export OPENSSL_COMPILER="${OPENSSL_COMPILER:-linux-armv4}"
export CROSS_ROOT="${CROSS_ROOT:-/cross_root}"
export LDFLAGS='-s -static --static'
if [ ! "${CI}" = true ]; then
  sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/' /etc/apk/repositories
fi
apk upgrade
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
  gettext-dev \
  ca-certificates-bundle
mkdir -p "${CROSS_ROOT}" /usr/src/zlib \
  /usr/src/xz \
  /usr/src/openssl \
  /usr/src/libxml2 \
  /usr/src/sqlite \
  /usr/src/c-ares \
  /usr/src/libssh2 \
  /usr/src/libuv \
  /usr/src/jemalloc \
  /usr/src/aria2
export PATH="${CROSS_ROOT}/bin:${PATH}"
export CROSS_PREFIX="${CROSS_ROOT}/${CROSS_HOST}"
export PKG_CONFIG_PATH="${CROSS_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}"
SELF_DIR="$(dirname "${0}")"
BUILD_INFO="${SELF_DIR}/build_info.md"

echo "# Build Info" > "${BUILD_INFO}"
echo "Building using these dependencies:" >> "${BUILD_INFO}"

# toolchain
[ ! -f "${SELF_DIR}/${CROSS_HOST}-cross.tgz" ] && wget -c -O "${SELF_DIR}/${CROSS_HOST}-cross.tgz" "https://musl.cc/${CROSS_HOST}-cross.tgz"
tar -axf "${SELF_DIR}/${CROSS_HOST}-cross.tgz" --transform='s|^\./||S' --strip-components=1 -C "${CROSS_ROOT}"

# zlib
if [ ! -f "${SELF_DIR}/zlib.tar.gz" ]; then
  zlib_latest_url="$(wget -qO- https://api.github.com/repos/madler/zlib/tags | jq -r '.[0].tarball_url')"
  wget -c -O "${SELF_DIR}/zlib.tar.gz" "${zlib_latest_url}"
fi
tar -zxf "${SELF_DIR}/zlib.tar.gz" --strip-components=1 -C /usr/src/zlib
cd /usr/src/zlib
CHOST="${CROSS_HOST}" ./configure --prefix="${CROSS_PREFIX}" --static
make -j$(nproc)
make install
echo "- zlib: ${zlib_latest_url:-cached zlib}" >> "${BUILD_INFO}"

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
echo "- xz: ${xz_latest_url:-cached xz}" >> "${BUILD_INFO}"

# openssl
if [ ! -f "${SELF_DIR}/openssl.tar.gz" ]; then
  openssl_filename="$(wget -qO- https://www.openssl.org/source/ | grep -o 'href="openssl-1.*tar.gz"' | grep -o '[^"]*.tar.gz')"
  openssl_latest_url="https://www.openssl.org/source/${openssl_filename}"
  wget -c -O "${SELF_DIR}/openssl.tar.gz" "${openssl_latest_url}"
fi
tar -zxf "${SELF_DIR}/openssl.tar.gz" --strip-components=1 -C /usr/src/openssl
cd /usr/src/openssl
./Configure -static --cross-compile-prefix="${CROSS_HOST}-" --prefix="${CROSS_PREFIX}" "${OPENSSL_COMPILER}"
make -j$(nproc)
make install_sw
echo "- openssl: ${openssl_latest_url:-cached openssl}" >> "${BUILD_INFO}"

# libxml2
if [ ! -f "${SELF_DIR}/libxml2.tar.gz" ]; then
  libxml2_latest_url="ftp://xmlsoft.org/libxml2/LATEST_LIBXML2"
  wget -c -O "${SELF_DIR}/libxml2.tar.gz" "${libxml2_latest_url}"
fi
tar -zxf "${SELF_DIR}/libxml2.tar.gz" --strip-components=1 -C /usr/src/libxml2
cd /usr/src/libxml2
CC="${CROSS_HOST}-gcc" ./configure --host="${CROSS_HOST%-musl*}" --prefix="${CROSS_PREFIX}" --enable-silent-rules --without-python --without-icu --enable-static --disable-shared
make -j$(nproc)
make install
echo "- libxml2: ${libxml2_latest_url:-cached libxml2}" >> "${BUILD_INFO}"

# sqlite
if [ ! -f "${SELF_DIR}/sqlite.tar.gz" ]; then
  sqlite_latest_url="https://github.com/sqlite/sqlite/archive/release.tar.gz"
  wget -c -O "${SELF_DIR}/sqlite.tar.gz" "${sqlite_latest_url}"
fi
tar -zxf "${SELF_DIR}/sqlite.tar.gz" --strip-components=1 -C /usr/src/sqlite
cd /usr/src/sqlite
./configure --host="${CROSS_HOST}" --prefix="${CROSS_PREFIX}" --enable-static --disable-shared
make -j$(nproc)
make install
echo "- sqlite: ${sqlite_latest_url:-cached sqlite}" >> "${BUILD_INFO}"

# c-ares
if [ ! -f "${SELF_DIR}/c-ares.tar.gz" ]; then
  cares_suffix_url="$(wget -qO- https://c-ares.haxx.se/ | grep -o 'href=".*tar.gz"' | grep -o '[^"]*tar.gz')"
  cares_latest_url="https://c-ares.haxx.se${cares_suffix_url}"
  wget -c -O "${SELF_DIR}/c-ares.tar.gz" "${cares_latest_url}"
fi
tar -zxf "${SELF_DIR}/c-ares.tar.gz" --strip-components=1 -C /usr/src/c-ares
cd /usr/src/c-ares
./configure --host="${CROSS_HOST}" --prefix="${CROSS_PREFIX}" --enable-static --disable-shared --enable-silent-rules
make -j$(nproc)
make install
echo "- c-ares: ${cares_latest_url:-cached c-ares}" >> "${BUILD_INFO}"

# libssh2
if [ ! -f "${SELF_DIR}/libssh2.tar.gz" ]; then
  libssh2_suffix_url="$(wget -qO- https://www.libssh2.org/ | grep -o 'href=".*tar.gz"' | grep -o '[^"]*libssh2.*tar.gz')"
  libssh2_latest_url="https://www.libssh2.org/${libssh2_suffix_url}"
  wget -c -O "${SELF_DIR}/libssh2.tar.gz" "${libssh2_latest_url}"
fi
tar -zxf "${SELF_DIR}/libssh2.tar.gz" --strip-components=1 -C /usr/src/libssh2
cd /usr/src/libssh2
./configure --host="${CROSS_HOST}" --prefix="${CROSS_PREFIX}" --enable-static --disable-shared --enable-silent-rules
make -j$(nproc)
make install
echo "- libssh2: ${libssh2_latest_url:-cached libssh2}" >> "${BUILD_INFO}"

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
echo "- libuv: ${libuv_latest_url:-cached libuv}" >> "${BUILD_INFO}"

# jemalloc
if [ ! -f "${SELF_DIR}/jemalloc.tar.bz2" ]; then
  jemalloc_tag="$(wget -qO- https://api.github.com/repos/jemalloc/jemalloc/tags | jq -r '.[0].name')"
  jemalloc_latest_url="https://github.com/jemalloc/jemalloc/releases/download/${jemalloc_tag}/jemalloc-${jemalloc_tag}.tar.bz2"
  wget -c -O "${SELF_DIR}/jemalloc.tar.bz2" "${jemalloc_latest_url}"
fi
tar -jxf "${SELF_DIR}/jemalloc.tar.bz2" --strip-components=1 -C /usr/src/jemalloc
cd /usr/src/jemalloc
./configure --host="${CROSS_HOST}" --prefix="${CROSS_PREFIX}" --enable-static --disable-shared
make -j$(nproc)
make install
echo "- jemalloc: ${jemalloc_latest_url:-cached jemalloc}" >> "${BUILD_INFO}"

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
./configure --host="${CROSS_HOST}" --prefix="${CROSS_PREFIX}" --enable-static --disable-shared --enable-silent-rules ARIA2_STATIC=yes --with-libuv --with-jemalloc
make -j$(nproc)
make install
echo "- aria2: ${aria2_latest_url:-cached aria2}" >> "${BUILD_INFO}"

# get release
cp -v "${CROSS_PREFIX}/bin/"aria2* "${SELF_DIR}"
