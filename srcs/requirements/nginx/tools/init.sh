#!/bin/sh
set -e

echo "Generating self-signed TLS certificate for ${DOMAIN_NAME}..."
mkdir -p /etc/nginx/ssl

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx.key \
    -out /etc/nginx/ssl/nginx.crt \
    -subj "/C=PT/ST=Lisbon/L=Lisbon/O=42/OU=Student/CN=${DOMAIN_NAME:-vde-maga.42.fr}"

echo "Starting NGINX..."
exec nginx -g 'daemon off;'
