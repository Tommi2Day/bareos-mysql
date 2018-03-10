#!/bin/bash
#
# bareos docker container starter

DOCKER_USER=tommi2day
DOCKER=docker
VMNAME=${1:-"bareos-mysql"}
shift
VERS="16.2"
shift
#define variables
if [ -r run.vars ]; then
	source run.vars
fi

#set defaults if needed
HOSTNAME=${HOSTNAME:-$(uname -n)}
DOCKER_SHARED=${DOCKER_SHARED:-$(pwd)}
SHARED_DIR=${DOCKER_SHARED}/bareos-shared
BACKUP_DIR=${BACKUP_DIR:-${SHARED_DIR}/backup}
TARGET_HOST=${TARGET_HOST:-$HOSTNAME}
BAREOS_DB_PASSWORD=${BAREOS_DB_PASSWORD:-bareos}
DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-bareos}
EXT_HTML_PORT=${EXT_HTML_PORT:-33080}
EXT_DB_PORT=${EXT_DB_PORT:-33306}
EXT_DIR_PORT=${EXT_DIR_PORT:-9101}
EXT_FD_PORT=${EXT_FD_PORT:-9102}
EXT_SD_PORT=${EXT_SD_PORT:-9103}
TZ=${TZ:-Etc/UTC}

#debug
if [ -z "$DEBUG" ]; then
	RUN="-d "
else
	RUN="--rm=true -it --entrypoint bash "

fi


#stop and delete
RUNNING=$($DOCKER inspect --format="{{ .State.Running }}" $VMNAME 2> /dev/null)
if [ $? -eq 0 ]; then
	if [ "$RUNNING" == "true" ]; then
		$DOCKER stop $VMNAME
	fi
	$DOCKER rm $VMNAME
fi

if [ "$DEBUG" = "clean" ]; then
	#clean all if debug set to clean
	rm -Rf ${SHARED_DIR}
fi

#create shared directories
if [ ! -d  $BACKUP_DIR ]; then
		mkdir -p $BACKUP_DIR
fi
for d in db log-mysql log-bareos log-apache2 etc-bareos etc-bareos-webui; do
	if [ ! -d  ${SHARED_DIR}/$d ]; then
		mkdir -p ${SHARED_DIR}/$d
	fi
done


#copy predefined local system settings
for f in bareos.env bareos-dir.d bareos-sd.d bareos-clients.d ; do
	if [ -e $f ]; then
		cp -rf $f ${SHARED_DIR}/etc-bareos
	fi
done

#run it
echo "	
$DOCKER run $RUN \
--name ${VMNAME} \
--hostname $VMNAME \
--add-host bareos:127.0.0.1 \
--add-host ntp:192.53.103.108 \
-e TARGET_HOST=$TARGET_HOST \
-e BAREOS_DB_PASSWORD=$BAREOS_DB_PASSWORD \
-e DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD \
-e TZ=$TZ \
-v ${BACKUP_DIR}:/backup \
-v ${SHARED_DIR}/db:/db \
-v ${SHARED_DIR}/etc-bareos:/etc/bareos \
-v ${SHARED_DIR}/log-mysql:/var/log/mysql \
-v ${SHARED_DIR}/log-bareos:/var/log/bareos \
-v ${SHARED_DIR}/etc-bareos-webui:/etc/bareos-webui \
-v ${SHARED_DIR}/log-apache2:/var/log/apache2 \
-p ${EXT_DIR_PORT}:9101 -p ${EXT_FD_PORT}:9102 -p ${EXT_SD_PORT}:9103 \
-p ${EXT_DB_PORT}:3306 -p ${EXT_HTML_PORT}:80 \
${DOCKER_USER}/$VMNAME:$VERS $@ " >starter

if [ "$OSTYPE" = "msys" ]; then
	mv starter starter.ps1
	powershell -File starter.ps1
else
	bash starter
fi
