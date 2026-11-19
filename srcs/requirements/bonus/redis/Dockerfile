FROM alpine:3.23

RUN apk update && apk upgrade && \
    apk add --no-cache redis

RUN set -eux; \
    grep -q '^redis:' /etc/group || addgroup -S redis; \
    grep -q '^redis:' /etc/passwd || adduser -S -D -H -G redis redis; \
    mkdir -p /etc/redis /var/lib/redis; \
    chown -R redis:redis /var/lib/redis

COPY conf/redis.conf /etc/redis/redis.conf
COPY tools/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

EXPOSE 6379

USER redis

ENTRYPOINT ["/usr/local/bin/init.sh"]
