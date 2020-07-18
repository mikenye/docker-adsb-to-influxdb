FROM golang:1 AS telegraf_builder

WORKDIR /src/telegraf

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

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
    BRANCH_TELEGRAF=$(git tag --sort="-creatordate" | head -1) && \
    git checkout "tags/${BRANCH_TELEGRAF}" && \
    make

FROM debian:stable-slim AS readsb_builder

WORKDIR /src/readsb

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

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
    make OPTIMIZE="-O3"

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

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -x && \
    apt-get update && \
    apt-get install --no-install-recommends -y \
        bc \
        ca-certificates \
        curl \
        file \
        libncurses6 \
        gnupg \
        jq \
        net-tools \
        procps \
        && \
    curl -s https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh | sh && \
    apt-get remove -y \
        file \
        gnupg \
        && \
    apt-get autoremove -y && \
    apt-get clean -y && \
    /usr/local/bin/telegraf --version >> /VERSIONS && \
    # In the line below, the "timeout" and "|| true" are workarounds for weird readsb behaviour.
    # readsb doesn't exit when running with "--version". I've let the author know and will remove
    # this workaround when fixed.
    echo "readsb $(timeout 3s /usr/local/bin/readsb --version 2>&1 | grep -i version)" >> /VERSIONS || true && \
    echo "debian version $(cat /etc/debian_version)" >> /VERSIONS && \
    date -I >> /BUILDDATE && \
    rm -rf /var/lib/apt/lists/* /src && \
    cat /VERSIONS

COPY /rootfs /

ENTRYPOINT [ "/init" ]