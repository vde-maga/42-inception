#!/bin/sh
set -e

DB_PASSWORD=$(tr -d '\n' < /run/secrets/db_password)
WP_ADMIN_PASS=$(tr -d '\n' < /run/secrets/credentials)

export WP_CLI_CACHE_DIR=/tmp/wp-cli-cache
mkdir -p "$WP_CLI_CACHE_DIR"

cd /var/www/html

if [ ! -f "/var/www/html/wp-config.php" ]; then

    if [ ! -f "/var/www/html/wp-includes/version.php" ]; then
        echo "Downloading WordPress..."
        wp core download --allow-root
    else
        echo "WordPress files already downloaded, skipping..."
    fi

    echo "Waiting for MariaDB to be ready..."
    until php -r "new mysqli('${MYSQL_HOST}', '${MYSQL_USER}', '${DB_PASSWORD}', '${MYSQL_DATABASE}');" > /dev/null 2>&1; do
        sleep 1
    done
    echo "MariaDB is ready!"

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

    chown -R nobody:nobody /var/www/html
fi

echo "Starting PHP-FPM..."
exec php-fpm83 -F
