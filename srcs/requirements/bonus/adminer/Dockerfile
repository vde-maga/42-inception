FROM alpine:3.23

RUN apk update && apk upgrade && \
    apk add --no-cache \
    curl \
    php83 \
    php83-fpm \
    php83-mysqli \
    php83-session \
    php83-mbstring \
    php83-openssl \
    php83-ctype \
    php83-iconv

RUN mkdir -p /var/www/adminer && \
    chown -R nobody:nobody /var/www/adminer

RUN curl -fsSL -o /var/www/adminer/index.php https://www.adminer.org/latest.php && \
    chown nobody:nobody /var/www/adminer/index.php && \
    chmod 644 /var/www/adminer/index.php

COPY conf/www.conf /etc/php83/php-fpm.d/www.conf

EXPOSE 9000

ENTRYPOINT ["php-fpm83", "-F"]
