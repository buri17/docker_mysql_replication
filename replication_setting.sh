#!/bin/bash

MASTER_SOCKET=/var/opt/lib/mysql1/mysql.sock
SLAVE_SOCKET=/var/opt/lib/mysql2/mysql.sock
MASTER_USER=\'repl\'
MASTER_PASSWORD=\'slavepass\'
MASTER_PORT=3306
MASTER_DUMP_FILE=masterdump.db
SLEEP_SECONDS=1
MAX_RETRY_COUNT=30

echo "Booting mysql instances..."
/opt/mysql/server-5.6/bin/mysqld_multi start

retry_count=0
while [ $retry_count -lt $MAX_RETRY_COUNT ]; do
    echo "Waiting for mysql instances... ($retry_count)"
    num_groups=`mysqld_multi report | tail -n +2 | wc -l`
    num_running=`mysqld_multi report | tail -n +2 | grep "is running" | wc -l`
    if [ $num_groups -eq $num_running ]; then
	break;
    fi
    echo "Sleeping... $SLEEP_SECONDS seconds..."
    sleep $SLEEP_SECONDS
    retry_count=`expr $retry_count + 1`
done

echo "Creating the master user for replication..."
mysql -S $MASTER_SOCKET  <<EOF 
GRANT REPLICATION SLAVE ON *.* TO $MASTER_USER@'localhost' IDENTIFIED BY $MASTER_PASSWORD; 
EOF

echo "Locking the master..."
mysql -S $MASTER_SOCKET  <<EOF &
FLUSH TABLES WITH READ LOCK; SELECT SLEEP(10000); 
EOF

echo "Dumping the master..."
mysqldump -S $MASTER_SOCKET  --all-databases --master-data > $MASTER_DUMP_FILE

echo "Unlocking the master..."
mysql -S $MASTER_SOCKET  <<EOF 
UNLOCK TABLES;
EOF

echo "Releasing the lock of the master..."
kill -QUIT $!

echo "Importing master data to the slave..."
mysql -S $SLAVE_SOCKET -uroot < $MASTER_DUMP_FILE

echo "Setting the master infomation to the slave..."
mysql -S $SLAVE_SOCKET -uroot <<EOF
CHANGE MASTER TO MASTER_HOST='127.0.0.1', MASTER_USER=$MASTER_USER, MASTER_PASSWORD=$MASTER_PASSWORD, MASTER_PORT=$MASTER_PORT;
start slave;
EOF

echo "Starging the slave..."
mysqladmin -S $SLAVE_SOCKET start-slave

echo "Done."
