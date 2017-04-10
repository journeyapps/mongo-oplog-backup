#!/bin/bash -ex

echo "This requires a mongodb instance running on 27017."
echo "It will first SHUTDOWN any instances already running on that port, and then start new ones."
echo "If this is undesired, CTRL+C within 5 seconds..." 
sleep 5
echo "Here we go..."
mongo --port 27017 admin --eval 'db.shutdownServer({force: true})' || true
sleep 5
rm -rf backup-test/*
rm -rf testdb
mkdir testdb
mongod --port 27017 --dbpath testdb --replSet rs0 --oplogSize 20 --noprealloc --fork --smallfiles --logpath mongodb.log
sleep 3
mongo --port 27017 admin --eval 'printjson(rs.initiate());'
sleep 20



bundle exec rspec



bundle exec bin/mongo-oplog-backup backup --port 27017 --dir backup-test/ --gzip --full
mongo --port 27017 backup-test --eval 'db.test.insert({"a":2})'

bundle exec bin/mongo-oplog-backup backup --port 27017 --dir backup-test/ --gzip --oplog

sleep 5
mongo --port 27017 backup-test --eval 'db.test.insert({"a":3})'
bundle exec bin/mongo-oplog-backup backup --port 27017 --dir backup-test/ --oplog


sleep 5
mongo --port 27017 backup-test --eval 'db.test.insert({"a":4})'
bundle exec bin/mongo-oplog-backup backup --port 27017 --dir backup-test/ --oplog



mongo --port 27017 admin --eval 'db.shutdownServer({force: true})'
sleep 5
rm -rf testdb/*
mongod --port 27017 --dbpath testdb --replSet rs0 --oplogSize 20 --noprealloc --fork --smallfiles --logpath mongodb.log
sleep 3
mongo --port 27017 admin --eval 'printjson(rs.initiate());'
sleep 20

export BACKUPDIR=`ls -1t backup-test/ |grep backup- |head -n 1`

bundle exec bin/mongo-oplog-backup restore --full --gzip --dir backup-test/$BACKUPDIR --port 27017
mongo --port 27017 backup-test --eval 'db.test.find()'


#mongorestore --gzip --port 27017 backup-test/$BACKUPDIR/dump
#mongo --port 27017 backup-test --eval 'db.test.find()'
#bundle exec bin/mongo-oplog-backup restore --oplog --dir backup-test/$BACKUPDIR --port 27017
#mongo --port 27017 backup-test --eval 'db.test.find()'
