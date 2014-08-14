# Mongo::Oplog::Backup

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'mongo-oplog-backup'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install mongo-oplog-backup

## Usage

TODO: Write usage instructions here

## Backup structure

* `backup.json` - Stores the current state (oplog timestamp and backup folder).
    The only file required to perform incremental backups. It is not used for restoring a backup.
* `backup-<timestamp>` - The current backup folder.
  * `dump` - a full mongodump
  * `oplog-<start>-<end>.bson - The oplog from the start timestamp until the end timestamp (inclusive).

Each time a full backup is performed, a new backup folder is created.
## Contributing

1. Fork it ( http://github.com/<my-github-username>/mongo-oplog-backup/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
