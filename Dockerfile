FROM alpine:3.7
MAINTAINER IF Fulcrum "fulcrum@ifsight.net"

RUN STARTTIME=$(date "+%s")                                                                              && \
echo "#################### [$(date)] Setup Preflight variables ####################"                     && \
PHPMAJVER=7                                                                                              && \
PHPMNRVER=1                                                                                              && \
PHPCHGURL=http://php.net/ChangeLog-$PHPMAJVER.php                                                        && \
PGKDIR=/home/abuild/packages/community/x86_64                                                            && \
PKGS1="common ctype curl dom fpm ftp gd gettext imap json ldap mbstring"                                 && \
PKGS2="mcrypt mysqlnd mysqli opcache openssl pdo pdo_mysql pdo_pgsql"                                    && \
PKGS3="pgsql session simplexml soap sockets tokenizer xml xmlreader xmlwriter zip"                       && \

PKGS="$PKGS1 $PKGS2 $PKGS3"                                                                              && \
BLACKFURL=https://blackfire.io/api/v1/releases/probe/php/alpine/amd64/$PHPMAJVER$PHPMNRVER               && \
echo "#################### [$(date)] Add Packages ####################"                                  && \
apk update --no-cache && apk upgrade --no-cache                                                          && \
apk add --no-cache --virtual build-dependencies alpine-sdk autoconf binutils m4 libbz2 pcre-dev perl        \
    php$PHPMAJVER-dev php$PHPMAJVER-phar                                                                 && \
apk add --no-cache curl curl-dev mysql-client postfix                                                    && \
echo "#################### [$(date)] Get PHP point upgrade ####################"                         && \
PHPPNTVER=$(curl -s $PHPCHGURL|grep -Eo "$PHPMAJVER\.$PHPMNRVER\.\d+"|cut -d\. -f3|sort -n|tail -1)      && \
PHPVER=$PHPMAJVER.$PHPMNRVER.$PHPPNTVER                                                                  && \
echo "#################### [$(date)] Setup build environment ####################"                       && \
adduser -D abuild -G abuild -s /bin/sh                                                                   && \
mkdir -p /var/cache/distfiles                                                                            && \
chmod a+w /var/cache/distfiles                                                                           && \
echo "abuild ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/abuild                                            && \
su - abuild -c "git clone -v https://github.com/alpinelinux/aports.git aports"                           && \
su - abuild -c "cd aports && git checkout 3.7-stable"                                                    && \
su - abuild -c "cd aports && git pull"                                                                   && \
su - abuild -c "cd aports/community/php$PHPMAJVER && abuild -r deps"                                     && \
su - abuild -c "git config --global user.name \"IF Fulcrum\""                                            && \
su - abuild -c "git config --global user.email \"fulcrum@ifsight.net\""                                  && \
su - abuild -c "echo ''|abuild-keygen -a -i"                                                             && \


echo "#################### [$(date)] Use Alpine's bump command ####################"                     && \
su - abuild -c "cd aports/community/php$PHPMAJVER && abump -k php$PHPMAJVER-$PHPVER"                     && \
echo "#################### [$(date)] Build ancillary PHP packages ####################"                  && \

su - abuild -c "cd aports/community/php$PHPMAJVER-redis  && abuild checksum && abuild -r"                && \
su - abuild -c "cd aports/community/php$PHPMAJVER-xdebug && abuild checksum && abuild -r"                && \
echo "#################### [$(date)] Install PHP packages ####################"                          && \
apk add --allow-untrusted $PGKDIR/php$PHPMAJVER-$PHPVER-r0.apk $PGKDIR/php$PHPMAJVER-redis*.apk             \
    $PGKDIR/php$PHPMAJVER-xdebug*.apk                                                                    && \
for EXT in $PKGS;do apk add --allow-untrusted $PGKDIR/php$PHPMAJVER-$EXT-$PHPVER-r0.apk;done             && \
echo "#################### [$(date)] Setup Fulcrum Env ####################"                             && \
adduser -h /var/www/html -s /sbin/nologin -D -H -u 1971 php                                              && \
chown -R postfix  /var/spool/postfix                                                                     && \
chgrp -R postdrop /var/spool/postfix/public /var/spool/postfix/maildrop                                  && \
chown -R root     /var/spool/postfix/pid                                                                 && \
chown    root     /var/spool/postfix                                                                     && \
echo smtputf8_enable = no >> /etc/postfix/main.cf                                                        && \
echo "#################### [$(date)] Install Blackfire ####################"                             && \
curl -A "Docker" -o /blackfire-probe.tar.gz -D - -L -s $BLACKFURL                                        && \
tar zxpf /blackfire-probe.tar.gz -C /                                                                    && \
mv /blackfire-*.so $(php -r "echo ini_get('extension_dir');")/blackfire.so                               && \
printf "extension=blackfire.so\nblackfire.agent_socket=tcp://blackfire:8707\n"                            | \
    tee /etc/php$PHPMAJVER/conf.d/90-blackfire.ini                                                       && \
echo "#################### [$(date)] Install Drush ####################"                                 && \
cd /usr/local                                                                                            && \
curl -sS https://getcomposer.org/installer|php                                                           && \
/bin/mv composer.phar bin/composer                                                                       && \
deluser php                                                                                              && \
adduser -h /phphome -s /bin/sh -D -H -u 1971 php                                                         && \
mkdir -p /usr/share/drush/commands /phphome drush8                                                       && \
chown php.php /phphome drush8                                                                            && \
su - php -c "cd /usr/local/drush8 && composer require drush/drush:8.*"                                   && \
ln -s /usr/local/drush8/vendor/drush/drush/drush /usr/local/bin/drush                                    && \
su - php -c "/usr/local/bin/drush @none dl registry_rebuild-7.x"                                         && \
mv /phphome/.drush/registry_rebuild /usr/share/drush/commands/                                           && \
echo "#################### [$(date)] Reset php user for fulcrum ####################"                    && \
deluser php                                                                                              && \
adduser -h /var/www/html -s /bin/sh -D -H -u 1971 php                                                    && \
echo "#################### [$(date)] Clean up container/put on a diet ####################"              && \
find /bin /lib /sbin /usr/bin /usr/lib /usr/sbin -type f -exec strip -v {} \;                            && \
apk del build-dependencies                                                                               && \
deluser --remove-home abuild                                                                             && \
cd /usr/bin                                                                                              && \
rm -rf /blackfire* /var/cache/apk/* /var/cache/distfiles/* /phphome /usr/local/bin/composer                 \
    mysql_waitpid mysqlimport mysqlshow mysqladmin mysqlcheck mysqldump myisam_ftdump                    && \
echo "#################### [$(date)] Done ####################"                                          && \
echo "#################### Elapsed: $(expr $(date "+%s") - $STARTTIME) seconds ####################"

USER php

ENV COLUMNS 100

WORKDIR /var/www/html

ENTRYPOINT ["/usr/sbin/php-fpm7"]

CMD ["--nodaemonize"]