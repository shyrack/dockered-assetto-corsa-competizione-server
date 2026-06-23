# syntax=docker/dockerfile:1

FROM debian:13-slim

RUN set -eux; \
    dpkg --add-architecture i386; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        netcat-openbsd \
        tini \
        winbind \
        xvfb; \
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL -o /tmp/winehq.key https://dl.winehq.org/wine-builds/winehq.key; \
    if ! gpg --show-keys --with-fingerprint /tmp/winehq.key 2>/dev/null \
        | tr -d '[:space:]' \
        | grep -q 'D43F640145369C51D786DDEA76F1A20FF987672F'; then \
        echo "ERROR: WineHQ GPG key fingerprint mismatch" >&2; \
        exit 1; \
    fi; \
    cat /tmp/winehq.key | gpg --dearmor > /etc/apt/keyrings/winehq-archive.key; \
    rm /tmp/winehq.key; \
    curl -fsSL -o /etc/apt/sources.list.d/winehq-trixie.sources \
        https://dl.winehq.org/wine-builds/debian/dists/trixie/winehq-trixie.sources; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        winehq-stable; \
    ln -sf /opt/wine-stable/bin/wine       /usr/bin/wine; \
    ln -sf /opt/wine-stable/bin/wineboot   /usr/bin/wineboot; \
    ln -sf /opt/wine-stable/bin/wineserver /usr/bin/wineserver; \
    apt-get remove --purge -y curl gnupg gnupg2; \
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

WORKDIR /app

RUN mkdir -p \
        /app/cfg \
        /app/results \
        /home/assetto-corsa-competizione/.wine; \
    chown -R assetto-corsa-competizione:assetto-corsa-competizione \
        /home/assetto-corsa-competizione

ENV WINEARCH=win64 \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES="mscoree,mshtml=" \
    WINEPREFIX=/home/assetto-corsa-competizione/.wine \
    DISPLAY=:99

LABEL org.opencontainers.image.title="Dockered ACC Server" \
      org.opencontainers.image.description="Wine runtime for Assetto Corsa Competizione dedicated server" \
      org.opencontainers.image.licenses="MIT"

STOPSIGNAL SIGTERM

EXPOSE 8081/tcp
EXPOSE 9600/tcp
EXPOSE 9600/udp
EXPOSE 9601/tcp
EXPOSE 9601/udp

VOLUME ["/app/cfg", "/app/results"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=300s --retries=3 \
    CMD nc -z localhost 8081 || exit 1

USER assetto-corsa-competizione

ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/bin/sh", "-c"]
CMD ["\
    set -e; \
    Xvfb :99 -screen 0 1024x768x16 & \
    XVFB_PID=$!; \
    for _ in 1 2 3 4 5 6 7 8 9 10; do \
        [ -e /tmp/.X99-lock ] && break; \
        sleep 0.5; \
    done; \
    if ! kill -0 $XVFB_PID 2>/dev/null; then \
        echo 'ERROR: Xvfb failed to start' >&2; \
        exit 1; \
    fi; \
    wineboot -u; \
    exec wine accServer.exe \
"]
