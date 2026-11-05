#!/bin/sh
set -e

if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB Data Folder..."
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null

    echo "Starting Temporary MariaDB to Configure Users..."
    mariadbd --user=mysql --datadir=/var/lib/mysql --skip-networking &
    TEMP_PID=$!
    
    sleep 3

    DB_ROOT_PASSWORD=$(tr -d '\n' < /run/secrets/db_root_password)
    DB_PASSWORD=$(tr -d '\n' < /run/secrets/db_password)

    echo "Configuring Users and Database..."
    
    unset MYSQL_HOST
    
    mariadb -u root <<-EOSQL
        DELETE FROM mysql.global_priv WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
        CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
        CREATE USER IF NOT EXISTS \`${MYSQL_USER}\`@'%' IDENTIFIED BY '${DB_PASSWORD}';
        GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO \`${MYSQL_USER}\`@'%';
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
        FLUSH PRIVILEGES;
EOSQL

    kill -s SIGTERM $TEMP_PID
    wait $TEMP_PID 2>/dev/null || true
fi

echo "Starting MariaDB..."
exec mariadbd --user=mysql --datadir=/var/lib/mysql
