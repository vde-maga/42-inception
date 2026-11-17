# Inception — User Documentation

## Stack services

| Service | Role | Exposure |
|---|---|---|
| **nginx** | HTTPS entrypoint (TLS 1.2/1.3), serves static files, proxies PHP to WordPress | Port **443** (the only public port) |
| **wordpress** | WordPress + PHP-FPM, runs the website logic | Internal only (port 9000) |
| **mariadb** | Database server | Internal only (port 3306) |

Website files and the database persist in Docker named volumes, stored under
`/home/vde-maga/data` on the host.

## Start and stop

From the repository root:

```
make up      # build (if needed) and start everything
make down    # stop and remove containers — your data is kept
make re      # full rebuild from scratch — WARNING: deletes all data
```

## Access the website

From **inside the VM** (the domain is resolved by the VM's `/etc/hosts`):

- Website: `https://vde-maga.42.fr`
- Login page: `https://vde-maga.42.fr/wp-login.php`
- Admin panel: `https://vde-maga.42.fr/wp-admin`

The TLS certificate is **self-signed**: the browser will show a security
warning. This is expected — accept the exception to continue. Plain HTTP is
intentionally not served.

## Locate and manage credentials

Usernames are defined in `srcs/.env` (not secret). Passwords are stored in
git-ignored files under `secrets/`:

| Account | Username | Password file |
|---|---|---|
| WordPress administrator | `vde-maga` | `secrets/credentials.txt` |
| WordPress author | `carolina` | `secrets/credentials.txt` |
| MariaDB application user | `wpuser` | `secrets/db_password.txt` |
| MariaDB root (local access only) | `root` | `secrets/db_root_password.txt` |

To read a password: `cat secrets/credentials.txt`

To rotate passwords: edit the secret files, then run `make re` so the stack is
re-provisioned with the new values.

**Warning:** `make re` wipes the volumes —
all site content is lost. To change a password without losing data, update it
directly (e.g. `wp user update` inside the WordPress container, or `ALTER USER`
in MariaDB) instead of re-provisioning.

## Check that the services are running

```sh
# All three containers must be "Up"; only nginx publishes port 443
docker ps

# Website responds (expect HTTP/1.1 200 OK)
curl -kI https://vde-maga.42.fr

# NGINX: configuration is valid and the daemon is running as PID 1
docker exec nginx nginx -t
docker top nginx

# PHP-FPM: master + worker processes are running
docker top wordpress

# MariaDB: server answers a ping (use the password from secrets/db_password.txt)
docker exec -it mariadb mariadb-admin ping -u wpuser -p -h mariadb
# Expected output: "mysqld is alive"

# WordPress installation is healthy
docker exec -it wordpress wp core version --allow-root
docker exec -it wordpress wp user list --allow-root
```

If a service misbehaves, inspect its logs:

```sh
docker logs nginx
docker logs wordpress
docker logs mariadb
```

Containers restart automatically after a crash (`unless-stopped` policy). A
container stopped manually with `docker stop` stays stopped until you run
`docker start <name>` or `make up`.
