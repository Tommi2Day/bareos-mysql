# docker-bareos-mysql

[![Docker Pulls](https://img.shields.io/docker/stars/tommi2day/bareos-mysql.svg)](https://hub.docker.com/r/tommi2day/bareos-mysql/)
[![Docker Pulls](https://img.shields.io/docker/pulls/tommi2day/bareos-mysql.svg)](https://hub.docker.com/r/tommi2day/bareos-mysql/)

## Bareos on Docker 

Bareos is a fork of the well know backup solution "Bacula"
see https://www.bareos.org

This Bareos installation on Docker comes with integrated mysql backend and Bareos Webui.
Database files and configuration are mapped to volumes. It was made to run on a Synology
Diskstation.

### Run 
Variables must be predefined, see run.vars sample  below and run_bareos-mysql.sh. 
On a Synology Diskstation you may use the Docker Gui instead of the following commands
```sh
docker pull tommi2day/bareos-mysql
docker run --name bareos-mysql \
--add-host bareos:127.0.0.1 \
--add-host ntp:192.53.103.108 \
-e TARGET_HOST=$TARGET_HOST \
-e TZ=$TZ \
-e BAREOS_DB_PASSWORD=$BAREOS_DB_PASSWORD \
-e DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD \
-v ${BACKUP_DIR}:/backup \
-v ${SHARED_DIR}/db:/db \
-v ${SHARED_DIR}/etc-bareos:/etc/bareos \
-v ${SHARED_DIR}/log-mysql:/var/log/mysql \
-v ${SHARED_DIR}/log-bareos:/var/log/bareos \
-v ${SHARED_DIR}/etc-bareos-webui:/etc/bareos-webui \
-v ${SHARED_DIR}/log-apache2:/var/log/apache2 \
-p ${EXT_DIR_PORT}:9101 -p ${EXT_FD_PORT}:9102 -p ${EXT_SD_PORT}:9103 \
-p ${EXT_DB_PORT}:3306 -p ${EXT_HTML_PORT}:80
tommi2day/bareos-mysql
```
Bareos Gui Access:
http://$TARGET_HOST:$EXT_HTML_PORT/bareos-webui
User admin Password admin

#### local settings
* bareos.env --> will be sourced each time container starts. 
You may place your mailconfig or others there, with is not persistent in the container. Put this file into your shared /etc/bareos folder

```sh
#bareos env system configuration
#will be executed on every start by prepare.sh
#put your local system changes here
#mail
postconf -e relayhost=mailhost
postconf -e myhostname=bareos
echo "
root:         root@mydomain.com
" >>/etc/aliases
newaliases
postfix restart

#Time
TZ=${TZ:-Etc/UTC}
TZF=/usr/share/zoneinfo/$TZ
if [ -r $TZF ];then
	echo $TZ >/etc/timezone
	rm /etc/localtime && ln -s $TZF /etc/localtime
fi
ntpdate -q ptbtime1.ptb.de
```

* run.vars --> defines variables used by run_bareos-mysql.sh. Put this file into the same path, 
if you want to use this commandline script.
```sh
#shared folder on a synology nas
BACKUP_DIR=/volume1/Backup/bareos
#runtime variables
#DOCKER_SHARED=$(pwd)}
#SHARED_DIR=bareos-shared
#TARGET_HOST=docker
TZ=Europe/Berlin
BAREOS_DB_PASSWORD=bareos
DB_ROOT_PASSWORD=supersecret
TZ=Europe/Berlin
EXT_HTML_PORT=33080
#EXT_DB_PORT=3306
#EXT_DIR_PORT=9101
#EXT_FD_PORT=9102
#EXT_SD_PORT=9103
```
### exposed Ports
```sh
# web, director, fd, storage, mysql daemons 
EXPOSE 80 9101 9102 9103 3306
```
### Volumes
```sh
VOLUME /db # mysql datadir
VOLUME /var/log/mysql # mysql logfiles
VOLUME /var/log/apache2 # apache logfiles
VOLUME /backup # Backup Storage
VOLUME ["/etc/bareos","/var/log/bareos","/etc/bareos-webui"] # Bareos konfiguration
```
### Environment variables used
```sh
TARGET_HOST # Host/IP for bareos dir, fd and sd Address configuration parameter  
BAREOS_DB_PASSWORD # create bareos user account with this password
DB_ROOT_PASSWORD # create database with this password
TZ #valid time zone name for /usr/share/zoneinfo
```

### Attention: Update to Docker Bareos-Mysql:16.2 onwards from previous versions

First of all: Make sure you have a valid backup of all your configuration files and the mysql database 
(e.g. mysqldump -A ..). You may need it in case of errors.

The database engine has been changed from mysql to mariadb. The update will cause an unrecoverable change of
the mysql datafiles. 

In Bareos 16.2 the configuration file structure has been changed. 
See the [documentation](http://doc.bareos.org/master/html/bareos-manual-main-reference.html#bareos-update) for details.
Bareos provides a [migrate-config](https://raw.githubusercontent.com/bareos/bareos-contrib/master/misc/bareos-migrate-config/bareos-migrate-config.sh) 
script. This script extracts the existing configuration 
with bconsole show commands und builds pure new config files only based on the extracted config, 
not on the existing config files. As of Bareos 16.2.4 this method is known to produce invalid
 configuration files, which prevents the director to come up. 

However: To extract the configuration you need a running director instance acessible by bconsole.
Because this is not available when upgrading the docker container my start script will only do the most
 important changes to bringup the director and leaves the directory changes for you.

Alternativ you may run the migrate-config script against your running old 15.2 director, 
and copy the resulting files over after the first boot of 16.2 succeeded and do a reload. 