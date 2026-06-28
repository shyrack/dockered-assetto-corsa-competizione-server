# syntax=docker/dockerfile:1

FROM debian:13-slim

RUN set -eux; \
    dpkg --add-architecture i386; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libc6:i386 \
    libfreetype6:amd64 \
    libfreetype6:i386 \
    netcat-openbsd \
    python3 \
    tini \
    xz-utils

ARG UMU_PROTON_VERSION=UMU-Proton-10.0-4
RUN set -eux; \
    mkdir -p /opt/umu-proton; \
    curl -sSL "https://github.com/Open-Wine-Components/umu-proton/releases/download/${UMU_PROTON_VERSION}/${UMU_PROTON_VERSION}.tar.gz" \
    | tar xz -C /opt/umu-proton; \
    ln -s "/opt/umu-proton/${UMU_PROTON_VERSION}" /opt/umu-proton/current

ENV STEAM_COMPAT_DATA_PATH=/app/compatdata \
    STEAM_COMPAT_CLIENT_INSTALL_PATH=/nonexistent \
    UMU_ID=acc-server \
    STORE=none \
    WINEDEBUG=-all \
    PROTON_NO_FSYNC=1
ENV PATH=/opt/umu-proton/current:$PATH

RUN set -eux; \
    apt-get remove --purge -y curl xz-utils; \
    apt-get autoremove --purge -y; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

ARG UID=1000
ARG GID=1000

RUN set -eux; \
    groupadd --gid "$GID" assetto-corsa-competizione; \
    useradd --uid "$UID" --gid "$GID" \
    --home-dir /home/assetto-corsa-competizione \
    --shell /usr/sbin/nologin \
    --create-home \
    assetto-corsa-competizione

RUN echo "acc-server-00000000000000000000000000000001" > /etc/machine-id

RUN mkdir -p /app/compatdata && chown assetto-corsa-competizione:assetto-corsa-competizione /app/compatdata

WORKDIR /app

LABEL \
    org.opencontainers.image.title="Dockered ACC Server" \
    org.opencontainers.image.description="Proton runtime for Assetto Corsa Competizione dedicated server" \
    org.opencontainers.image.licenses="MIT"

STOPSIGNAL SIGTERM

EXPOSE 8081/tcp
EXPOSE 9600/tcp
EXPOSE 9600/udp
EXPOSE 9601/tcp
EXPOSE 9601/udp

HEALTHCHECK --interval=30s --timeout=10s --start-period=300s --retries=3 \
    CMD nc -z localhost 8081 || exit 1

USER assetto-corsa-competizione

ENTRYPOINT ["/usr/bin/tini", "-g", "--", "proton", "run", "accServer.exe"]
