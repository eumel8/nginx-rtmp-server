# syntax=docker/dockerfile:1.6
ARG NGINX_VERSION=1.27.3
ARG RTMP_MODULE_VERSION=1.2.2

############################
# Build stage
############################
FROM alpine:3.20 AS build

ARG NGINX_VERSION
ARG RTMP_MODULE_VERSION

RUN apk add --no-cache \
    build-base \
    pcre-dev \
    openssl-dev \
    zlib-dev \
    linux-headers \
    curl \
    ca-certificates

WORKDIR /tmp

RUN curl -fsSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar -xz && \
    curl -fsSL https://github.com/arut/nginx-rtmp-module/archive/refs/tags/v${RTMP_MODULE_VERSION}.tar.gz | tar -xz

WORKDIR /tmp/nginx-${NGINX_VERSION}

RUN ./configure \
        --prefix=/usr/local/nginx \
        --sbin-path=/usr/local/nginx/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/run/nginx/nginx.pid \
        --lock-path=/run/nginx/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --with-http_ssl_module \
        --with-http_stub_status_module \
        --with-threads \
        --add-module=/tmp/nginx-rtmp-module-${RTMP_MODULE_VERSION} && \
    make -j"$(nproc)" && \
    make install && \
    strip /usr/local/nginx/sbin/nginx

# stat.xsl ships with the rtmp module
RUN mkdir -p /usr/local/nginx/html && \
    cp /tmp/nginx-rtmp-module-${RTMP_MODULE_VERSION}/stat.xsl /usr/local/nginx/html/stat.xsl

############################
# Runtime stage
############################
FROM alpine:3.20

RUN apk add --no-cache \
        pcre \
        openssl \
        zlib \
        ca-certificates \
        tini && \
    addgroup -S -g 10001 nginx && \
    adduser  -S -D -H -u 10001 -G nginx -s /sbin/nologin nginx

COPY --from=build /usr/local/nginx/sbin/nginx /usr/local/nginx/sbin/nginx
COPY --from=build /usr/local/nginx/html       /usr/local/nginx/html
# mime.types and other default conf files
COPY --from=build /etc/nginx/                 /etc/nginx/
COPY nginx.conf /etc/nginx/nginx.conf
COPY watch.html /usr/local/nginx/html/watch.html

# Writable dirs the container needs at runtime (mounted as emptyDir in k8s)
RUN mkdir -p /var/log/nginx /var/cache/nginx /run/nginx /var/hls /var/dash && \
    chown -R nginx:nginx /var/log/nginx /var/cache/nginx /run/nginx /var/hls /var/dash /etc/nginx

USER 10001:10001

EXPOSE 1935 8080

STOPSIGNAL SIGQUIT

ENTRYPOINT ["/sbin/tini","--"]
CMD ["/usr/local/nginx/sbin/nginx","-g","daemon off;"]
