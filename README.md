# MongoOplogBackup

**Experimental** incremental backup system for MongoDB based on the oplog.

**Not ready for any important data yet. Use at your own risk.**

## Introduction

This project aims to enable incremental backups with point-in-time restore
functionality, utilizing MongoDB's oplog and standard tools wherever possible.

A backup script can be run from a cron job, and each incremental run produces
a single file that can be stored on your preferred medium, for example Amazon S3
or an FTP site. This project only provides the tools to produce the backup files,
and it's up to you to transfer it to a backup medium.

Internally the `mongodump` command is used for the backup operations. Initially
a full dump is performed, after which incremetal backups are performed by backing
up new sections of the oplog. Only the standard BSON format from mongodump is used.

To restore a backup, the incremental oplogs are merged into a single file and combined
with the initial full dump, which can then be restored with a standard
`mongorestore --oplogReplay` command. A point-in-time restore with the `--oplogLimit`
option of `mongorestore`. Additional support for this may be added to the
oplog merging command in the future to simplify the process.

Incremental oplogs always overlap by exactly one entry, so that integrity can easily
be verified (e.g. that there are no gaps between incremental oplogs).



## Installation

Install released gem (recommended):

    gem install mongo-oplog-backup

Install latest development version:

    git clone git@github.com:journeyapps/mongo-oplog-backup.git
    cd mongo-oplog-backup
    rake install

## Usage

To backup from localhost to the `mybackup` directory.

    mongo-oplog-backup backup --dir mybackup

The first run will perform a full backup. Subsequent runs will backup any new entries from the oplog.
A full backup can be forced with the `--full` option.

Sample cron script to perform incremental backups every 15 minutes, and a full backup once a week at 00:05:

    0,15,30,45 * * * * /path/to/ruby/bin/mongo-oplog-backup backup --dir /path/to/backup/location --oplog >> /path/to/backup.log
    5 0 * * 1 /path/to/ruby/bin/mongo-oplog-backup backup --dir /path/to/backup/location --full >> /path/to/backup.log

It is recommended to do a full backup every few days. The restore process may
be very inefficient if the oplogs grow larger than a full backup.

For connection and authentication options, see `mongo-oplog-backup backup --help`.

The backup commands work on a live server. The initial dump with oplog replay relies
on the idempotency of the oplog to have a consistent snapshot, similar to `mongodump --oplog`.
That said, there have been bugs in the past that caused the oplog to not be idempotent
in some edge cases. Therefore it is recommended to stop the secondary before performing
a full backup.

## Rotation

Older backups can be automatically deleted with `mongo-oplog-backup rotate`.

For example, given the full backup schedule above and a recovery point objective of 4 weeks, any full backup sets
older than 4 weeks (excluding the currently active backup set and the previous backup set) can be deleted.

A sample cron script to clean-up any older backups about an hour before the weekly full backup:

   0 23 * * 0 /path/to/ruby/bin/mongo-oplog-backup rotate --dir /path/to/backup/location --keep_days=28 >> /path/to/backup.log
   
It is strongly recommended to use the `dryRun` option to thoroughly test your particular configuration and schedule. 

## To restore

    mongo-oplog-backup merge --dir mybackup/backup-<timestamp>

The above command merges the individual oplog backups into `mybackup/backup-<timestamp>/dump/oplog.bson`.
This allows you to restore the backup with the `mongorestore` command:

    mongorestore --drop --oplogReplay backup/backup-<timestamp>/dump

## Backup structure

* `backup.json` - Stores the current state (oplog timestamp and backup folder).
    The only file required to perform incremental backups. It is not used for restoring a backup.
* `backup.lock` - Lock file to prevent two full backups from running concurrently.
* `backup-<timestamp>` - The current backup folder.
  * `backup.lock` - Lock file preventing two backups running concurrently in this folder.
  * `status.json` - backup status (oplog timestamp)
  * `dump` - a full mongodump
  * `oplog-<start>-<end>.bson` - The oplog from the start timestamp until the end timestamp (inclusive).

Each time a full backup is performed, a new backup folder is created.

## Contributing

1. Fork it ( http://github.com/journeyapps/mongo-oplog-backup/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
