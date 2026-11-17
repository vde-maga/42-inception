# Inception — Developer Documentation

## Prerequisites

- A Linux VM (developed on **Alpine 3.23**)
- Docker Engine + Docker Compose v2
- `make`, `git`, `openssl`

On an Alpine VM:

```sh
doas apk update
doas apk add docker docker-cli-compose make git openssl
doas rc-update add docker boot
doas service docker start
doas addgroup $USER docker   # log out and back in afterwards
```

## Environment setup from scratch

### 1. Relocate Docker's data-root

The subject requires the named volumes' data to live in `/home/vde-maga/data`.
This is achieved by pointing the Docker daemon's `data-root` there (the volumes
remain Docker named volumes, not bind mounts):

```sh
mkdir -p /home/vde-maga/data
doas tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "data-root": "/home/vde-maga/data"
}
EOF
doas service docker restart
docker info | grep "Docker Root Dir"   # must show /home/vde-maga/data
```

### 2. Configure the domain

```sh
echo "127.0.0.1 vde-maga.42.fr" | doas tee -a /etc/hosts
```

### 3. Clone the repository

```sh
git clone https://github.com/vde-maga/42-inception.git
cd 42-inception
```

### 4. Configure `srcs/.env`

Non-sensitive configuration only — **no passwords in this file**:

```.env
DOMAIN_NAME=vde-maga.42.fr

MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_HOST=mariadb
MYSQL_PORT=3306

WP_TITLE=Inception
WP_ADMIN_USER=vde-maga
WP_ADMIN_EMAIL=vde-maga@student.42.fr
WP_USER=editor
WP_USER_EMAIL=editor@vde-maga.42.fr
```

*Note: the WordPress administrator username must not contain `admin` or
`administrator` (subject requirement).*

### 5. Create the secrets (git-ignored)

```sh
mkdir -p secrets
openssl rand -base64 24 > secrets/db_password.txt
openssl rand -base64 24 > secrets/db_root_password.txt
openssl rand -base64 24 > secrets/credentials.txt
```

| File | Purpose |
|---|---|
| `db_password.txt` | MariaDB application user (`wpuser`) password |
| `db_root_password.txt` | MariaDB `root` password (local socket access only) |
| `credentials.txt` | WordPress users password (admin `vde-maga` and author `editor`) |

The entrypoint scripts strip trailing newlines when reading secrets
(`tr -d '\n'`), so files created with `echo` are safe.

## Build and launch

From the repository root (the Makefile drives `srcs/docker-compose.yml`):

| Command | Effect |
|---|---|
| `make` / `make up` | Build images and start the stack (detached) |
| `make down` | Stop and remove containers (**data is kept**) |
| `make clean` | Same as `down` |
| `make fclean` | Remove containers, locally built images and volumes (**destroys data**) |
| `make re` | `fclean` + `up` — full rebuild from scratch |

All images are tagged `:inception` (the `latest` tag is prohibited).

## Managing containers and volumes

Compose commands (from the repo root):

```sh
docker compose -f srcs/docker-compose.yml ps
docker compose -f srcs/docker-compose.yml logs -f <service>
docker compose -f srcs/docker-compose.yml up -d --build
docker compose -f srcs/docker-compose.yml down
```

Useful Docker commands:

```sh
docker ps                          # running containers
docker ps -a                       # all containers, including stopped ones
docker inspect <container>         # full container details
docker top <container>             # processes inside a container (PID 1 check)
docker volume ls
docker volume inspect srcs_wp_data
docker volume rm <volume>
docker images                      # must show *:inception, no *:latest
```

WP-CLI (inside the WordPress container):

```sh
docker exec -it wordpress wp core version --allow-root
docker exec -it wordpress wp user list --allow-root
docker exec -it wordpress wp option get siteurl --allow-root
docker exec -it wordpress wp post list --allow-root
```

MariaDB access:

```sh
# Application user, via TCP (same path WordPress uses)
docker exec -it mariadb mariadb -u wpuser -p -h mariadb

# Root, via local socket only (remote root logins are disabled)
docker exec -it mariadb sh -c 'unset MYSQL_HOST; mariadb -u root -p'
```

## Where data is stored and how it persists

Data lives in two Docker **named volumes**, declared in `srcs/docker-compose.yml`:

| Volume | Mounted at | Content |
|---|---|---|
| `db_data` | `mariadb:/var/lib/mysql` | MariaDB database files |
| `wp_data` | `wordpress:/var/www/html` (rw), `nginx:/var/www/html` (ro) | WordPress files |

Because the Compose project name is `srcs` and the daemon's `data-root` was
relocated, the physical paths on the host are:

```
/home/vde-maga/data/volumes/srcs_db_data/_data
/home/vde-maga/data/volumes/srcs_wp_data/_data
```

Persistence rules:

- `make down` / `make clean` → containers removed, **volumes kept**: the site,
  posts and users survive.
- `make fclean` / `make re` → volumes deleted: everything is re-provisioned from
    scratch on the next `make up` (the entrypoint scripts detect empty volumes and
    re-run the full initialization).
- Changing secrets or `.env` values only takes effect on a fresh provision
    (`make re`), since initialization is skipped when data already exists.

## Verification

```sh
# All three containers Up, only nginx publishes a port (443)
docker ps

# Website responds
curl -kI https://vde-maga.42.fr        # expect HTTP/1.1 200 OK

# TLS: 1.2 and 1.3 must succeed
openssl s_client -connect vde-maga.42.fr:443 -tls1_2 </dev/null
openssl s_client -connect vde-maga.42.fr:443 -tls1_3 </dev/null
# TLS: 1.1 and 1.0 must fail
openssl s_client -connect vde-maga.42.fr:443 -tls1_1 </dev/null

# Restart policy (stack must be running detached, i.e. started via make)
docker inspect -f '{{.Name}} {{.HostConfig.RestartPolicy.Name}}' mariadb wordpress nginx
docker kill wordpress && sleep 5 && docker ps --filter name=wordpress
# The container must come back "Up" on its own.
# Note: `docker stop` is a manual stop and will NOT trigger a restart
# with the unless-stopped policy — use `docker kill` to simulate a crash.
```
