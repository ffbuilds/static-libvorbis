# syntax=docker/dockerfile:1

# bump: vorbis /VORBIS_VERSION=([\d.]+)/ https://github.com/xiph/vorbis.git|*
# bump: vorbis after ./hashupdate Dockerfile VORBIS $LATEST
# bump: vorbis link "CHANGES" https://github.com/xiph/vorbis/blob/master/CHANGES
# bump: vorbis link "Source diff $CURRENT..$LATEST" https://github.com/xiph/vorbis/compare/v$CURRENT..v$LATEST
ARG VORBIS_VERSION=1.3.7
ARG VORBIS_URL="https://downloads.xiph.org/releases/vorbis/libvorbis-$VORBIS_VERSION.tar.gz"
ARG VORBIS_SHA256=0e982409a9c3fc82ee06e08205b1355e5c6aa4c36bca58146ef399621b0ce5ab

# Must be specified
ARG ALPINE_VERSION

FROM ghcr.io/ffbuilds/static-libogg-alpine_${ALPINE_VERSION}:main as libogg

FROM alpine:${ALPINE_VERSION} AS base

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
    build-base pkgconf && \
  ./configure --disable-shared --enable-static --disable-oggtest && \
  make -j$(nproc) install && \
  # Sanity tests
  pkg-config --exists --modversion --path vorbis && \
  pkg-config --exists --modversion --path vorbisenc && \
  pkg-config --exists --modversion --path vorbisfile && \
  ar -t /usr/local/lib/libvorbis.a && \
  ar -t /usr/local/lib/libvorbisenc.a && \
  ar -t /usr/local/lib/libvorbisfile.a && \
  readelf -h /usr/local/lib/libvorbis.a && \
  readelf -h /usr/local/lib/libvorbisenc.a && \
  readelf -h /usr/local/lib/libvorbisfile.a && \
  # Cleanup
  apk del build

FROM scratch
ARG VORBIS_VERSION
COPY --from=build /usr/local/lib/pkgconfig/vorbis*.pc /usr/local/lib/pkgconfig/
COPY --from=build /usr/local/lib/libvorbis*.a /usr/local/lib/
COPY --from=build /usr/local/include/vorbis/ /usr/local/include/vorbis/
