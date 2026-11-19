#!/bin/sh
set -e

REDIS_PASSWORD=$(tr -d '\n' < /run/secrets/redis_password)

umask 077
cat /etc/redis/redis.conf > /tmp/redis.conf
printf 'requirepass "%s"\n' "$REDIS_PASSWORD" >> /tmp/redis.conf

echo "Starting Redis..."
exec redis-server /tmp/redis.conf
