FROM alpine:3.7
MAINTAINER IF Fulcrum "fulcrum@ifsight.net"

RUN apk update --no-cache && apk upgrade --no-cache                                                                  && \
  apk add --no-cache --virtual build-dependencies alpine-sdk binutils php7-phar                                      && \
  apk add --no-cache curl curl-dev mysql-client postfix                                                              && \
  PHPMAJVER=7                                                                                                        && \
  PHPMNRVER=1                                                                                                        && \
  PHPCHGURL=http://php.net/ChangeLog-$PHPMAJVER.php                                                                  && \
  PGKSDIR=/home/abuild/packages/community/x86_64                                                                     && \
  PHPPKGS1="common ctype curl dom fpm ftp gd gettext imap json ldap mbstring"                                        && \
  PHPPKGS2="mcrypt mysqlnd mysqli opcache openssl pdo pdo_mysql pdo_pgsql"                                           && \
  PHPPKGS3="pgsql session simplexml soap sockets tokenizer xdebug xml xmlreader xmlwriter zip"                       && \
  PHPPKGS="$PHPPKGS1 $PHPPKGS2 $PHPPKGS3"                                                                            && \
  PHPPNTVER=$(curl -s $PHPCHGURL|grep -Eo "$PHPMAJVER\.$PHPMNRVER\.\d+"|cut -d\. -f3|sort -n|tail -1)                && \
  BLACKFURL=https://blackfire.io/api/v1/releases/probe/php/alpine/amd64/$PHPMAJVER$PHPMNRVER                         && \
  PHPVER=$PHPMAJVER.$PHPMNRVER.$PHPPNTVER                                                                            && \
  STRIPDIRS="/bin /lib /sbin /usr/bin /usr/lib /usr/sbin"                                                            && \
  adduser -D abuild -G abuild -s /bin/sh                                                                             && \
  mkdir -p /var/cache/distfiles                                                                                      && \
  chmod a+w /var/cache/distfiles                                                                                     && \
  echo "abuild ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/abuild                                                      && \
  su - abuild -c "git clone -v https://github.com/alpinelinux/aports.git ~/aports"                                   && \
  su - abuild -c "cd ~/aports && git checkout 3.7-stable"                                                            && \
  su - abuild -c "cd ~/aports && git pull"                                                                           && \
  su - abuild -c "cd ~/aports/community/php7 && abuild -r deps"                                                      && \
  su - abuild -c "git config --global user.name \"IF Fulcrum\""                                                      && \
  su - abuild -c "git config --global user.email \"fulcrum@ifsight.net\""                                            && \
  su - abuild -c "echo '' | abuild-keygen -a -i"                                                                     && \
  su - abuild -c "cd ~/aports/community/php7 && abump -k php$PHPMAJVER-$PHPVER"                                      && \
  su - abuild -c "cd ~/aports/community/php7-redis  && abuild checksum && abuild -r"                                 && \
  su - abuild -c "cd ~/aports/community/php7-xdebug && abuild checksum && abuild -r"                                 && \
  apk add --allow-untrusted $PGKSDIR/php7-$PHPVER-r0.apk $PGKSDIR/php7-redis*.apk $PGKSDIR/php7-xdebug*.apk          && \
  for PHPEXT in $PHPPKGS; do apk add --allow-untrusted $PGKSDIR/php7-$PHPEXT-$PHPVER-r0.apk; done                    && \
  adduser -h /var/www/html -s /sbin/nologin -D -H -u 1971 php                                                        && \
  chown -R postfix  /var/spool/postfix                                                                               && \
  chgrp -R postdrop /var/spool/postfix/public /var/spool/postfix/maildrop                                            && \
  chown -R root     /var/spool/postfix/pid                                                                           && \
  chown    root     /var/spool/postfix                                                                               && \
  echo smtputf8_enable = no >> /etc/postfix/main.cf                                                                  && \
  curl -A "Docker" -o /blackfire-probe.tar.gz -D - -L -s $BLACKFURL                                                  && \
  tar zxpf /blackfire-probe.tar.gz -C /                                                                              && \
  mv /blackfire-*.so $(php -r "echo ini_get('extension_dir');")/blackfire.so                                         && \
  printf "extension=blackfire.so\nblackfire.agent_socket=tcp://blackfire:8707\n" > /etc/php7/conf.d/90-blackfire.ini && \
  cd /usr/local                                                                                                      && \
  curl -sS https://getcomposer.org/installer | php                                                                   && \
  /bin/mv composer.phar bin/composer                                                                                 && \
  deluser php                                                                                                        && \
  adduser -h /tmp/phphome -s /bin/sh -D -H -u 1971 php                                                               && \
  mkdir -p /usr/share/drush/commands/ /tmp/phphome drush8                                                            && \
  chown php.php /tmp/phphome drush8                                                                                  && \
  su - php -c "cd /usr/local/drush8 && composer require drush/drush:8.*"                                             && \
  ln -s /usr/local/drush8/vendor/drush/drush/drush /usr/local/bin/drush                                              && \
  su - php -c "/usr/local/bin/drush @none dl registry_rebuild-7.x"                                                   && \
  mv /tmp/phphome/.drush/registry_rebuild /usr/share/drush/commands/                                                 && \
  deluser php                                                                                                        && \
  adduser -h /var/www/html -s /bin/sh -D -H -u 1971 php                                                              && \
  find $STRIPDIRS -type f -exec strip -v {} \;                                                                        && \
  apk del build-dependencies php7-dev pcre-dev                                                                       && \
  deluser --remove-home abuild                                                                                       && \
  rm -rf /blackfire* /var/cache/apk/* /var/cache/distfiles/*                                                         && \
  rm -rf /tmp/phphome /var/cache/apk/* /usr/local/bin/composer                                                       && \
  cd /usr/bin                                                                                                        && \
  rm mysql_waitpid mysqlimport mysqlshow mysqladmin mysqlcheck mysqldump myisam_ftdump

USER php

ENV COLUMNS 100

# Move to the directory were the php files stands
WORKDIR /var/www/html

ENTRYPOINT ["/usr/sbin/php-fpm7"]

CMD ["--nodaemonize"]