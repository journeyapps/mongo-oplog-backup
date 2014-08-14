// Get the timestamp of the last oplog entry.
// Usage: mongo --quiet --norc local oplog-last-timestamp.js

var local = db.getSiblingDB('local');
var last = local['oplog.rs'].find().sort({'$natural': -1}).limit(1)[0];
var result = {};
if(last != null) {
    result = {position: last['ts']};
}

print(JSON.stringify(result));
