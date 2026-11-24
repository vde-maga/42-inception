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

Alpine uses OpenRC, not systemd: use `doas rc-service docker <start|stop|restart>`.
Docker daemon logs are in `/var/log/docker.log` (there is no `journalctl`).

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

Non-sensitive configuration only — **no passwords in this file**. The committed
`.env` is authoritative; this mirrors it:

```dotenv
DOMAIN_NAME=vde-maga.42.fr

MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_HOST=mariadb
MYSQL_PORT=3306

WP_TITLE=Inception
WP_ADMIN_USER=vde-maga
WP_ADMIN_EMAIL=mega_email@gaming.pt
WP_USER=carolina
WP_USER_EMAIL=carolina@gaming.pt

# Redis (bonus)
REDIS_HOST=redis
REDIS_PORT=6379

# FTP (bonus)
FTP_USER=ftpuser
FTP_PASV_ADDRESS=127.0.0.1
FTP_PASV_MIN=30000
FTP_PASV_MAX=30009
```

*Note: the WordPress administrator username must not contain `admin` or
`administrator` (subject requirement).*

`FTP_PASV_ADDRESS` is the address Pure-FTPd advertises in PASV replies.
`127.0.0.1` works for clients running inside the VM; set it to the VM's LAN IP
for external clients.

### 5. Create the secrets (git-ignored)

```sh
mkdir -p secrets
openssl rand -base64 24 > secrets/db_password.txt
openssl rand -base64 24 > secrets/db_root_password.txt
openssl rand -base64 24 > secrets/credentials.txt
openssl rand -base64 24 > secrets/redis_password.txt
openssl rand -base64 24 > secrets/ftp_password.txt
```

| File | Purpose |
|---|---|
| `db_password.txt` | MariaDB application user (`wpuser`) password |
| `db_root_password.txt` | MariaDB `root` password (local socket access only) |
| `credentials.txt` | WordPress users password (`vde-maga` and `carolina`) |
| `redis_password.txt` | Redis `requirepass` *(bonus)* |
| `ftp_password.txt` | FTP virtual user `ftpuser` *(bonus)* |

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

### Published ports

| Port | Service | Notes |
|---|---|---|
| `443` | nginx → WordPress | mandatory: the only web entrypoint |
| `8443` | nginx → Adminer | bonus |
| `8444` | nginx → static site | bonus |
| `21` + `30000-30009` | ftp | bonus; fixed passive range required by Docker |

Redis, MariaDB, WordPress, Adminer and the static container's internal nginx are
**not** published — they are reachable only on the `inception` network.

## Managing containers and volumes

Compose commands (from the repo root):

```sh
docker compose -f srcs/docker-compose.yml ps
docker compose -f srcs/docker-compose.yml logs -f <service>
docker compose -f srcs/docker-compose.yml up -d --build
docker compose -f srcs/docker-compose.yml up -d --build <service>
docker compose -f srcs/docker-compose.yml down
```

Changing `ports:` requires **recreating** the container, not just restarting it:
`docker compose -f srcs/docker-compose.yml up -d <service>`.

Useful Docker commands:

```sh
docker ps                          # running containers
docker ps -a                       # all containers, including stopped ones
docker inspect <container>         # full container details
docker top <container>             # processes inside a container (PID 1 check)
docker port nginx                  # published port mappings
docker volume ls
docker volume inspect srcs_wp_data
docker volume rm <volume>
docker images                      # must show *:inception, no *:latest
```

### WordPress (WP-CLI)

```sh
docker exec -it wordpress wp core version --allow-root
docker exec -it wordpress wp user list --allow-root
docker exec -it wordpress wp option get siteurl --allow-root
docker exec -it wordpress wp post list --allow-root
docker exec -it wordpress wp plugin list --allow-root
docker exec -it wordpress wp redis status --allow-root   # bonus
docker exec wordpress php -m                            # loaded PHP extensions
```

### MariaDB

```sh
# Application user, via TCP (same path WordPress uses)
docker exec -it mariadb mariadb -u wpuser -p -h mariadb

# Root, via local socket only (remote root logins are disabled)
docker exec -it mariadb sh -c 'unset MYSQL_HOST; mariadb -u root -p'
```

### Redis (bonus)

```sh
docker exec -e REDISCLI_AUTH="$(cat secrets/redis_password.txt)" redis redis-cli ping
docker exec -e REDISCLI_AUTH="$(cat secrets/redis_password.txt)" redis redis-cli dbsize
docker exec -e REDISCLI_AUTH="$(cat secrets/redis_password.txt)" redis redis-cli info stats
docker exec -e REDISCLI_AUTH="$(cat secrets/redis_password.txt)" redis redis-cli config get save
docker exec redis redis-cli ping     # must fail with NOAUTH
```

### FTP (bonus)

```sh
docker logs ftp
docker top ftp                                    # sessions (pure-ftpwho is not built in Alpine)
docker exec ftp pure-pw list -f /etc/pure-ftpd/pureftpd.passwd
curl --user "ftpuser:$(cat secrets/ftp_password.txt)" ftp://127.0.0.1/
```

The FTP virtual user is mapped to the uid/gid of `nobody` (65534), which owns the
WordPress files, so uploads are immediately usable by PHP-FPM without any
permission changes.

### Static site (bonus)

Source lives in `srcs/requirements/bonus/static/site/` (a Hugo project).
Edit `content/*.md` or `hugo.toml`, then rebuild the image:

```sh
docker compose -f srcs/docker-compose.yml up -d --build static
docker exec static ls /var/www/static
```

The site is baked into the image at build time by a **multi-stage** Dockerfile:
stage 1 runs Hugo, stage 2 copies the output into an nginx image. There is no
bind mount and no runtime generation. The local theme `themes/inception` is a
fallback; switching themes means changing the `theme` value in `hugo.toml`.

Alpine ships `hugo v0.152.2+extended`, so SCSS-based themes work; themes requiring
npm/PostCSS do not.

## Where data is stored and how it persists

Data lives in two Docker **named volumes**, declared in `srcs/docker-compose.yml`:

| Volume | Mounted at | Content |
|---|---|---|
| `db_data` | `mariadb:/var/lib/mysql` | MariaDB database files |
| `wp_data` | `wordpress:/var/www/html` (rw), `nginx:/var/www/html` (ro), `ftp:/var/www/html` (rw) | WordPress files |

Because the Compose project name is `srcs` and the daemon's `data-root` was
relocated, the physical paths on the host are:

```
/home/vde-maga/data/volumes/srcs_db_data/_data
/home/vde-maga/data/volumes/srcs_wp_data/_data
```

Redis has **no volume**: it is a pure object cache with `save ""` and
`appendonly no`, so nothing needs to survive a restart. FTP reuses `wp_data`
rather than creating its own volume, which is what the subject asks for. Adminer
and the static site are stateless and need no volume either.

Persistence rules:

- `make down` / `make clean` → containers removed, **volumes kept**: the site,
  posts and users survive.
- `make fclean` / `make re` → volumes deleted: everything is re-provisioned from
  scratch on the next `make up` (the entrypoint scripts detect empty volumes and
  re-run the full initialization).
- Changing secrets or `.env` values that affect provisioning only takes effect on
  a fresh provision (`make re`). Redis and FTP credentials are re-read on every
  container start.

## Verification

```sh
# All seven containers Up
docker ps

# Web endpoints
curl -kI https://vde-maga.42.fr        # expect HTTP/1.1 200 OK
curl -kI https://vde-maga.42.fr:8443   # Adminer
curl -kI https://vde-maga.42.fr:8444   # static site

# TLS 1.2/1.3 only, on all three vhosts (authoritative check: the config itself)
docker exec nginx grep -c 'ssl_protocols TLSv1.2 TLSv1.3' /etc/nginx/http.d/default.conf
# must print 3

openssl s_client -connect vde-maga.42.fr:443 -tls1_2 </dev/null
openssl s_client -connect vde-maga.42.fr:443 -tls1_3 </dev/null
# Note: a `-tls1_1` failure may come from the client refusing the protocol,
# so the config check above is the reliable proof.

# Volumes in the required location
docker volume inspect srcs_db_data srcs_wp_data --format '{{.Name}} {{.Mountpoint}}'

# No credentials tracked by git
git ls-files secrets/       # must be empty
git ls-files srcs/.env      # must be tracked
```

### Testing crash recovery correctly

`docker kill` and `docker stop` are treated by Docker as **manual stops**, so the
restart policy is deliberately ignored until the daemon restarts. This is
documented Docker behaviour, not a project defect. To simulate a real crash, kill
the process inside the container instead, after it has been up for at least 10
seconds (a restart policy only applies once a container has started successfully):

```sh
docker inspect -f '{{.Name}} {{.HostConfig.RestartPolicy.Name}}' \
  mariadb wordpress nginx redis ftp adminer static

sleep 15
docker exec wordpress kill -TERM 1
sleep 5
docker ps --filter name=wordpress --format '{{.Names}} {{.Status}}'   # Up again
```

Use `-TERM`, not `-9`: PID 1 in a namespace ignores SIGKILL sent from inside, but
signals it has a handler for (SIGTERM) are delivered.

Proof that a restart happened:

```sh
docker inspect nginx --format 'Started={{.State.StartedAt}} Finished={{.State.FinishedAt}}'
# Started must be later than Finished
```

### End-to-end bonus proofs

```sh
# Redis is serving cache hits
curl -k https://vde-maga.42.fr > /dev/null
docker exec -e REDISCLI_AUTH="$(cat secrets/redis_password.txt)" redis redis-cli info stats | grep keyspace

# A file uploaded over FTP is served by nginx from the same volume
echo "ftp bonus ok" > /tmp/ftp-test.txt
curl -T /tmp/ftp-test.txt --user "ftpuser:$(cat secrets/ftp_password.txt)" ftp://127.0.0.1/
docker exec wordpress ls -l /var/www/html/ftp-test.txt
curl -k https://vde-maga.42.fr/ftp-test.txt

# Adminer can authenticate to MariaDB (extension + network + credentials)
docker exec -e DBP="$(cat secrets/db_password.txt)" adminer \
  php83 -r '$c = @new mysqli("mariadb", "wpuser", getenv("DBP"), "wordpress"); echo $c->connect_error ? "FAIL\n" : "OK\n";'

# The static runtime image contains neither PHP nor Hugo
docker exec static sh -c 'command -v php hugo || echo "none"'
```

Note: inside the Adminer container the PHP binary is `php83`. Only the WordPress
image has a `php → php83` symlink, because WP-CLI's shebang requires `php` in
`$PATH`; Adminer is executed by PHP-FPM and needs no CLI alias.

## Project structure

```
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/                      # git-ignored, created locally
└── srcs/
    ├── .env
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/              # Dockerfile, conf/, tools/
        ├── nginx/                # Dockerfile, conf/, tools/
        ├── wordpress/            # Dockerfile, conf/, tools/
        └── bonus/
            ├── redis/            # Dockerfile, conf/, tools/
            ├── ftp/              # Dockerfile, tools/
            ├── adminer/          # Dockerfile, conf/
            └── static/           # Dockerfile, conf/, site/ (Hugo)
```
