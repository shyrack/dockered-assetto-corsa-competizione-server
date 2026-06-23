FROM alpine:3

RUN apk add wine && \
    rm -rf /var/cache/apk/*

ARG UID=1000
ARG GID=1000

RUN addgroup -g $GID assetto-corsa-competizione 2>/dev/null || true && \
    adduser -D -h /home/assetto-corsa-competizione -u $UID -G assetto-corsa-competizione assetto-corsa-competizione

WORKDIR /app

RUN mkdir -p /app/cfg /app/results && \
    mkdir -p /home/assetto-corsa-competizione/.wine && \
    chown -R assetto-corsa-competizione:assetto-corsa-competizione /home/assetto-corsa-competizione

ENV WINEARCH=win64 \
    WINEDEBUG=-all \
    WINEPREFIX=/home/assetto-corsa-competizione/.wine

USER assetto-corsa-competizione

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

CMD ["wine", "accServer.exe"]
