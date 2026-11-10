# DEV_DOC.md

## Prerequisites
- A Linux VM with Docker and Docker Compose v2 installed.
- Docker data-root redirected so named volumes land in `/home/vde-maga/data`:
  edit `/etc/docker/daemon.json` with `{"data-root": "/home/vde-maga/data"}` and restart Docker.
- `/etc/hosts` entry: `127.0.0.1 vde-maga.42.fr`.

## Setup from scratch
1. Clone the repository.
2. Create the secret files (they are git-ignored):
   - `secrets/credentials.txt`
   - `secrets/db_password.txt`
   - `secrets/db_root_password.txt`
   Generate strong values, e.g. `openssl rand -base64 24`.
3. Adjust `srcs/.env` if needed (domain, DB name/users — no passwords here).

## Build and launch
- `make` builds the images via `srcs/docker-compose.yml` and starts the stack.
- `make re` forces a clean rebuild.

## Managing containers and volumes
- `docker compose -f srcs/docker-compose.yml ps`
- `docker compose -f srcs/docker-compose.yml logs -f <service>`
- `docker volume ls` / `docker volume inspect srcs_wp_data`
- `docker exec -it wordpress wp <command> --allow-root`

## Where data is stored and how it persists
Data lives in Docker **named volumes** (`db_data`, `wp_data`), not bind mounts.
Because of the custom `data-root`, the physical files are under:
`/home/vde-maga/data/volumes/<volume>/_data`.
Volumes survive `make down`; only `make fclean` (`-v`) deletes them.
