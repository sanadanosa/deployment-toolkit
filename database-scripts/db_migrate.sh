#!/bin/bash
set -e

# Parameters
read -p "Project Name: " PROJECT
read -s -p "Replicator Password: " REP_PASS
echo ""
read -p "Remote Standby (ip:port): " REMOTE_SSH
read -p "SSH Key Path (Optional): " SSH_KEY

CONTAINER="postgis_$PROJECT"
SLOT="slot_${PROJECT}_standby1"
TEMP_DIR="/var/tmp/pg_$PROJECT"

# Port Parsing Logic
if [[ $REMOTE_SSH == *:* ]]; then
    REMOTE_HOST=${REMOTE_SSH%:*}
    REMOTE_PORT=${REMOTE_SSH##*:}
    SSH_OPTS="-p $REMOTE_PORT"
else
    REMOTE_HOST=$REMOTE_SSH
    SSH_OPTS="-p 22"
fi

# 1. Creating backup inside the container
echo "Starting basebackup"
docker exec "$CONTAINER" bash -c "rm -rf /tmp/backup && PGPASSWORD='$REP_PASS' pg_basebackup -D /tmp/backup -S $SLOT -X stream -P -U replicator -Fp -R"

# 2. Extracting backup to temp folder
echo "Cleaning local temp and pulling data from container."
rm -rf "$TEMP_DIR" && mkdir -p "$TEMP_DIR"
docker cp "$CONTAINER:/tmp/backup/." "$TEMP_DIR/"

# 3. Rsync to Standby server
echo "Syncing to Standby on $SSH_OPTS..."
if [ -z "$SSH_KEY" ]; then
    rsync -Pav -e "ssh $SSH_OPTS" "$TEMP_DIR" "$REMOTE_HOST:/var/tmp/"
else
    rsync -Pav -e "ssh -i $SSH_KEY $SSH_OPTS" "$TEMP_DIR" "$REMOTE_HOST:/var/tmp/"
fi

echo "Data sync complete. Files are now on the Standby VM."




