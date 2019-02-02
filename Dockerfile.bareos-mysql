ARG BASE="ubuntu:18.04"
FROM       $BASE
MAINTAINER Tommi2Day

ENV DEBIAN_FRONTEND noninteractive
ENV HOSTNAME bareos
ENV TERM xterm

#install standard packages
RUN apt-get update && apt-get upgrade -y && apt-get install -y wget less aptitude mariadb-server apache2 postfix ntpdate vim inetutils-ping net-tools dnsutils iproute2 gnupg locales && apt-get clean

#Mountpoints
RUN mkdir -p /db /backup 

#install bareos from there own repo
RUN echo "deb http://download.bareos.org/bareos/release/latest/xUbuntu_18.04/ /" > /etc/apt/sources.list.d/bareos.list
RUN wget -q http://download.bareos.org/bareos/release/latest/xUbuntu_18.04/Release.key -O- | apt-key add -
RUN apt-get update && apt-get install -y bareos bareos-database-mysql bareos-webui && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 
#RUN wget -q -O /etc/bareos/bareos-migrate-config.sh https://raw.githubusercontent.com/bareos/bareos-contrib/master/misc/bareos-migrate-config/bareos-migrate-config.sh

WORKDIR /root



#add scripts
ADD [ "prepare.sh","start.sh","configure.sh","/root/" ]
RUN chmod u+x /root/*.sh && /root/configure.sh

#save default configs
RUN tar cfvz etc.tgz /etc/bareos /etc/bareos-webui /etc/mysql

#volumes
VOLUME ["/db","/var/log/mysql","/backup","/etc/bareos","/var/log/bareos","/etc/bareos-webui","/etc/mysql","/var/log/apache2"]

# web, director, fd, storage, mysql daemons 
EXPOSE 80 9101 9102 9103 3306


ENTRYPOINT ["/root/prepare.sh"]
CMD ["/root/start.sh"]

