# aria2-static-build

![workflow](https://github.com/abcfy2/aria2-static-build/workflows/.github/workflows/build_and_release.yml/badge.svg)

aria2 static build using musl and support many platforms.

You can downloads from release pages.

Continuous build: https://github.com/abcfy2/aria2-static-build/releases/tag/continuous

## Build locally yourself

Requirements:

- docker

```sh
docker run --rm -v `pwd`:/build alpine /build/build.sh
```

Cached build dependencies, `build_info.md` and `aria2c` will be found in current directory.

You can set more optional environment variables in `docker` command like:

```sh
docker run --rm -v `pwd`:/build -e CROSS_HOST=x86_64-linux-musl -e USE_ZLIB_NG=0 -e USE_LIBRESSL=1 alpine /build/build.sh
```

Optional environment variables:

- `CROSS_HOST`: cross toolchain name can be found in [musl.cc](http://musl.cc/)(without `-cross` or `-native`). Default: `arm-linux-musleabi`
- `USE_ZLIB_NG`: use [zlib-ng](https://github.com/zlib-ng/zlib-ng) instead of [zlib](https://zlib.net/). Default: `1`
- `USE_LIBRESSL`: use [LibreSSL](https://www.libressl.org/) instead of [OpenSSL](https://www.openssl.org/). Default: `0`. **_NOTE_**, if `CROSS_HOST=x86_64-w64-mingw32` will not use openssl or libressl because aria2 and all dependencies will use WinTLS instead.
