
# bump: vorbis /VORBIS_VERSION=([\d.]+)/ https://github.com/xiph/vorbis.git|*
# bump: vorbis after ./hashupdate Dockerfile VORBIS $LATEST
# bump: vorbis link "CHANGES" https://github.com/xiph/vorbis/blob/master/CHANGES
# bump: vorbis link "Source diff $CURRENT..$LATEST" https://github.com/xiph/vorbis/compare/v$CURRENT..v$LATEST
ARG VORBIS_VERSION=1.3.7
ARG VORBIS_URL="https://downloads.xiph.org/releases/vorbis/libvorbis-$VORBIS_VERSION.tar.gz"
ARG VORBIS_SHA256=0e982409a9c3fc82ee06e08205b1355e5c6aa4c36bca58146ef399621b0ce5ab

FROM ghcr.io/ffbuilds/static-libogg:main as libogg

# bump: alpine /FROM alpine:([\d.]+)/ docker:alpine|^3
# bump: alpine link "Release notes" https://alpinelinux.org/posts/Alpine-$LATEST-released.html
FROM alpine:3.16.2 AS base

FROM base AS download
ARG VORBIS_URL
ARG VORBIS_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O libvorbis.tar.gz "$VORBIS_URL" && \
  echo "$VORBIS_SHA256  libvorbis.tar.gz" | sha256sum --status -c - && \
  mkdir vorbis && \
  tar xf libvorbis.tar.gz -C vorbis --strip-components=1 && \
  rm libvorbis.tar.gz && \
  apk del download

FROM base AS build
COPY --from=download /tmp/vorbis/ /tmp/vorbis/
COPY --from=libogg /usr/local/lib/pkgconfig/ogg.pc /usr/local/lib/pkgconfig/ogg.pc
COPY --from=libogg /usr/local/lib/libogg.a /usr/local/lib/libogg.a
COPY --from=libogg /usr/local/include/ogg/ /usr/local/include/ogg/
WORKDIR /tmp/vorbis
RUN \
  apk add --no-cache --virtual build \
    build-base && \
  ./configure --disable-shared --enable-static --disable-oggtest && \
  make -j$(nproc) install && \
  apk del build

FROM scratch
ARG VORBIS_VERSION
COPY --from=build /usr/local/lib/pkgconfig/vorbis*.pc /usr/local/lib/pkgconfig/
COPY --from=build /usr/local/lib/libvorbis*.a /usr/local/lib/
COPY --from=build /usr/local/include/vorbis/ /usr/local/include/vorbis/
