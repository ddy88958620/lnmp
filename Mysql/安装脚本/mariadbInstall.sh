#!/bin/bash

# Check if user is root
if [ $(id -u) != "0" ]; then
    printf "Error: You must be root to run this script!\n"
    exit 1
fi

printf "\n"
printf "===========================\n"
printf " MariaDB V10.0.14 Install  \n"
printf " copyright:www.doitphp.com \n"
printf "===========================\n"
printf "\n\n"

if [ ! -s websrc ]; then    
    printf "Error: directory websrc not found.\n"
    exit 1
fi

cd websrc

printf "\n========= source package download start =========\n\n"

if [ -s mariadb-10.0.14.tar.gz ]; then
  echo "mariadb-10.0.14.tar.gz [found]"
else
  echo "mariadb-10.0.14.tar.gz download now..."
  wget https://downloads.mariadb.org/interstitial/mariadb-10.0.14/source/mariadb-10.0.14.tar.gz
fi

mariadbMd5=`md5sum mariadb-10.0.14.tar.gz | awk '{print $1}'`
if [ "$mariadbMd5" != "80fea71de54a9cfa7f5508df53d3f06d" ]; then
    echo "Error: mariadb-10.0.14.tar.gz package md5 value is invalid. Please check package download url";
    exit 1
fi

if [ -s mariadb-10.0.14 ]; then
    rm -rf mariadb-10.0.14
fi
tar zxvf mariadb-10.0.14.tar.gz

printf "\n========= source package download completed =========\n\n"

groupadd mysql
useradd -g mysql mysql -s /bin/false

mkdir -p /data/mysql
chown -R mysql:mysql /data/mysql

mkdir -p /usr/local/mysql
mkdir -m 0777 -p /var/log/mysql

printf "========= Cmake install start... =========\n\n"

if [ -s /usr/local/share/cmake-3.1/completions/cmake ]; then
	echo "cmake V3.1.2 has been installed.";
else
	if [ -s cmake-3.1.2.tar.gz ]; then
		echo "cmake-3.1.2.tar.gz [found]"
	else
		echo "cmake-3.1.2.tar.gz download now..."
		wget http://www.cmake.org/files/v3.1/cmake-3.1.2.tar.gz
	fi

	if [ -s cmake-3.1.2 ]; then
		rm -rf cmake-3.1.2 
	fi
	tar zxvf cmake-3.1.2.tar.gz

	cd cmake-3.1.2
	./configure --prefix=/usr/local
	make -j 4
	make install
	cd -
fi

printf "\n========= Cmake install end =========\n\n"
printf "========= MariaDB install start... =========\n\n"

cd mariadb-10.0.14
cmake . -DCMAKE_INSTALL_PREFIX=/usr/local/mysql -DMYSQL_DATADIR=/data/mysql -DSYSCONFDIR=/etc -DMYSQL_UNIX_ADDR=/tmp/mysql.sock -DMYSQL_TCP_PORT=3306 -DWITH_INNOBASE_STORAGE_ENGINE=1 -DWITH_PARTITION_STORAGE_ENGINE=1 -DWITH_BLACKHOLE_STORAGE_ENGINE=1 -DWITH_MYISAM_STORAGE_ENGINE=1 -DWITH_READLINE=1 -DENABLED_LOCAL_INFILE=1 -DDEFAULT_CHARSET=utf8 -DDEFAULT_COLLATION=utf8_general_ci -DWITH_EXTRA_CHARSETS=all
make -j 8
make install
cd -

if [ ! -f /usr/local/mysql/bin/mysql ]; then
    printf "Error: mysql make install failed!\n"
    exit 1
fi

cat >/etc/my.cnf<<EOF
# MariaDB config file

# The MySQL server
[mysqld]
basedir = /usr/local/mysql
datadir = /data/mysql
socket	= /tmp/mysql.sock
pid-file = /data/mysql/mysql.pid

character-set-server = utf8
collation-server = utf8_general_ci
user = mysql
port = 3306

default_storage_engine = InnoDB
innodb_file_per_table = 1
server-id = 1
log-bin=mysql-bin
binlog_format = mixed
expire_logs_days = 7

skip-name-resolve
skip-host-cache
skip-external-locking

key_buffer_size = 512M
max_allowed_packet = 1M
table_open_cache = 512
sort_buffer_size = 2M
read_buffer_size = 2M
read_rnd_buffer_size = 8M
myisam_sort_buffer_size = 64M
thread_cache_size = 8
query_cache_size = 32M
query_cache_type = 1
thread_concurrency = 8

log_error = /var/log/mysql/mysql-error.log
long_query_time = 1
slow_query_log
slow_query_log_file = /var/log/mysql/mysql-slow.log

max_connections = 1000
bind-address= 0.0.0.0

[client]
default-character-set = utf8
port = 3306
socket = /tmp/mysql.sock
EOF

cd /usr/local/mysql

./scripts/mysql_install_db --user=mysql

cp ./support-files/mysql.server /etc/rc.d/init.d/mysqld

chmod 0775 /etc/rc.d/init.d/mysqld

sed -i 's/^basedir=/basedir=\/usr\/local\/mysql/g' /etc/rc.d/init.d/mysqld
sed -i 's/^datadir=/datadir=\/data\/mysql/g' /etc/rc.d/init.d/mysqld

isSet=`grep "/usr/local/mysql/bin" /etc/profile | wc -l`
if [ "$isSet" != "1" ]; then
    echo "export PATH=$PATH:/usr/local/mysql/bin">>/etc/profile
fi

ln -s /usr/local/mysql/include/mysql /usr/include/mysql

service mysqld start
chkconfig mysqld on

./bin/mysql_secure_installation
service mysqld restart
cd -

printf "\n========== MariaDB install Completed! ========\n\n"
ps aux | grep mysql | grep -v "grep"
printf "============== The End. ==============\n"