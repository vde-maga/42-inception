# Stage 1: gerar o site estatico com Hugo
FROM alpine:3.23 AS builder

RUN apk update && apk upgrade && \
    apk add --no-cache hugo

WORKDIR /src
COPY site/ .

ARG SITE_BASEURL=https://localhost:8444/
RUN hugo --minify --baseURL "${SITE_BASEURL}" --destination /public

# Stage 2: servir os ficheiros gerados com nginx (sem Hugo na imagem final)
FROM alpine:3.23

RUN apk update && apk upgrade && \
    apk add --no-cache nginx

RUN mkdir -p /run/nginx /var/www/static && \
    rm -f /etc/nginx/http.d/default.conf

COPY conf/nginx.conf /etc/nginx/http.d/default.conf
COPY --from=builder /public/ /var/www/static/

EXPOSE 80

ENTRYPOINT ["nginx", "-g", "daemon off;"]
