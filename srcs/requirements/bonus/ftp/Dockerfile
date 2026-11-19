FROM alpine:3.23

RUN apk update && apk upgrade && \
    apk add --no-cache pure-ftpd

RUN mkdir -p /etc/pure-ftpd /var/www/html

COPY tools/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

EXPOSE 21 30000-30009

ENTRYPOINT ["/usr/local/bin/init.sh"]
