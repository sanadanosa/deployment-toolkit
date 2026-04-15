#!/bin/bash
set -e

# Parameters
read -p "Project Name: " PROJECT
read -p "Database Port (Host): " DB_PORT
read -s -p "Postgres Password: " DB_PASS
echo ""
read -s -p "Replicator Password: " REP_PASS
echo ""

CONTAINER="postgis_$PROJECT"
SLOT="slot_${PROJECT}_standby1"
DATA_BASE_DIR="/opt/pg_data/$CONTAINER"

# 1. Running the container
echo "Creating persistent directory at $DATA_BASE_DIR..."
sudo mkdir -p "$DATA_BASE_DIR"
sudo chown -R 999:999 "$DATA_BASE_DIR"

echo "Launching Primary Container..."
docker run -d \
  --name "$CONTAINER" \
  -e POSTGRES_PASSWORD="$DB_PASS" \
  -p "$DB_PORT:5432" \
  -v "$DATA_BASE_DIR:/var/lib/postgresql/data" \
  --restart unless-stopped \
  --shm-size="1g" \
  postgis/postgis

sleep 15

# 2. Configuring replication
docker exec -u postgres "$CONTAINER" bash -c "grep -q '^wal_level = replica' /var/lib/postgresql/data/postgresql.conf || cat <<EOF >> /var/lib/postgresql/data/postgresql.conf
wal_level = replica
hot_standby = on
max_wal_senders = 10
max_replication_slots = 10
hot_standby_feedback = on
EOF"

docker exec -u postgres "$CONTAINER" bash -c "echo 'host replication replicator 0.0.0.0/0 trust' >> /var/lib/postgresql/data/pg_hba.conf"

docker restart "$CONTAINER"
sleep 10

# 3. Creating replication user and slot
docker exec -u postgres "$CONTAINER" psql -c "CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD '$REP_PASS';"
docker exec -u postgres "$CONTAINER" psql -c "SELECT * FROM pg_create_physical_replication_slot('$SLOT');"


echo "Primary is up with persistent data is at $DATA_BASE_DIR Slot: $SLOT"
