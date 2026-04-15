#!/bin/bash
set -e

# Parameters
read -p "Project Name:: " PROJECT
read -s -p "Postgres Password: " DB_PASS
echo ""
read -p "Standby DB Port: " STANDBY_PORT
read -p "Primary Host IP: " PRIMARY_IP
read -p "Primary DB Port: " PRIMARY_DB_PORT
read -s -p "Replicator Password: " REP_PASS
echo ""

CONTAINER="postgis_$PROJECT"
SOURCE_DATA="/var/tmp/pg_$PROJECT"
STANDBY_DATA_DIR="/opt/pg_data/$CONTAINER"

# 1. Preparing presistent volume and injecting configs
echo "Preparing Persistent Standby Directory..."
sudo rm -rf "$STANDBY_DATA_DIR"
sudo mkdir -p "$STANDBY_DATA_DIR"

echo "Injecting migrated data..."
sudo cp -a "$SOURCE_DATA/." "$STANDBY_DATA_DIR/"
sudo chown -R 999:999 "$STANDBY_DATA_DIR"
sudo chmod 700 "$STANDBY_DATA_DIR"

echo "Signaling Standby Mode..."
sudo touch "$STANDBY_DATA_DIR/standby.signal"
sudo chown 999:999 "$STANDBY_DATA_DIR/standby.signal"

echo "Writing handshake config to postgresql.auto.conf..."
sudo bash -c "cat <<EOF > $STANDBY_DATA_DIR/postgresql.auto.conf
primary_conninfo = 'host=$PRIMARY_IP port=$PRIMARY_DB_PORT user=replicator password=$REP_PASS'
primary_slot_name = 'slot_${PROJECT}_standby1'
restore_command = 'cp /var/lib/postgresql/data/pg_wal/%f \"%p\"'
EOF"

# 2. Running the container.
echo "Launching standby container..."
docker run -d \
  --name "$CONTAINER" \
  -e POSTGRES_PASSWORD="$DB_PASS" \
  -p "$STANDBY_PORT:5432" \
  -v "$STANDBY_DATA_DIR:/var/lib/postgresql/data" \
  --restart unless-stopped \
  --shm-size="1g" \
  postgis/postgis

echo "Standby is starting. Checking logs..."
sleep 5
docker exec "$CONTAINER" psql -U postgres -c "SELECT * FROM pg_stat_wal_receiver;"
