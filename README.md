# Dockered Assetto Corsa Competizione Server

Docker image providing a Wine runtime to run the Windows-based ACC dedicated server on Linux.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Prerequisites

- Docker 21.05+
- ACC dedicated server files downloaded to `./acc-server/`

Download the ACC dedicated server (Steam App ID 1430110) to your host:

```sh
# Install SteamCMD (see https://developer.valvesoftware.com/wiki/SteamCMD)
steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir ./acc-server +login YOUR_STEAM_ACCOUNT +app_update 1430110 +quit
```

The server files will be in `./acc-server/` with `accServer.exe` at the root.

## Build

```sh
docker build -t acc-server .
```

## Run

### Docker Compose (recommended)

```sh
docker compose up -d
```

### Docker CLI

```sh
docker run -d \
  --name acc-server \
  --init \
  --restart unless-stopped \
  -v "$(pwd)/acc-server:/app" \
  -p 9600:9600/tcp \
  -p 9600:9600/udp \
  -p 9601:9601/tcp \
  -p 9601:9601/udp \
  acc-server
```

## Configuration

Place your ACC config files in `acc-server/cfg/` before starting the container:

```
acc-server/
├── accServer.exe
├── cfg/
│   ├── configuration.json
│   ├── settings.json
│   └── event.json
└── results/
```

If `configuration.json` uses a custom `udpPort` / `tcpPort`, adjust the `-p` mappings accordingly. Remember that the ACC lobby handshake always uses `udpPort + 1` for both TCP and UDP.

## Docker Compose

A `docker-compose.yml` is included in the repository. Start with:

```sh
docker compose up -d
```

Contents:

```yaml
services:
  acc:
    image: acc-server
    container_name: acc-server
    restart: unless-stopped
    init: true
    ports:
      - "9600:9600/tcp"
      - "9600:9600/udp"
      - "9601:9601/tcp"
      - "9601:9601/udp"
    volumes:
      - ./acc-server:/app
```

## Exposed Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 9600 | TCP + UDP | Main server (client connections and query) |
| 9601 | TCP + UDP | Lobby registration handshake (9600 + 1) |
| 8081 | TCP | HTTP broadcasting API (healthcheck) |
