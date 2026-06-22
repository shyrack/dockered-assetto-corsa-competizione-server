FROM alpine:3

RUN apk add wine && \
    rm -rf /var/cache/apk/*

RUN adduser -D -h /app assetto-corsa-competizione

WORKDIR /app

RUN mkdir -p /app/cfg /app/results && \
    chown -R assetto-corsa-competizione:assetto-corsa-competizione /app

USER assetto-corsa-competizione

ENV WINEARCH=win64 \
    WINEDEBUG=-all

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
