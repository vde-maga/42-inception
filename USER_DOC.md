# Inception — User Documentation

## Stack services

| Service | Role | Exposure |
|---|---|---|
| **nginx** | HTTPS entrypoint (TLS 1.2/1.3 only), serves static files, proxies PHP to WordPress and Adminer, and the static site | Ports **443**, **8443**, **8444** |
| **wordpress** | WordPress + PHP-FPM, runs the website logic | Internal only (9000) |
| **mariadb** | Database server | Internal only (3306) |
| **redis** *(bonus)* | Object cache for WordPress — speeds up page loads | Internal only (6379) |
| **ftp** *(bonus)* | Pure-FTPd file access to the WordPress files | Ports **21** + **30000-30009** |
| **adminer** *(bonus)* | Database administration UI | HTTPS **8443** |
| **static** *(bonus)* | Showcase site generated with Hugo | HTTPS **8444** |

Website files and the database persist in Docker named volumes, stored under
`/home/vde-maga/data` on the host. Redis is a pure cache and intentionally has no
persistent volume.

## Start and stop

From the repository root:

```sh
make up      # build (if needed) and start everything
make down    # stop and remove containers — your data is kept
make re      # full rebuild from scratch — WARNING: deletes all data
```

## Access the services

From **inside the VM** (the domain is resolved by the VM's `/etc/hosts`):

| What | URL |
|---|---|
| Website | `https://vde-maga.42.fr` |
| WordPress login | `https://vde-maga.42.fr/wp-login.php` |
| WordPress admin panel | `https://vde-maga.42.fr/wp-admin` |
| Adminer *(bonus)* | `https://vde-maga.42.fr:8443` |
| Static site *(bonus)* | `https://vde-maga.42.fr:8444` |

The TLS certificate is **self-signed**: the browser will show a security
warning. This is expected — accept the exception to continue.

**Plain HTTP is intentionally not served.** Requesting any of these addresses
with `http://` instead of `https://` returns
`400 Bad Request — The plain HTTP request was sent to HTTPS port`. This is
correct behaviour: the subject requires TLS 1.2/1.3 only.

### Adminer login

| Field | Value |
|---|---|
| System | MySQL / MariaDB |
| **Server** | `mariadb` — **do not leave `localhost`** |
| Username | `wpuser` |
| Password | contents of `secrets/db_password.txt` |
| Database | `wordpress` |

The MariaDB `root` account **cannot** log in here: it only accepts local socket
connections, by design.

### FTP access

| Setting | Value |
|---|---|
| Host | `127.0.0.1` (or `vde-maga.42.fr`) |
| Port | `21` |
| User | `ftpuser` |
| Password | contents of `secrets/ftp_password.txt` |
| Mode | **passive** |

The FTP user is jailed in the WordPress directory, so a file uploaded there is
immediately available over HTTPS. Anonymous login is refused.

Quick test without an FTP client:

```sh
curl --user "ftpuser:$(cat secrets/ftp_password.txt)" ftp://127.0.0.1/
```

To connect from another machine, set `FTP_PASV_ADDRESS` in `srcs/.env` to the
VM's LAN IP address and run `make up` again — FTP must advertise an address the
client can reach for data connections.

## Locate and manage credentials

Usernames are defined in `srcs/.env` (not secret). Passwords are stored in
git-ignored files under `secrets/`:

| Account | Username | Password file |
|---|---|---|
| WordPress administrator | `vde-maga` | `secrets/credentials.txt` |
| WordPress author | `carolina` | `secrets/credentials.txt` |
| MariaDB application user | `wpuser` | `secrets/db_password.txt` |
| MariaDB root (local access only) | `root` | `secrets/db_root_password.txt` |
| Redis *(bonus)* | — (password only) | `secrets/redis_password.txt` |
| FTP *(bonus)* | `ftpuser` | `secrets/ftp_password.txt` |

To read a password: `cat secrets/credentials.txt`

To rotate passwords: edit the secret files, then run `make re` so the stack is
re-provisioned with the new values.

**Warning:** `make re` wipes the volumes — all site content is lost. To change a
password without losing data, update it directly (e.g. `wp user update` inside
the WordPress container, or `ALTER USER` in MariaDB) instead of re-provisioning.
Redis and FTP credentials are re-read on every container start, so a restart is
enough for those.

## Check that the services are running

```sh
# All seven containers must be "Up"
docker ps

# Website responds (expect HTTP/1.1 200 OK)
curl -kI https://vde-maga.42.fr
curl -kI https://vde-maga.42.fr:8443   # Adminer
curl -kI https://vde-maga.42.fr:8444   # static site

# NGINX: configuration is valid and the daemon is running as PID 1
docker exec nginx nginx -t
docker top nginx

# PHP-FPM: master + worker processes are running
docker top wordpress
docker top adminer

# MariaDB: server answers a ping (use the password from secrets/db_password.txt)
docker exec -it mariadb mariadb-admin ping -u wpuser -p -h mariadb
# Expected output: "mysqld is alive"

# WordPress installation is healthy
docker exec -it wordpress wp core version --allow-root
docker exec -it wordpress wp user list --allow-root

# Redis (bonus): plugin connected to the cache
docker exec wordpress wp redis status --allow-root | head -6
# Expected: "Status: Connected"

# Redis (bonus): proof the cache is actually used
docker exec -e REDISCLI_AUTH="$(cat secrets/redis_password.txt)" redis redis-cli dbsize
docker exec -e REDISCLI_AUTH="$(cat secrets/redis_password.txt)" redis redis-cli info stats | grep keyspace

# FTP (bonus): server processes and active sessions
docker logs ftp
docker top ftp

# Static site (bonus): no PHP and no Hugo in the runtime image
docker exec static sh -c 'command -v php hugo || echo "none"'
```

If a service misbehaves, inspect its logs:

```sh
docker logs nginx
docker logs wordpress
docker logs mariadb
docker logs redis
docker logs ftp
docker logs adminer
docker logs static
```

Containers restart automatically after a crash (`unless-stopped` policy). A
container stopped manually with `docker stop` stays stopped until you run
`docker start <name>` or `make up`.
