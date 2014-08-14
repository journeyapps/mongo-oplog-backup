# MongoOplogBackup

**Experimental** incremental backup system for MongoDB based on the oplog.

Not ready for any important data yet.

## Installation

    git clone git@github.com:journeyapps/mongo-oplog-backup.git
    cd mongo-oplog-backup
    rake install

## Usage

    mongo-oplog-backup backup --dir mybackup

TODO: Write usage instructions here

## Backup structure

* `backup.json` - Stores the current state (oplog timestamp and backup folder).
    The only file required to perform incremental backups. It is not used for restoring a backup.
* `backup-<timestamp>` - The current backup folder.
  * `dump` - a full mongodump
  * `oplog-<start>-<end>.bson` - The oplog from the start timestamp until the end timestamp (inclusive).

Each time a full backup is performed, a new backup folder is created.
## Contributing

1. Fork it ( http://github.com/<my-github-username>/mongo-oplog-backup/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
