# MongoOplogBackup

**Experimental** incremental backup system for MongoDB based on the oplog.

**Not ready for any important data yet. Use at your own risk.**

## Installation

    git clone git@github.com:journeyapps/mongo-oplog-backup.git
    cd mongo-oplog-backup
    rake install

## Usage

To backup from localhost to the `mybackup` directory.

    mongo-oplog-backup backup --dir mybackup

The first run will perform a full backup. Subsequent runs will backup any new entries from the oplog.
A full backup can be forced with the `--full` option.

For connection options, see `mongo-oplog-backup backup --help`.

## To restore

    mongo-oplog-backup merge --dir mybackup/backup-<timestamp>
    
The above command merges the individual oplog backups into `mybackup/backup-<timestamp>/dump/oplog.bson`.
This allows you to restore the backup with the `mongorestore` command:

    mongorestore --drop --oplogReplay backup/backup-<timestamp>/dump
    

## Backup structure

* `backup.json` - Stores the current state (oplog timestamp and backup folder).
    The only file required to perform incremental backups. It is not used for restoring a backup.
* `backup-<timestamp>` - The current backup folder.
  * `dump` - a full mongodump
  * `oplog-<start>-<end>.bson` - The oplog from the start timestamp until the end timestamp (inclusive).

Each time a full backup is performed, a new backup folder is created.

## Contributing

1. Fork it ( http://github.com/journeyapps/mongo-oplog-backup/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
