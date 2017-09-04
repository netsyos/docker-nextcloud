FROM netsyos/nginx:latest

RUN add-apt-repository -y ppa:ondrej/php

RUN apt-get update

RUN apt-get -y --force-yes install php7.1-cli php7.1-fpm php7.1-mysql php7.1-json php7.1-mcrypt \
     php7.1-curl php7.1-xml php7.1-gd php7.1-intl php7.1-imap \
     php7.1-dev php7.1-bcmath php7.1-bz2 php7.1-mbstring php7.1-soap \
     php7.1-zip php7.1-imagick php-ssh2

RUN apt-get install -y \
  rsync \
  bzip2 \
  libcurl4-openssl-dev \
  libfreetype6-dev \
  libicu-dev \
  libjpeg-dev \
  libldap2-dev \
  libmcrypt-dev \
  libmemcached-dev \
  libpng12-dev \
  libpq-dev \
  libxml2-dev

RUN apt-get install -y \
  pkg-config
## https://docs.nextcloud.com/server/9/admin_manual/installation/source_installation.html
#RUN debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)" \
#  && docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr \
#  && docker-php-ext-configure ldap --with-libdir="lib/$debMultiarch" \
#  && docker-php-ext-install gd exif intl mbstring mcrypt ldap mysqli opcache pdo_mysql pdo_pgsql pgsql zip pcntl

# set recommended PHP.ini settings
# see https://docs.nextcloud.com/server/12/admin_manual/configuration_server/server_tuning.html#enable-php-opcache
#RUN { \
#  echo 'opcache.enable=1'; \
#  echo 'opcache.enable_cli=1'; \
#  echo 'opcache.interned_strings_buffer=8'; \
#  echo 'opcache.max_accelerated_files=10000'; \
#  echo 'opcache.memory_consumption=128'; \
#  echo 'opcache.save_comments=1'; \
#  echo 'opcache.revalidate_freq=1'; \
#  } > /usr/local/etc/php/conf.d/opcache-recommended.ini

# PECL extensions
RUN set -ex \
 && pecl install APCu-5.1.8 \
 && pecl install memcached-3.0.3 \
 && pecl install redis-3.1.3
#  \
# && docker-php-ext-enable apcu redis memcached

ENV NEXTCLOUD_VERSION 12.0.2
ENV WWW_PATH /var/www
ENV NEXTCLOUD_PATH $WWW_PATH/nextcloud

RUN curl -fsSL -o nextcloud.tar.bz2 \
    "https://download.nextcloud.com/server/releases/nextcloud-${NEXTCLOUD_VERSION}.tar.bz2" \
 && curl -fsSL -o nextcloud.tar.bz2.asc \
    "https://download.nextcloud.com/server/releases/nextcloud-${NEXTCLOUD_VERSION}.tar.bz2.asc" \
 && export GNUPGHOME="$(mktemp -d)" \
# gpg key from https://nextcloud.com/nextcloud.asc
 && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 28806A878AE423A28372792ED75899B9A724937A \
 && gpg --batch --verify nextcloud.tar.bz2.asc nextcloud.tar.bz2 \
 && rm -r "$GNUPGHOME" nextcloud.tar.bz2.asc \
 && tar -xjf nextcloud.tar.bz2 -C $WWW_PATH/ \
 && rm nextcloud.tar.bz2 \
 && rm -rf $NEXTCLOUD_PATH/updater \
 # https://docs.nextcloud.com/server/11/admin_manual/installation/installation_wizard.html#setting-strong-directory-permissions
 && mkdir -p $NEXTCLOUD_PATH/data \
 && mkdir -p $NEXTCLOUD_PATH/custom_apps \
 && find $NEXTCLOUD_PATH/ -type f -print0 | xargs -0 chmod 0640 \
 && find $NEXTCLOUD_PATH/ -type d -print0 | xargs -0 chmod 0750 \
 && chown -R www-data:www-data $NEXTCLOUD_PATH/ \
 && chown -R www-data:www-data $NEXTCLOUD_PATH/custom_apps/ \
 && chown -R www-data:www-data $NEXTCLOUD_PATH/config/ \
 && chown -R www-data:www-data $NEXTCLOUD_PATH/data/ \
 && chown -R www-data:www-data $NEXTCLOUD_PATH/themes/ \
 && chmod +x $NEXTCLOUD_PATH/occ


COPY config/nextcloud/* $NEXTCLOUD_PATH/config/
COPY config/php/php.ini /etc/php/7.1/fpm/
COPY config/php/php.ini /etc/php/7.1/cli/
COPY config/nginx/nginx.conf /etc/nginx/
RUN echo "extension = apcu.so" | tee -a /etc/php/7.1/mods-available/apcu.ini
RUN ln -s /etc/php/7.1/mods-available/apcu.ini /etc/php/7.1/fpm/conf.d/30-apcu.ini
RUN ln -s /etc/php/7.1/mods-available/apcu.ini /etc/php/7.1/cli/conf.d/30-apcu.ini

RUN chown -R www-data:www-data $NEXTCLOUD_PATH/

RUN mkdir /run/php
RUN mkdir /etc/service/fpm
ADD service/fpm.sh /etc/service/fpm/run
RUN chmod +x /etc/service/fpm/run

RUN mkdir /etc/service/logs
ADD service/logs.sh /etc/service/logs/run
RUN chmod +x /etc/service/logs/run

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*