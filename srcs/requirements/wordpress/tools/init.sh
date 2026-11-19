#!/bin/sh
set -e

DB_PASSWORD=$(tr -d '\n' < /run/secrets/db_password)
WP_ADMIN_PASS=$(tr -d '\n' < /run/secrets/credentials)

export WP_CLI_CACHE_DIR=/tmp/wp-cli-cache
mkdir -p "$WP_CLI_CACHE_DIR"

cd /var/www/html

echo "Waiting for MariaDB to be ready..."
until php -r "new mysqli('${MYSQL_HOST}', '${MYSQL_USER}', '${DB_PASSWORD}', '${MYSQL_DATABASE}');" > /dev/null 2>&1; do
    sleep 1
done
echo "MariaDB is ready!"

if [ ! -f "/var/www/html/wp-config.php" ]; then

    if [ ! -f "/var/www/html/wp-includes/version.php" ]; then
        echo "Downloading WordPress..."
        wp core download --allow-root
    else
        echo "WordPress files already downloaded, skipping..."
    fi

    echo "Creating wp-config.php..."
    wp config create \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${DB_PASSWORD}" \
        --dbhost="${MYSQL_HOST}" \
        --allow-root

    echo "Setting filesystem method..."
    wp config set FS_METHOD direct --allow-root

    echo "Installing WordPress..."
    wp core install \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASS}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --allow-root

    echo "Creating secondary user..."
    wp user create \
        "${WP_USER}" "${WP_USER_EMAIL}" \
        --role=author \
        --user_pass="${WP_ADMIN_PASS}" \
        --allow-root
fi

if [ -f /run/secrets/redis_password ]; then
    if [ ! -f /var/www/html/wp-content/object-cache.php ] || \
       ! wp config has WP_REDIS_HOST --allow-root > /dev/null 2>&1; then

        REDIS_PASSWORD=$(tr -d '\n' < /run/secrets/redis_password)

        echo "Waiting for Redis..."
        i=0
        until php -r "exit(@fsockopen('${REDIS_HOST}', ${REDIS_PORT}, \$e, \$s, 1) ? 0 : 1);" > /dev/null 2>&1; do
            i=$((i + 1))
            if [ "$i" -ge 30 ]; then break; fi
            sleep 1
        done

        if ! wp plugin is-installed redis-cache --allow-root > /dev/null 2>&1; then
            echo "Installing Redis Object Cache plugin..."
            wp plugin install redis-cache --activate --allow-root
        else
            wp plugin activate redis-cache --allow-root > /dev/null 2>&1 || true
        fi

        echo "Configuring Redis in wp-config.php..."
        wp config set WP_CACHE true --raw --allow-root > /dev/null
        wp config set WP_REDIS_CLIENT phpredis --allow-root > /dev/null
        wp config set WP_REDIS_HOST "${REDIS_HOST}" --allow-root > /dev/null
        wp config set WP_REDIS_PORT "${REDIS_PORT}" --raw --allow-root > /dev/null
        wp config set WP_REDIS_PASSWORD "${REDIS_PASSWORD}" --allow-root > /dev/null
        wp config set WP_REDIS_DATABASE 0 --raw --allow-root > /dev/null
        wp config set WP_REDIS_TIMEOUT 1 --raw --allow-root > /dev/null
        wp config set WP_REDIS_READ_TIMEOUT 1 --raw --allow-root > /dev/null

        echo "Enabling Redis object cache drop-in..."
        wp redis enable --allow-root || true
    else
        echo "Redis object cache already configured, skipping..."
    fi
fi

chown -R nobody:nobody /var/www/html

echo "Starting PHP-FPM..."
exec php-fpm83 -F
