FROM ubuntu

run locale-gen en_US.UTF-8
run update-locale LANG=en_US.UTF-8
env DEBIAN_FRONTEND noninteractive
env LC_ALL C
env LC_ALL en_US.UTF-8

RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" > /etc/apt/sources.list
RUN apt-get update
RUN apt-get clean

# Install sshd & Supervisor
RUN apt-get install -y openssh-server supervisor
RUN mkdir -p /var/run/sshd
RUN chmod 744 /var/run/sshd
RUN mkdir -p /var/log/supervisor

# Add supervisor's configuration file
ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Install MySQL 5.6
RUN apt-get install -y wget perl libaio1
RUN wget http://dev.mysql.com/get/Downloads/MySQL-5.6/mysql-5.6.16-debian6.0-x86_64.deb -P /tmp
# ADD mysql-5.6.16-debian6.0-x86_64.deb /tmp/mysql-5.6.16-debian6.0-x86_64.deb
RUN dpkg -i /tmp/mysql-5.6.16-debian6.0-x86_64.deb
ENV PATH $PATH:/opt/mysql/server-5.6/bin

## Remove temporary files
RUN rm /tmp/mysql-5.6.16-debian6.0-x86_64.deb
RUN rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

## Setup user and group
RUN groupadd mysql
RUN useradd -r -g mysql mysql
RUN chown -R mysql:mysql /opt/mysql

## Create mysql log directory
RUN mkdir -p /var/log/mysql

## Copy my.cnf
ADD my.cnf /etc/my.cnf

## Create mysql data directories
RUN mkdir -p /var/opt/lib
RUN /opt/mysql/server-5.6/scripts/mysql_install_db --user=mysql --datadir=/var/opt/lib/mysql1
RUN /opt/mysql/server-5.6/scripts/mysql_install_db --user=mysql --datadir=/var/opt/lib/mysql2

## Exec replication_setting.sh
ADD replication_setting.sh /tmp/replication_setting.sh
RUN chmod +x /tmp/replication_setting.sh
RUN /tmp/replication_setting.sh
RUN rm -f /tmp/replication_setting.sh

## Expose ports to connect mysql
EXPOSE 22 3306 13306 9001

CMD ["/usr/bin/supervisord"]