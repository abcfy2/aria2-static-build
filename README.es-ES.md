

# aria2-static-build

![Build and Release](https://github.com/abcfy2/aria2-static-build/actions/workflows/build_and_release.yml/badge.svg)

Compilación estática de aria2 usando musl que admite múltiples plataformas.

## Descarga

Puedes descargar desde [Continuous Build](https://github.com/abcfy2/aria2-static-build/releases/tag/continuous) (Compilación semanal desde la rama master de aria2 con las últimas dependencias).

O descarga desde la compilación de [último lanzamiento](https://github.com/abcfy2/aria2-static-build/releases/latest) (Compilada desde la versión de lanzamiento más reciente de aria2).

## NOTA para usuarios de Android

Si estás ejecutando en un entorno Android (como x86_64, arm o aarch64), por favor sigue el README oficial de Android de aria2: https://github.com/aria2/aria2/blob/master/README.android

Aquí hay un ejemplo:

```sh
cat /etc/security/cacerts/* | ./aria2c --ca-certificate=/proc/self/fd/0 --async-dns-server=1.1.1.1 https://github.com/
```

Ten en cuenta que `getprop net.dns1` no funciona desde Android 8, por lo que debes configurar un DNS válido manualmente.

## NOTA sobre certificados https (Solo Linux)

La ubicación de los certificados SSL puede variar entre diferentes distribuciones. Ej.: Ubuntu usa `/etc/ssl/certs/ca-certificates.crt`, pero CentOS usa `/etc/pki/tls/certs/ca-bundle.crt`.

Es imposible detectar la ubicación de los certificados en todas las distribuciones. Ver incidencia: [openssl/openssl#7481](https://github.com/openssl/openssl/issues/7481). Afortunadamente, la mayoría de las distribuciones pueden contener un enlace simbólico `/etc/ssl/cert.pem` que apunta a la ruta del archivo real.

Por eso configuré las opciones de compilación `--openssldir=/etc/ssl/` para openssl/libressl. Lo cual funciona para la mayoría de las distribuciones.

Si tu entorno contiene el archivo `/etc/ssl/openssl.cnf` o `/etc/ssl/cert.pem`, tienes suerte y puedes usar mi compilación directamente sin configuraciones adicionales.

Si tu entorno no contiene ninguno de estos archivos, debes hacer una de las siguientes opciones para garantizar que las solicitudes HTTPS funcionen.

- Agrega `--ca-certificate=/ruta/a/tu/certificado` a `aria2c` o configura `ca-certificate=/ruta/a/tu/certificado` en `~/.aria2/aria2.conf`. Ej.: `./aria2c --ca-certificate=/etc/pki/tls/certs/ca-bundle.crt https://github.com/`
- O añade la variable de entorno `SSL_CERT_FILE=/ruta/a/tu/certificado` antes de ejecutar `aria2c`. Ej.: `export SSL_CERT_FILE=/etc/pki/tls/certs/ca-bundle.crt; ./aria2c https://github.com/` o `SSL_CERT_FILE=/etc/pki/tls/certs/ca-bundle.crt ./aria2c https://github.com/`

> Referencia para ubicaciones de certificados en diferentes distribuciones: https://gitlab.com/probono/platformissues/blob/master/README.md#certificates

## NOTA para usuarios de Fedora

El openssl de Fedora puede contener algunos parches no oficiales y tener configuraciones no soportadas por el openssl de esta compilación.

Para este escenario, puedes forzar la configuración de una variable de entorno `OPENSSL_CONF` que apunte a una ruta inválida antes de ejecutar `aria2c`. Ej.:

```sh
OPENSSL_CONF=/tmp ./aria2c https://github.com/
```

Esto no se verá interferido por la configuración de openssl de Fedora.

## Compilar localmente tú mismo

Requisitos:

- docker

```sh
docker run --rm -v `pwd`:/build abcfy2/musl-cross-toolchain-ubuntu:${CROSS_HOST} /build/build.sh

# Para x86_64-w64-mingw32 e i686-w64-mingw32, por favor usa abcfy2/mingw-cross-toolchain-ubuntu en su lugar:
docker run --rm -v `pwd`:/build abcfy2/mingw-cross-toolchain-ubuntu:${CROSS_HOST} /build/build.sh
```

> También puedes usar mi imagen de GHCR como alternativa: [ghcr.io/abcfy2/musl-cross-toolchain-ubuntu](https://github.com/abcfy2/docker-musl-cross-toolchain-ubuntu/pkgs/container/musl-cross-toolchain-ubuntu) y [ghcr.io/abcfy2/mingw-cross-toolchain-ubuntu](https://github.com/abcfy2/docker-mingw-cross-toolchain-ubuntu/pkgs/container/mingw-cross-toolchain-ubuntu)

Todos los `CROSS_HOST` disponibles se pueden encontrar en la página [Tags](https://hub.docker.com/r/abcfy2/musl-cross-toolchain-ubuntu/tags).

**NOTA**: Actualmente solo he probado las siguientes etiquetas:

- arm-unknown-linux-musleabi
- aarch64-unknown-linux-musl
- loongarch64-unknown-linux-musl
- mips-unknown-linux-musl
- mipsel-unknown-linux-musl
- mips64-unknown-linux-musl
- x86_64-unknown-linux-musl
- i686-unknown-linux-musl
- x86_64-w64-mingw32
- i686-w64-mingw32

Si deseas compilar para otra plataforma, es posible que tengas que modificar `build.sh` para adaptarlo a tu plataforma.

Las dependencias de compilación en caché (`downloads/`), `build_info.md` y `aria2c` se encontrarán en el directorio actual.

Puedes configurar más variables de entorno opcionales en el comando `docker` como:

```sh
docker run --rm -v `pwd`:/build -e USE_ZLIB_NG=0 -e USE_LIBRESSL=1 abcfy2/musl-cross-toolchain-ubuntu:${CROSS_HOST} /build/build.sh
```

Variables de entorno opcionales:

- `ARIA2_VER`: compilar una versión específica de aria2, ej.: `1.36.0`. Predeterminado: `master`.
- `USE_CHINA_MIRROR`: establecerlo en `1` usará espejos de China, si te encuentras en China, por favor establécelo en `1`. Predeterminado: `0`.
- `USE_ZLIB_NG`: usa [zlib-ng](https://github.com/zlib-ng/zlib-ng) en lugar de [zlib](https://zlib.net/). Predeterminado: `1`
- `USE_LIBRESSL`: usa [LibreSSL](https://www.libressl.org/) en lugar de [OpenSSL](https://www.openssl.org/). Predeterminado: `0`. **_NOTA_**, si `CROSS_HOST=x86_64-w64-mingw32` no usará openssl ni libressl porque aria2 y todas las dependencias usarán WinTLS en su lugar.
