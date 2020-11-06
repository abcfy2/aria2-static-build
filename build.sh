#!/bin/sh -e

# value from: https://musl.cc/ (without -cross or -native)
export CROSS_HOST="${CROSS_HOST:-arm-linux-musleabi}"
# value from openssl source: ./Configure LIST
export OPENSSL_COMPILER="${OPENSSL_COMPILER:-linux-armv4}"
export CROSS_ROOT="${CROSS_ROOT:-/cross_root}"
export LDFLAGS='-s -static --static'
sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/' /etc/apk/repositories
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
  ca-certificates-bundle
mkdir -p "${CROSS_ROOT}" /usr/src/zlib \
  /usr/src/xz \
  /usr/src/openssl \
  /usr/src/libiconv \
  /usr/src/libxml2 \
  /usr/src/sqlite \
  /usr/src/gmp \
  /usr/src/nettle \
  /usr/src/c-ares \
  /usr/src/libssh2 \
  /usr/src/libuv \
  /usr/src/jemalloc \
  /usr/src/aria2
export PATH="${CROSS_ROOT}/bin:${PATH}"
export CROSS_PREFIX="${CROSS_ROOT}/${CROSS_HOST}"
export PKG_CONFIG_PATH="${CROSS_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}"
SELF_DIR="$(dirname "${0}")"

# toolchain
[ ! -f "${SELF_DIR}/${CROSS_HOST}-cross.tgz" ] && wget -c -O "${SELF_DIR}/${CROSS_HOST}-cross.tgz" "https://musl.cc/${CROSS_HOST}-cross.tgz"
tar -axf "${SELF_DIR}/${CROSS_HOST}-cross.tgz" --strip-components=1 -C "${CROSS_ROOT}"
if [ ! -f "${SELF_DIR}/zlib.tar.gz" ]; then
  zlib_latest_url="$(wget -qO- https://api.github.com/repos/madler/zlib/tags | jq -r '.[0].tarball_url')"
  wget -c -O "${SELF_DIR}/zlib.tar.gz" "${zlib_latest_url}"
fi
tar -zxf "${SELF_DIR}/zlib.tar.gz" --strip-components=1 -C /usr/src/zlib
cd /usr/src/zlib
CHOST="${CROSS_HOST}" ./configure --prefix="${CROSS_PREFIX}" --static
make -j$(nproc)
make install

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

# libiconv
if [ ! -f "${SELF_DIR}/libiconv.tar.gz" ]; then
  libiconv_latest_url="$(wget -qO- https://www.gnu.org/software/libiconv/ | grep -o '[^>< "]*ftp.gnu.org/pub/gnu/libiconv/.[^>< "]*' | head -1)"
  wget -c -O "${SELF_DIR}/libiconv.tar.gz" "${libiconv_latest_url}"
fi
tar -zxf "${SELF_DIR}/libiconv.tar.gz" --strip-components=1 -C /usr/src/libiconv
cd /usr/src/libiconv
./configure --host="${CROSS_HOST}" --prefix="${CROSS_PREFIX}" --enable-silent-rules --enable-static --disable-shared
make -j$(nproc)
make install

# libxml2
if [ ! -f "${SELF_DIR}/libxml2.tar.gz" ]; then
  libxml2_latest_url="ftp://xmlsoft.org/libxml2/libxml2-git-snapshot.tar.gz"
  wget -c -O "${SELF_DIR}/libxml2.tar.gz" "${libxml2_latest_url}"
fi
tar -zxf "${SELF_DIR}/libxml2.tar.gz" --strip-components=1 -C /usr/src/libxml2
cd /usr/src/libxml2
CC="${CROSS_HOST}-gcc" ./configure --host="${CROSS_HOST%-musl*}" --prefix="${CROSS_PREFIX}" --enable-silent-rules --without-python --without-icu --enable-static --disable-shared
make -j$(nproc)
make install

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

# gmplib
if [ ! -f "${SELF_DIR}/gmp.tar.bz2" ]; then
  gmp_filename="$(wget -qO- 'https://ftp.gnu.org/gnu/gmp/?C=M;O=D' | grep -o 'href="gmp-.*tar.bz2"' | grep -o '[^"]*gmp-.*tar.bz2' | head -1)"
  gmp_latest_url="https://ftp.gnu.org/gnu/gmp/${gmp_filename}"
  wget -c -O "${SELF_DIR}/gmp.tar.bz2" "${gmp_latest_url}"
fi
tar -jxf "${SELF_DIR}/gmp.tar.bz2" --strip-components=1 -C /usr/src/gmp
cd /usr/src/gmp
./configure --host="${CROSS_HOST}" --prefix="${CROSS_PREFIX}" --enable-static --disable-shared --enable-silent-rules --enable-cxx
make -j$(nproc)
make install

# nettle
if [ ! -f "${SELF_DIR}/nettle.tar.gz" ]; then
  nettle_filename="$(wget -qO- 'https://ftp.gnu.org/gnu/nettle/?C=M;O=D' | grep -o 'href="nettle-.*tar.gz"' | grep -o '[^"]*nettle-.*tar.gz' | head -1)"
  nettle_latest_url="https://ftp.gnu.org/gnu/nettle/${nettle_filename}"
  wget -c -O "${SELF_DIR}/nettle.tar.gz" "${nettle_latest_url}"
fi
tar -zxf "${SELF_DIR}/nettle.tar.gz" --strip-components=1 -C /usr/src/nettle
cd /usr/src/nettle
./configure --host="${CROSS_HOST}" --prefix="${CROSS_PREFIX}" --enable-static --disable-shared
make -j$(nproc)
make install

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

# aria2
if [ ! -f "${SELF_DIR}/aria2.tar.gz" ]; then
  aria2_latest_tag="$(wget -qO- https://api.github.com/repos/aria2/aria2/tags | jq -r '.[0].name')"
  aria2_latest_ver="${aria2_latest_tag#*-}"
  aria2_latest_url="https://github.com/aria2/aria2/releases/download/release-${aria2_latest_ver}/aria2-${aria2_latest_ver}.tar.gz"
  wget -c -O "${SELF_DIR}/aria2.tar.gz" "${aria2_latest_url}"
fi
tar -zxf "${SELF_DIR}/aria2.tar.gz" --strip-components=1 -C /usr/src/aria2
cd /usr/src/aria2
./configure --host="${CROSS_HOST}" --prefix="${CROSS_PREFIX}" --enable-silent-rules --enable-static --disable-shared ARIA2_STATIC=yes --with-libuv --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt --with-jemalloc
make -j$(nproc)
make install

# get release
cp "${CROSS_PREFIX}/bin/"aria2* "${SELF_DIR}"
