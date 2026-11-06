FROM alpine:3.23

RUN apk update && apk upgrade && \
    apk add --no-cache \
    curl \
    less \
    php83 \
    php83-fpm \
    php83-mysqli \
    php83-curl \
    php83-mbstring \
    php83-phar \
    php83-openssl \
    php83-gd \
    php83-xml \
    php83-intl \
    php83-tokenizer \
    php83-fileinfo \
    php83-dom \
    php83-session \
    php83-zip

RUN ln -s /usr/bin/php83 /usr/bin/php

RUN mkdir -p /var/www/html && \
    chown -R nobody:nobody /var/www/html

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

COPY conf/www.conf /etc/php83/php-fpm.d/www.conf
COPY conf/php.ini /etc/php83/conf.d/99-custom.ini
COPY tools/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/init.sh"]
