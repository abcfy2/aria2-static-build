# aria2-static-build

![workflow](https://github.com/abcfy2/aria2-static-build/workflows/.github/workflows/build_and_release.yml/badge.svg)

aria2 static build using musl and support many platforms.

You can downloads from release pages.

Continuous build: https://github.com/abcfy2/aria2-static-build/releases/tag/continuous

> **NOTE**: If you were executed in Android environment (maybe x86_64, arm, or aarch64), please follow the official aria2 Android README: https://github.com/aria2/aria2/blob/master/README.android
>
> Here is a sample:
>
> ```sh
> cat /etc/security/cacerts/* | ./aria2c --async-dns-server=1.1.1.1 https://github.com/
> ```
>
> Please note `getprop net.dns1` does not work since Android 8, so you have to set a valid DNS manually.

## Build locally yourself

Requirements:

- docker

```sh
docker run --rm -v `pwd`:/build ubuntu /build/build.sh
```

Cached build dependencies, `build_info.md` and `aria2c` will be found in current directory.

You can set more optional environment variables in `docker` command like:

```sh
docker run --rm -v `pwd`:/build -e CROSS_HOST=x86_64-linux-musl -e USE_ZLIB_NG=0 -e USE_LIBRESSL=1 ubuntu /build/build.sh
```

Optional environment variables:

- `ARIA2_VER`: build specific version of aria2, e.g: `1.36.0`. Default: `master`.
- `USE_CHINIA_MIRROR`: set to `1` will use China mirrors, if you were located in China, please set to `1`. Default: `0`.
- `CROSS_HOST`: cross toolchain name can be found in [musl.cc](http://musl.cc/)(without `-cross` or `-native`). Default: `arm-linux-musleabi`
- `USE_ZLIB_NG`: use [zlib-ng](https://github.com/zlib-ng/zlib-ng) instead of [zlib](https://zlib.net/). Default: `1`
- `USE_LIBRESSL`: use [LibreSSL](https://www.libressl.org/) instead of [OpenSSL](https://www.openssl.org/). Default: `0`. **_NOTE_**, if `CROSS_HOST=x86_64-w64-mingw32` will not use openssl or libressl because aria2 and all dependencies will use WinTLS instead.
