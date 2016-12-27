#!/bin/bash
#
# prepare running docker container for services
# runs each time container starts

PARAMS="$@"

if [ -r /etc/bareos/bareos.env ]; then
  #run local definition script
  source  /etc/bareos/bareos.env
fi
chown -R mysql:adm /db /var/log/mysql

#init db and start db daemon
DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-mysql}
if [ ! -d /db ] || ! ls -1 /db/* >/dev/null ; then
(
  service mysql stop
  
  #mariadb 5.6 procedure
  sed -i "s!datadir=.*!#datadir=/db!" /etc/mysql/my.cnf
  echo -e "[server]\ndatadir=/db" >>/etc/mysql/my.cnf
  mysql_install_db --datadir=/db --force
  /usr/bin/mysqld_safe --datadir=/db &
  sleep 10
  
 
#  mysql 5.7 procedure
# sed -i "s!datadir=.*!datadir=/db!" /etc/mysql/my.cnf
#  mysqld --initialize-insecure --datadir=/db
# /usr/bin/mysqld_safe --datadir=/db &
#  sleep 10
#  mysql --password= <<EOP
#alter user 'root'@'localhost' identified by "$DB_ROOT_PASSWORD";
#flush privileges;
#EOP
) >/var/log/bareos/prepare.log
else
  /usr/bin/mysqld_safe --datadir=/db &
  sleep 5
fi

#set passwordless db access			
if [ ! -f $HOME/.my.cnf ]; then
  echo "
[client]
host=localhost
user=root
password=${DB_ROOT_PASSWORD}
" >$HOME/.my.cnf
fi

mysqladmin password "$DB_ROOT_PASSWORD"
mysql_upgrade >>/var/log/bareos/prepare.log #if needed

#create initial config
if [ -r /etc/bareos/bareos-dir.d/director/bareos-dir.conf ] || [ -r /etc/bareos/bareos-dir.conf ]; then
      echo "migrate using existing config " >>/var/log/bareos/prepare.log
      tar xfvz etc.tgz -C / etc/bareos-webui/configuration.ini
      if [ -r /etc/bareos/bareos-dir.d/webui-profiles.conf ]; then
        sed -i "s/CommandACL = status.*/CommandACL = !.bvfs_clear_cache, !.exit, !.sql, !configure, !create, !delete, !purge, !sqlquery, !umount, !unmount, *all*/g" /etc/bareos/bareos-dir.d/webui-profiles.conf
      fi
      
else
      #initial config from build
      tar xfvz etc.tgz -C / 
        
      #change names
      NAME=$(grep -o -E "Name =(.*)-dir" /etc/bareos/bareos-dir.d/director/bareos-dir.conf|perl -p -e 's/.*=\s*(\w+)-dir/\1/g;')
      sed -i "s/$NAME/$HOSTNAME/" /etc/bareos/bareos-dir.d/director/bareos-dir.conf
      sed -i "s/$NAME/$HOSTNAME/" /etc/bareos/bareos-dir.d/client/bareos-fd.conf
      sed -i "s/${NAME}-fd/${HOSTNAME}-fd/" /etc/bareos/bareos-dir.d/client/*.conf
      sed -i "s/${NAME}-fd/${HOSTNAME}-fd/" /etc/bareos/bareos-dir.d/job/*.conf
      sed -i "s/$NAME/$HOSTNAME/" /etc/bareos/bareos-dir.d/console/bareos-mon.conf
      sed -i "s/$NAME/$HOSTNAME/" /etc/bareos/bareos-sd.d/director/bareos-dir.conf
      sed -i "s/$NAME/$HOSTNAME/" /etc/bareos/bareos-sd.d/storage/bareos-sd.conf
      sed -i "s/$NAME/$HOSTNAME/" /etc/bareos/bareos-sd.d/messages/Standard.conf
      mv /etc/bareos/bareos-dir.d/console/admin.conf.example /etc/bareos/bareos-dir.d/console/admin.conf
      
      #translate name to ip for address config
      TARGET_HOST=$(getent hosts ${TARGET_HOST:-$HOSTNAME}|head -1|awk '{print $1}')
      TARGET_HOST=${TARGET_HOST:-$HOSTNAME}
      sed -i "s/Address =.*/Address = ${TARGET_HOST}/" /etc/bareos/bareos-dir.d/client/bareos-fd.conf      	
      
      #set db
      sed -i "s/dbpassword =.*/dbpassword = \"${BAREOS_DB_PASSWORD}\"/" /etc/bareos/bareos-dir.d/catalog/MyCatalog.conf
      sed -i "s/dbdriver =.*/dbdriver = \"mysql\"/" /etc/bareos/bareos-dir.d/catalog/MyCatalog.conf
      sed -i "s/dbuser =.*/dbuser = \"bareos\" \n  dbaddress = \"localhost\"\n  dbport = 3306/" /etc/bareos/bareos-dir.d/catalog/MyCatalog.conf
      #set backup file location
      sed -i "s/Archive Device.*$/Archive Device = \/backup/" /etc/bareos/bareos-sd.d/device/FileStorage.conf

      #change director name
      sed -i "s/localhost-dir/$HOSTNAME-dir/" /etc/bareos-webui/directors.ini
      
fi

#fix rights
chown -R bareos:bareos /etc/bareos*

#db check
if  (mysql -e "show databases" | cut -d \| -f 1 | grep -w bareos) >/dev/null; then
(  
  echo "Try Update"
	/usr/lib/bareos/scripts/update_bareos_tables
) >>/var/log/bareos/prepare.log
else
(
  mysql <<EOS
GRANT USAGE ON *.* TO 'bareos'@'%' IDENTIFIED BY "${BAREOS_DB_PASSWORD}";
GRANT ALL PRIVILEGES ON bareos.* TO 'bareos'@'%';
FLUSH PRIVILEGES;
EOS
  #run bareos db scripts	
  /usr/lib/bareos/scripts/create_bareos_database
  /usr/lib/bareos/scripts/make_bareos_tables
  /usr/lib/bareos/scripts/grant_bareos_privileges
)>>/var/log/bareos/prepare.log
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') Start Daemons" >>/var/log/bareos/bareos.log
#fix permissions (again)
chown -R bareos:bareos /var/log/bareos /backup
chown -R www-data:www-data /var/log/apache2


#run services
service apache2 stop && service apache2 start
service postfix stop && service postfix start
service bareos-dir stop && service bareos-dir start
service bareos-sd stop && service bareos-sd start
service bareos-fd stop && service bareos-fd start

#exec final command (e.g. start.sh)
exec $PARAMS
