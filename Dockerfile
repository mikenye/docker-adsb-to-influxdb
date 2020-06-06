FROM golang:1 AS telegraf_builder

RUN set -x && \
    apt-get update && \
    apt-get install --no-install-recommends -y \
      git \
      ca-certificates \
      make \
      gcc \
      libc-dev \
      && \
    git clone https://github.com/influxdata/telegraf.git /src/telegraf && \
    cd /src/telegraf && \
    export BRANCH_TELEGRAF=$(git tag --sort="-creatordate" | head -1) && \
    git checkout tags/${BRANCH_TELEGRAF} && \
    make

FROM debian:stable-slim AS readsb_builder

RUN set -x && \
    apt-get update && \
    apt-get install --no-install-recommends -y \
        ca-certificates \
        gcc \
        git \
        libc-dev \
        libncurses-dev \
        make \
        zlib1g-dev \
        && \
    git clone https://github.com/wiedehopf/readsb.git /src/readsb && \
    cd /src/readsb && \
    make

FROM debian:stable-slim AS final

ENV ADSBPORT=30005 \
    ADSBTYPE=beast_in \
    INTERVAL=5 \
    JSONPORT=30012 \
    MLATPORT=30105 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2

COPY --from=telegraf_builder /src/telegraf/telegraf /usr/local/bin/telegraf
COPY --from=readsb_builder /src/readsb/readsb /usr/local/bin/readsb
COPY --from=readsb_builder /src/readsb/viewadsb /usr/local/bin/viewadsb

RUN set -x && \
    apt-get update && \
    apt-get install --no-install-recommends -y \
        ca-certificates \
        curl \
        libncurses6 \
        gnupg \
        net-tools \
        procps \
        && \
    curl -s https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh | sh && \
    apt-get remove -y \
        ca-certificates \
        curl \
        gnupg \
        && \
    apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/* /src

COPY /rootfs /

ENTRYPOINT [ "/init" ]