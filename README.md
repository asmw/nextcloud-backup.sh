# nextcloud-backup.sh
A shell script to backup nextcloud according to the official documentation.

The script switches on maintenance mode, rsyncs the nextcloud and data folder and dumps the mysql database.
On exit maintenance mode is disabled again.

# Features
 - Toggles maintenance mode
 - Extracts data folder location and database parameters from the nextcloud config

# Requirements
 - php
 - rsync
 - sudo
 - mysqldump

The script assumes that it can run sudo as the owner of the nextcloud `occ` script (i.e. www-data)

# Usage
`nextcloud-backup.sh [/path/to/nextcloud] [/path/to/backup] [backup suffix]`

Defaults for source and destination are `/var/www/nextcloud` and `/mnt/backups/nextcloud`
The default suffix for backup folders and the SQL dump is `_$(date + %Y%m%d)`

## Example
`nextcloud-backup.sh /var/www/nextcloud /mnt/backups/nextcloud`

# Caveats
The default rsync settings are suitable for backup onto a CIFS share which cannot preserve owner/group.
to override pass something like `RSYNC_ARGS="-avx --delete"` in the environment.

# Environment variables
 - `RSYNC_ARGS`: arguments passed to rsync (default: `-avx --no-owner --no-group --delete`)
 - `SUFFIX`: the backup folder and SQL dump suffix (default: `_$(date +"%Y%m%d")`)
 - `DRYRUN`: prefixed to all commands which do work, i.e. rsync/php/sudo, set to `echo` for a dryrun
