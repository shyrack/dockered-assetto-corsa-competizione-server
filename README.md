# Dockered Assetto Corsa Competizione Server

Docker image providing an UMU-Proton runtime to run the Windows-based ACC dedicated server on Linux.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Build and Publish](https://github.com/shyrack/dockered-assetto-corsa-competizione-server/actions/workflows/workflow.yaml/badge.svg)](https://github.com/shyrack/dockered-assetto-corsa-competizione-server/actions/workflows/workflow.yaml)

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
  - [Download Server Files](#download-server-files)
  - [Build from Source](#build-from-source)
  - [Use Pre-built Image](#use-pre-built-image)
- [Running the Server](#running-the-server)
  - [Docker Compose (recommended)](#docker-compose-recommended)
  - [Docker CLI](#docker-cli)
- [Configuration](#configuration)
- [File Permissions](#file-permissions)
- [Ports and Networking](#ports-and-networking)
- [Healthcheck](#healthcheck)
- [Volumes](#volumes)
- [Environment Variables](#environment-variables)
- [Stopping the Server](#stopping-the-server)
- [Viewing Logs](#viewing-logs)
- [Updating the ACC Server](#updating-the-acc-server)
- [CI/CD](#cicd)
- [Contributing](#contributing)
- [License](#license)

## Features

- Runs the Windows-based ACC dedicated server on Linux via UMU-Proton 10.0
- Debian Trixie (13) slim base with Python 3 and i386 multiarch support
- Non-root user for improved security
- Built-in healthcheck via the ACC HTTP broadcasting API
- Pre-built images published to GitHub Container Registry
- Proper signal handling via `tini` and graceful shutdown via `SIGTERM`

## Quick Start

```sh
# 1. Install SteamCMD and download server files
steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir ./acc-server +login YOUR_STEAM_ACCOUNT +app_update 1430110 +quit

# 2. Build and start
docker compose up -d
```

## Prerequisites

- **Docker** 21.05+
- **ACC dedicated server files** (Steam App ID 1430110) placed in `./acc-server/`

## Installation

### Download Server Files

Install [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD) and download the ACC dedicated server:

```sh
steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir ./acc-server +login YOUR_STEAM_ACCOUNT +app_update 1430110 +quit
```

The server files will be in `./acc-server/` with `accServer.exe` at the root.

### Build from Source

Build the image, passing your host user's UID and GID so the container user can read and write the mounted server files:

```sh
docker build --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t acc-server .
```

If you skip `--build-arg`, the container user defaults to UID 1000. See [File Permissions](#file-permissions) for details.

### Use Pre-built Image

Pre-built images are published to `ghcr.io` on every tagged release. Pull the image instead of building:

```sh
docker pull ghcr.io/shyrack/dockered-assetto-corsa-competizione-server:0
```

Replace `:0` with the latest major version tag (see [GitHub Packages](https://github.com/shyrack/dockered-assetto-corsa-competizione-server/pkgs/container/dockered-assetto-corsa-competizione-server) for available tags).

Pre-built images use the default UID 1000. If your host files are owned by a different user, grant world-writable permissions before starting:

```sh
chmod -R 777 ./acc-server
```

If using the pre-built image, remove the `build:` section from `docker-compose.yml` and reference the `ghcr.io` image directly:

## Running the Server

### Docker Compose (recommended)

```sh
docker compose up -d
```

The included `docker-compose.yml`:

```yaml
services:
  acc:
    build:
      context: .
      args:
        UID: ${UID:-1000}
        GID: ${GID:-1000}
    image: acc-server
    container_name: acc-server
    restart: unless-stopped
    ports:
      - "9600:9600/tcp"
      - "9600:9600/udp"
      - "9601:9601/tcp"
      - "9601:9601/udp"
    volumes:
      - ./cfg:/app/server/cfg
      - ./results:/app/server/results
      - ./log:/app/server/log
      - compatdata:/app/compatdata

volumes:
  compatdata:
```

The `build.args` pass your host user's UID/GID to the image. Set them via `UID=$(id -u) GID=$(id -g) docker compose build`.

### Docker CLI

```sh
docker run -d \
  --name acc-server \
  --restart unless-stopped \
  -v "$(pwd)/cfg:/app/server/cfg" \
  -v "$(pwd)/results:/app/server/results" \
  -v "$(pwd)/log:/app/server/log" \
  -v "$(pwd)/acc-server/accServer.exe:/app/server/accServer.exe:ro" \
  -p 9600:9600/tcp \
  -p 9600:9600/udp \
  -p 9601:9601/tcp \
  -p 9601:9601/udp \
  acc-server
```

If your host UID differs from 1000, build the image first with matching args:

```sh
docker build --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t acc-server .
```

## Configuration

The ACC server expects configuration files in a `cfg/` directory next to the executable. The docker-compose setup mounts local directories:

```
project/
├── cfg/            # mounted to /app/server/cfg
│   ├── configuration.json
│   ├── settings.json
│   └── event.json
├── results/        # mounted to /app/server/results
├── log/            # mounted to /app/server/log
└── docker-compose.yml
```

After downloading the server files with SteamCMD, copy the default config into the local cfg directory:

```sh
cp -a ./acc-server/cfg/* ./cfg/
```

If `configuration.json` uses a custom `udpPort` / `tcpPort`, adjust the `-p` mappings accordingly. Remember that the ACC lobby handshake always uses `udpPort + 1` for both TCP and UDP.

**Important:** The HTTP broadcasting API is used by the container healthcheck. Enable it in your `settings.json`:

```json
{
  "httpServerPort": 8081,
  "httpServerPassword": "your-password"
}
```

## File Permissions

### Why Permissions Matter

Proton requires the directory hosting its Wine prefix to be **owned** by the user running the process — it is not enough for the directory to be writable. The container runs as a non-root user, and the ACC server files are bind-mounted from the host. If the host files are owned by a different UID than the container user, Proton refuses to start.

### How It Works

The image solves this by placing Proton's compatdata (Wine prefix) **inside the container** (at `/app/compatdata`), where the container user always owns the directory. The bind-mounted server directory is used only for the ACC server executable and its data — Proton does not try to write its own configuration there.

For the ACC server to write configs, results and logs to the mounted volumes, the container user needs write permission on those directories. This is handled by matching the container user's UID/GID to the host file owner at build time.

### Matching UIDs (Recommended)

Build the image with your host user's UID and GID:

```sh
UID=$(id -u) GID=$(id -g) docker compose build --no-cache
```

Or with plain Docker:

```sh
docker build --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t acc-server .
```

### World-Writable Fallback (Pre-built Images)

If you are using the pre-built image from `ghcr.io` (which uses UID 1000) and your host files are owned by a different user, make the directory world-writable:

```sh
chmod -R 777 ./acc-server
```

This is the same approach used by many Docker game server images and works because the Wine prefix itself lives inside the container.

## Ports and Networking

| Port | Protocol | Purpose |
|------|----------|---------|
| 9600 | TCP + UDP | Main server (client connections and query) |
| 9601 | TCP + UDP | Lobby registration handshake (9600 + 1) |
| 8081 | TCP | HTTP broadcasting API (healthcheck) |

Port 8081 is used only for container health monitoring and does not need to be published unless external health checks are desired.

## Healthcheck

The container runs a healthcheck every 30 seconds that verifies the ACC HTTP broadcasting API is reachable on `localhost:8081`. It allows a 5-minute startup grace period and requires 3 consecutive failures before marking the container unhealthy.

The health status can be checked with:

```sh
docker inspect --format='{{json .State.Health}}' acc-server | jq
```

## Volumes

| Path | Purpose |
|------|---------|
| `/app/server` | ACC server executables (read-only from host) |
| `/app/server/cfg` | Server configuration files |
| `/app/server/results` | Race result files |
| `/app/server/log` | Server log files |
| `/app/compatdata` | Proton Wine prefix (named volume, persistent) |

Proton stores its configuration (Wine prefix, drive mappings) at `/app/compatdata` inside the container. This directory uses a named Docker volume and is always owned by the container user.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `STEAM_COMPAT_DATA_PATH` | `/app/compatdata` | Proton wine prefix location |
| `STEAM_COMPAT_CLIENT_INSTALL_PATH` | `/nonexistent` | Dummy Steam client path (required by Proton) |
| `UMU_ID` | `acc-server` | UMU game identifier |
| `STORE` | `none` | Store type for Proton |
| `WINEDEBUG` | `-all` | Suppresses Wine debug output |

### Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `UID` | `1000` | UID of the container user. Set to `$(id -u)` to match your host user. |
| `GID` | `1000` | GID of the container user. Set to `$(id -g)` to match your host group. |

## Stopping the Server

The container is configured with `STOPSIGNAL SIGTERM`. To stop gracefully:

```sh
docker stop acc-server
```

Tini (`ENTRYPOINT`) forwards signals to the process group, ensuring a reliable shutdown even if the ACC process becomes unresponsive.

## Viewing Logs

```sh
docker logs -f acc-server
```

## Updating the ACC Server

To update the ACC dedicated server files without rebuilding the Docker image:

```sh
steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir ./acc-server +login YOUR_STEAM_ACCOUNT +app_update 1430110 +quit
docker compose restart
```

If using a pre-built image, also pull the latest version:

```sh
docker pull ghcr.io/shyrack/dockered-assetto-corsa-competizione-server:0
```

## CI/CD

This repository includes a GitHub Actions workflow (`.github/workflows/workflow.yaml`) that builds and publishes the Docker image to `ghcr.io` on every tagged release matching `releases/*`. The workflow:

- Builds for `linux/amd64`
- Tags images with SemVer (`0.0.1`, `0.0`, `0`) and Git SHA

Manual dispatches are also supported via `workflow_dispatch`.

## Contributing

Contributions are welcome. Please open an issue or pull request on [GitHub](https://github.com/shyrack/dockered-assetto-corsa-competizione-server).

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
