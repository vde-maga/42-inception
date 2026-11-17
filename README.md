*This project has been created as part of the 42 curriculum by vde-maga.*

# Inception

Secure WordPress infrastructure deployment using Docker Compose on Alpine Linux.

## Description

Inception is a system administration project that consists of setting up a small
infrastructure of containerized services, following strict rules: one service per
container, custom-built images, TLS-only access, persistent named volumes, and
secrets kept out of the repository.

The stack is composed of three services, each built from its own Dockerfile based
on **Alpine 3.23** (the penultimate stable release, as of 2026/11/17):

- **nginx** — the only entrypoint into the infrastructure. Serves HTTPS on port
    443 with TLSv1.2/TLSv1.3 only, using a self-signed certificate generated at
    container startup. Proxies PHP requests to WordPress via FastCGI.
- **wordpress** — WordPress + PHP-FPM 8.3 (no nginx inside). Listens internally on
    port 9000. The site is downloaded, configured and installed automatically at
    first startup using WP-CLI, including the creation of two users.
- **mariadb** — the database server (no nginx inside). Listens internally on port
    3306. Initialized at first startup: database, application user and root
    password are created from environment variables and Docker secrets.

```
Browser ── HTTPS :443 ──► nginx ── FastCGI :9000 ──► wordpress ── TCP :3306 ──► mariadb
                          │                          │                          │
                          └──── wp_data (ro) ────────┴── wp_data ──┐   db_data ──┘
                                        Docker network: inception (bridge)
```

### Main design choices

- **Alpine over Debian**: minimal footprint and no "magic" init helpers — every
    daemon (`nginx`, `php-fpm83`, `mariadbd`) is launched explicitly in the
    foreground as PID 1 via `exec`, with no hacky keep-alive loops.
- **Automated provisioning**: entrypoint scripts are idempotent — they only
    provision on fresh volumes, so restarts never wipe data. WordPress waits for
    MariaDB to accept connections before installing (no race conditions).
- **Secrets**: all passwords live in `secrets/*.txt`, mounted as Docker secrets
    at `/run/secrets/`, and are git-ignored. Only non-sensitive configuration is
    stored in `srcs/.env`.
- **Persistence**: two Docker named volumes (`db_data`, `wp_data`). The Docker
    daemon's `data-root` is redirected so their data physically lives in
    `/home/vde-maga/data` on the host, while remaining true named volumes.
- **Resilience**: every service uses `restart: unless-stopped`.
- **No `latest` tag**: all images are tagged `:inception`.

Every service directory (`srcs/requirements/*/`) contains:

- a `Dockerfile` for image building
- configuration files (in `conf/`)
- an entrypoint script (in `tools/`)

### Virtual Machines vs Docker

Virtual machines emulate physical hardware. A VM runs its own kernel and full OS,
with a fixed amount of resources allocated from the host. This provides strong
isolation, at the cost of overhead and slower startup.

Docker containers virtualize user-space only. They share the host's kernel and
resources, making them lightweight and fast to start, with process-level
isolation instead of hardware-level isolation. In this project, the whole stack
runs inside a VM, and each service runs in its own container.

### Secrets vs Environment Variables

Environment variables are convenient for non-sensitive configuration (domain
name, database name, usernames). However, they are visible via `docker inspect`
and process environments, so they are not appropriate for credentials.

Docker secrets are mounted as files inside the container (`/run/secrets/<name>`)
only for the services that declare them. They are never baked into images or
Dockerfiles. In this project, `.env` holds configuration, while all passwords are
read from secrets at runtime.

### Docker Network vs Host Network

A user-defined bridge network provides container-to-container communication with
built-in DNS resolution (containers reach each other by service name), isolated
from the host. Inbound access requires explicit port publishing — here, only
nginx publishes port 443.

The host network removes isolation: containers share the host's network stack
directly. It can improve performance but exposes every listening port and is
forbidden by the subject. This project uses a dedicated bridge network named
`inception`.

### Docker Volumes vs Bind Mounts

Volumes are managed by Docker. They are abstracted from the host filesystem
layout, portable, and managed with Docker tooling (`docker volume ...`).

Bind mounts map an arbitrary host path into a container. They are useful for
development, but couple the container to the host's filesystem and let containers
modify host files directly. The subject forbids bind mounts for persistent
storage: this project uses named volumes, with the daemon's `data-root`
relocated to `/home/vde-maga/data` to satisfy the required data location.

## Instructions

### Requirements

- A Linux virtual machine (this project was developed on Alpine 3.23)
- [Docker Engine](https://docs.docker.com/engine/install/) and
  [Docker Compose v2](https://docs.docker.com/compose/install/)
- `make`, `git`, `openssl`

### Steps

1. Clone the repository:

```sh
git clone https://github.com/<your-user>/42-inception.git
cd 42-inception
```

2. Configure the VM (once):

- Set Docker's `data-root` to `/home/vde-maga/data` in `/etc/docker/daemon.json`
    and restart Docker.
- Add `127.0.0.1 vde-maga.42.fr` to `/etc/hosts`.

*See [DEV_DOC.md](DEV_DOC.md) for detailed commands.*

3. Review `srcs/.env` (non-sensitive configuration only):

```.env
DOMAIN_NAME=vde-maga.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_HOST=mariadb
WP_TITLE=Inception
WP_ADMIN_USER=vde-maga
WP_USER=editor
```

4. Create the secret files in `secrets/` (git-ignored):

- `db_password.txt` — MariaDB application user password
- `db_root_password.txt` — MariaDB root password
- `credentials.txt` — WordPress users password

*Example: `openssl rand -base64 24 > secrets/db_password.txt`*

5. Build and start:

```sh
make
```

The website is available at `https://vde-maga.42.fr` (from inside the VM).
The certificate is self-signed, so the browser will show a warning — this is
expected. See [USER_DOC.md](USER_DOC.md) for usage details.

## Resources

**Documentation**

- [Docker documentation](https://docs.docker.com/)
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
- [Compose file reference](https://docs.docker.com/reference/compose-file/)
- [Docker secrets](https://docs.docker.com/compose/how-tos/use-secrets/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [MariaDB documentation](https://mariadb.org/documentation/)
- [Alpine Linux package search](https://pkgs.alpinelinux.org/)
- [WP-CLI handbook](https://make.wordpress.org/cli/handbook/)

**Useful links**

- [Docker building best practices](https://docs.docker.com/build/building/best-practices/)
- [PID 1 and daemons in containers](https://docs.docker.com/build/building/best-practices/#pid-1)
- [NGINX beginner's guide](https://nginx.org/en/docs/beginners_guide.html)
- [Installing WordPress with WP-CLI](https://make.wordpress.org/cli/handbook/guides/installing/)
- [Installing MariaDB on Alpine](https://wiki.alpinelinux.org/wiki/MariaDB)

**AI usage**

An AI assistant was used throughout the project as a guided tutor and pair
debugger, specifically for:

- planning the architecture and the order of implementation;
- debugging Alpine-specific issues (versioned PHP binary names, missing PHP
    extensions, PHP memory limits, MariaDB socket-vs-TCP initialization, trailing
    newlines in secret files, startup race conditions between services);
- drafting this documentation.

All AI-generated content was applied incrementally, tested in the VM, reviewed
and modified as needed. Every component of the project was verified hands-on and
can be explained and modified during the evaluation.
