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
- Built-in healthcheck via TCP connectivity to the ACC server port
- Pre-built images published to GitHub Container Registry
- Proper signal handling via `tini` and graceful shutdown via `SIGTERM`
- Server binaries mounted read-only from the host; config, results, logs, and the Proton prefix live inside the container

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

Pre-built images use the default UID 1000. If your host files are owned by a different user, see [File Permissions](#file-permissions) for matching UIDs.

If using the pre-built image, remove the `build:` section from `docker-compose.yaml` and reference the `ghcr.io` image directly:

## Running the Server

### Docker Compose (recommended)

```sh
docker compose up -d
```

The included `docker-compose.yaml`:

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
    environment:
      - ACC_SERVER_PORT=${ACC_SERVER_PORT:-9600}
    ports:
      - "${ACC_SERVER_PORT:-9600}:${ACC_SERVER_PORT:-9600}/tcp"
      - "${ACC_SERVER_PORT:-9600}:${ACC_SERVER_PORT:-9600}/udp"
      - "${ACC_LOBBY_PORT:-9601}:${ACC_LOBBY_PORT:-9601}/tcp"
      - "${ACC_LOBBY_PORT:-9601}:${ACC_LOBBY_PORT:-9601}/udp"
    volumes:
      - ./acc-server:/app:ro
```

The `build.args` pass your host user's UID/GID to the image. Set them via `UID=$(id -u) GID=$(id -g) docker compose build`.

### Docker CLI

```sh
docker run -d \
  --name acc-server \
  --restart unless-stopped \
  -v "$(pwd)/acc-server:/app:ro" \
  -e ACC_SERVER_PORT="${ACC_SERVER_PORT:-9600}" \
  -p "${ACC_SERVER_PORT:-9600}:${ACC_SERVER_PORT:-9600}/tcp" \
  -p "${ACC_SERVER_PORT:-9600}:${ACC_SERVER_PORT:-9600}/udp" \
  -p "${ACC_LOBBY_PORT:-9601}:${ACC_LOBBY_PORT:-9601}/tcp" \
  -p "${ACC_LOBBY_PORT:-9601}:${ACC_LOBBY_PORT:-9601}/udp" \
  acc-server
```

If your host UID differs from 1000, build the image first with matching args:

```sh
docker build --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t acc-server .
```

## Configuration

The ACC server uses configuration files from the `cfg/` directory inside the server bundle. The server bundle is mounted read-only at `/app` — config, results, and logs stay inside the container.

```
project/
├── acc-server/     # mounted read-only to /app
└── docker-compose.yaml
```

### Settings for Wine / Proton

Running the ACC server under Wine requires the `"ignorePrematureDisconnects"` setting to be set to `0` in `/app/cfg/settings.json`. Wine's TCP stack can cause false-positive premature disconnect detection, and disabling it prevents the server from booting players incorrectly.

```json
{
  "ignorePrematureDisconnects": 0
}
```

### Custom Ports

To run on non-default ports (e.g. 9620/9621):

1. Edit `./acc-server/cfg/configuration.json`:

   ```json
   {
     "tcpPort": 9620,
     "udpPort": 9620
   }
   ```

2. Set environment variables and start:

   ```sh
   ACC_SERVER_PORT=9620 ACC_LOBBY_PORT=9621 docker compose up -d
   ```

   Or create a `.env` file in the project root:

   ```
   ACC_SERVER_PORT=9620
   ACC_LOBBY_PORT=9621
   ```

   Docker Compose reads `.env` automatically.

The lobby port must always equal `udpPort + 1` (ACC convention). The `ACC_LOBBY_PORT` environment variable should match this.

If `configuration.json` uses a custom `udpPort` / `tcpPort`, adjust the env vars and port mappings accordingly. Remember that the ACC lobby handshake always uses `udpPort + 1` for both TCP and UDP.

## File Permissions

### Why Permissions Matter

Proton requires the directory hosting its Wine prefix to be **owned** by the user running the process — it is not enough for the directory to be writable. The container runs as a non-root user, and the ACC server files are bind-mounted from the host. If the host files are owned by a different UID than the container user, Proton refuses to start.

### How It Works

The image places Proton's compatdata (Wine prefix) **inside the container** (at `/app/compatdata`), where the container user always owns the directory. The server bundle is mounted read-only at `/app` — Proton never writes there.

### Matching UIDs (Recommended)

Build the image with your host user's UID and GID:

```sh
UID=$(id -u) GID=$(id -g) docker compose build --no-cache
```

Or with plain Docker:

```sh
docker build --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t acc-server .
```

### Pre-built Images

If you are using the pre-built image from `ghcr.io` (which uses UID 1000) and your host files are owned by a different user, create a matching user and group on the host:

```sh
groupadd --gid 1000 accserver
useradd --uid 1000 --gid 1000 --no-create-home accserver
chown -R 1000:1000 ./acc-server
```

## Ports and Networking

| Port | Protocol | Purpose |
|------|----------|---------|
| 9600 | TCP + UDP | Main server (client connections and query) |
| 9601 | TCP + UDP | Lobby registration handshake (9600 + 1) |

The default ports are shown above. Use `ACC_SERVER_PORT` and `ACC_LOBBY_PORT` to override them (see [Custom Ports](#custom-ports)). If `configuration.json` uses custom ports, keep the environment variables in sync — the container does not inject or validate port settings.

## Healthcheck

The container runs a healthcheck every 30 seconds that verifies the ACC server is listening on the lobby handshake port via a TCP connect check. By default this checks port 9601 (`ACC_LOBBY_PORT`). It allows a 5-minute startup grace period and requires 3 consecutive failures before marking the container unhealthy.

The healthcheck port adapts automatically to `ACC_LOBBY_PORT`. If you set `ACC_LOBBY_PORT=9621`, the healthcheck probes port 9621.

The health status can be checked with:

```sh
docker inspect --format='{{json .State.Health}}' acc-server | jq
```

## Volumes

| Path | Purpose |
|------|---------|
| `/app` | ACC server bundle — read-only bind mount from `./acc-server` on the host |

Configs, results, logs, and the Proton Wine prefix live on paths under `/app` inside the container's writable layer. The Proton compatdata directory at `/app/compatdata` is owned by the container user and persisted within the container's storage.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ACC_SERVER_PORT` | `9600` | Main server port (TCP + UDP). Must match `tcpPort`/`udpPort` in `configuration.json`. |
| `ACC_LOBBY_PORT` | `9601` | Lobby handshake port (TCP + UDP). Must equal `configuration.json`'s `udpPort + 1`. |
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
| `UMU_PROTON_VERSION` | `UMU-Proton-10.0-4` | Version of UMU-Proton to install. |
| `UMU_PROTON_SHA256` | (pinned) | SHA256 checksum of the Proton tarball for supply-chain verification. |

### Runtime Dependencies

- **python3** — required by UMU-Proton runtime scripts for process management and compatibility.

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
- Verifies the UMU-Proton download against a pinned SHA256 checksum
- Runs a smoke test to confirm Proton launches correctly
- Scans the image for CRITICAL and HIGH vulnerabilities with Trivy

Manual dispatches are also supported via `workflow_dispatch`.

## Contributing

Contributions are welcome. Please open an issue or pull request on [GitHub](https://github.com/shyrack/dockered-assetto-corsa-competizione-server).

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
