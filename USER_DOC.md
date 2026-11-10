# USER_DOC.md

## What this stack provides
This project runs a WordPress site over HTTPS using three containers:
- **nginx**: the only public entrypoint, serving TLS 1.2/1.3 on port 443.
- **wordpress**: WordPress + PHP-FPM (no nginx inside), reachable only internally on port 9000.
- **mariadb**: the database, reachable only internally on port 3306.

Two named volumes persist data: `db_data` (database) and `wp_data` (website files).

## Start and stop
From the repository root:
- `make` (or `make up`) — build and start the stack.
- `make down` — stop and remove containers (data is kept).
- `make re` — full rebuild from scratch.
- `make fclean` — stop, remove containers, images and volumes (destroys data).

## Access the website
Inside the VM, open: `https://vde-maga.42.fr`
The certificate is self-signed, so the browser shows a warning — accept it to continue.
Admin panel: `https://vde-maga.42.fr/wp-admin`

## Credentials
Passwords are **not** stored in the repository. They live in local files under `secrets/`:
- `secrets/credentials.txt` — WordPress admin password.
- `secrets/db_password.txt` — MariaDB application user password.
- `secrets/db_root_password.txt` — MariaDB root password.

Default WordPress users:
- Administrator: `vde-maga` (password in `secrets/credentials.txt`).
- Author: `editor` (same password file).

## Check services are running
- `docker ps` — the three containers must be `Up`.
- `docker logs <container>` — inspect a service.
- `curl -kI https://vde-maga.42.fr` — must return `HTTP/1.1 200 OK`.
