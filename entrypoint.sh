#!/bin/bash

set -x

set -e

for file in $(ls /opt/setup.d/*)
do
    cp $file /opt/lib
done

echo DB_CONTAINER_NAME: ${DB_CONTAINER_NAME:=${0##*/}}
echo DB_SERVER_DBMS: ${DB_SERVER_DBMS:=mysql}
echo DB_SERVER_HOST: ${DB_SERVER_HOST:=$DB_PORT_3306_TCP_ADDR}
echo DB_SERVER_PORT: ${DB_SERVER_PORT:=$DB_PORT_3306_TCP_PORT}
echo DB_SERVER_USER: ${DB_SERVER_USER:=unspecified}
echo DB_SERVER_PASSWORD: ${DB_SERVER_PASSWORD:=unspecified}
echo DB_SERVER_DATABASE: ${DB_SERVER_DATABASE:=unspecified}
#echo REDIS_SERVER_HOST: ${REDIS_SERVER_HOST:=$REDIS_PORT_6379_TCP_ADDR}
#echo REDIS_SERVER_PORT: ${REDIS_SERVER_PORT:=$REDIS_PORT_6379_TCP_PORT}
echo DB_WAIT_CONTAINER_KEY: ${DB_WAIT_CONTAINER_KEY:=setup-database}

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
source $DIR/mysql-java-embulk-docker-lib.sh

for sql in $(ls /opt/lib/*.sql)
do
    mysql -h $DB_SERVER_HOST -P $DB_SERVER_PORT -u $DB_SERVER_USER -p$DB_SERVER_PASSWORD source $sql
done

function is_installed() {
    tablename=$(awk -F '[ \t:]+' '/table/ {print $3;exit}' $1)
    mysql -h $DB_SERVER_HOST -P $DB_SERVER_PORT -u $DB_SERVER_USER -p$DB_SERVER_PASSWORD -e "select count(*) from $DB_SERVER_DATABASE.$tablename;"
}

for yml in $(ls /opt/lib/*.yml)
do
    if is_installed $yml; then
	echo "Skip importing."
    else
	echo "embulk run $yml"
	sed -i -e "s/{{DB_SERVER_DBMS}}/$DB_SERVER_DBMS/g" $yml
	sed -i -e "s/{{DB_SERVER_HOST}}/$DB_SERVER_HOST/g" $yml
	sed -i -e "s/{{DB_SERVER_PORT}}/$DB_SERVER_PORT/g" $yml
	sed -i -e "s/{{DB_SERVER_USER}}/$DB_SERVER_USER/g" $yml
	sed -i -e "s/{{DB_SERVER_PASSWORD}}/$DB_SERVER_PASSWORD/g" $yml
	sed -i -e "s/{{DB_SERVER_DATABASE}}/$DB_SERVER_DATABASE/g" $yml
	cd /opt/lib && /opt/embulk run $yml
    fi
done

if [ -n "$REDIS_SERVER_HOST" ]; then
    redis-cli -h $REDIS_SERVER_HOST -p $REDIS_SERVER_PORT SET $DB_WAIT_CONTAINER_KEY up
fi
