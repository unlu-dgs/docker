FROM alpine:3.7 AS sodium
RUN apk add \
    php7 \
    php7-pear \
    php7-dev \
    gcc \
    musl-dev \
    make \
    libsodium \
    libsodium-dev \
    && pecl install -f libsodium-1.0.6

FROM alpine:3.7
# Por defecto se utiliza la timezone de Buenos Aires
ENV TZ=America/Argentina/Buenos_Aires

RUN apk --no-cache add \
    tzdata \
    php7 \
    php7-pdo_pgsql \
    php7-gd \
    php7-mbstring \
    php7-zip \
    php7-pcntl \
    php7-json \
    php7-curl \
    php7-gmp \
    libsodium \
    apache2 \
    php7-apache2 \
    curl \
    && rm -rf /var/cache/apk/* \
    && mkdir -p /run/apache2 \
    && echo "extension=libsodium.so" >> /etc/php7/php.ini \
    && echo "date.timezone=America/Argentina/Buenos_Aires" >> /etc/php7/php.ini \
    && echo "log_errors=On" >> /etc/php7/php.ini \
    && echo "ErrorLog /dev/stderr" >> /etc/apache2/httpd.conf \
    && echo "TransferLog /dev/stdout" >> /etc/apache2/httpd.conf \
    && echo "LoadModule rewrite_module modules/mod_rewrite.so" >> /etc/apache2/httpd.conf \
    && cp /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

COPY --from=sodium /usr/lib/php7/modules/libsodium.so /usr/lib/php7/modules/

EXPOSE 80
