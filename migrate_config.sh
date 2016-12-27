#!/bin/bash

#migrate config script from http://doc.bareos.org/master/html/bareos-manual-main-reference.html#x1-1110008.1.2
LOGDATE=`date '+%Y%m%d-%H%M%S'`
if [ -r /etc/bareos/bareos-dir.conf ]; then
	
	# backup old configuration 
	mv /etc/bareos/bareos-dir.conf /etc/bareos/bareos-dir.conf.$LOGDATE 
	mv /etc/bareos/bareos-dir.d /etc/bareos/bareos-dir.d.$LOGDATE 
 
	# prepare temporary directory
	rm -Rf  /tmp/bareos-dir.d
	mkdir /tmp/bareos-dir.d 
	cd /tmp/bareos-dir.d 
 
	# download migration script 
	if [ ! -f bareos-migrate-config.sh ]; then
		wget -q https://raw.githubusercontent.com/bareos/bareos-contrib/master/misc/bareos-migrate-config/bareos-migrate-config.sh 
	fi
	
	
 # execute the script 
	bash bareos-migrate-config.sh 
 
	# make sure, that all packaged configuration resources exists, 
	# otherwise they will be added when updating Bareos. 
	for i in $(find  /etc/bareos/bareos-dir.d.bak/ -name *.conf -type f -printf "%P\n"); do touch "$i"; done 
 
	# install newly generated configuration 
	cp -a /tmp/bareos-dir.d /etc/bareos/
fi
