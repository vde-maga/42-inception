FROM alpine:3.23

RUN apk update && \
	apk upgrade && \
	apk add --no-cache mariadb mariadb-client

RUN mkdir -p /run/mysqld /var/lib/mysql && \
    chown -R mysql:mysql /run/mysqld /var/lib/mysql

COPY conf/my.cnf /etc/my.cnf.d/mariadb-server.cnf
COPY tools/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

EXPOSE 3306

# O script init.sh será o PID 1
ENTRYPOINT ["/usr/local/bin/init.sh"]

