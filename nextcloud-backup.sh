#!/bin/bash
set -u

requirements="rsync sudo php mysqldump"
function check_req {
  if ! hash $1 2>/dev/null; then
    echo "Missing requirement: $1"
    echo "Requirements are: $requirements"
    exit 10
  fi
}

for r in $requirements; do
  check_req $r
done

set -e

NEXTCLOUD_DIR=${1:-/var/www/nextcloud}
BACKUP_DEST=${2:-/mnt/backups/nextcloud}
SUFFIX=${SUFFIX-${3:-_$(date +"%Y%m%d")}}
RSYNC_ARGS=${RSYNC_ARGS:-"-avx --no-owner --no-group --delete"}
DRYRUN=${DRYRUN:-}

echo "Backing up from $NEXTCLOUD_DIR to $BACKUP_DEST using suffix '$SUFFIX'"

if [ ! -w $BACKUP_DEST ]; then
  echo "Can not write $BACKUP_DEST"
  exit 1
fi

lock=$BACKUP_DEST/.backup_lock
if ! mkdir $lock 2>/dev/null; then
  echo "Lock directory '$lock' exists. A backup seems to be running."
  echo "If no backup is running this indicates an error."
  exit 2
fi

occ="$NEXTCLOUD_DIR/occ"
occ_owner=$(stat -c '%U' "$occ")

function finish {
  rm -rf "$lock"
  $DRYRUN sudo -u $occ_owner php "$occ" maintenance:mode --off
}
trap finish EXIT

echo "Enabling maintenance mode"
$DRYRUN sudo -u $occ_owner php "$occ" maintenance:mode --on

if [ ! -f $NEXTCLOUD_DIR/config/config.php ]; then
  echo "$NEXTCLOUD_DIR does not look like a nextcloud instance."
  exit 3
fi

DATA_DIR=$(php -r "include '$NEXTCLOUD_DIR/config/config.php'; echo \$CONFIG['datadirectory'];")
if [ ! -d "$DATA_DIR" ]; then
  echo "Could not find nextcloud data directory $DATA_DIR"
  exit 4
fi

CFG="$NEXTCLOUD_DIR/config/config.php"
DB_NAME=$(php -r "include '$CFG'; echo \$CONFIG['dbname'];")
DB_USER=$(php -r "include '$CFG'; echo \$CONFIG['dbuser'];")
DB_PASSWORD=$(php -r "include '$CFG'; echo \$CONFIG['dbpassword'];")
if [ -z "$DB_USER" -o -z "$DB_PASSWORD" -o -z "$DB_NAME" ]; then
  echo "Could not read proper database parameters from config ($DFG)"
  exit 5
fi

${PREPARE:-}
$DRYRUN mysqldump --single-transaction -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -r $BACKUP_DEST/nextcloud${SUFFIX}.sql
$DRYRUN rsync $RSYNC_ARGS $NEXTCLOUD_DIR/ $BACKUP_DEST/nextcloud${SUFFIX}/
$DRYRUN rsync $RSYNC_ARGS $DATA_DIR/ $BACKUP_DEST/nextcloud-data${SUFFIX}/
${TEARDOWN:-}
