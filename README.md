# deployment-toolkit

- db-primary-provisionv.sh: Initializes PostGIS database deployment. 

- db-migrate.sh: Syncs PostGIS data to a standby server. It automatically checks postgresql.conf to make sure wal_level = replica is actually active and not just commented out.

- db-standby-innit.sh: Generates standby container and grabs the files trasfered from db-migrate.sh scipt.

- provision-scripts/: Set of Bash scripts to spin up new backend and frontend containers. Saves me from typing the same 20 docker run commands every time.

- gitea-actions/: YAML files for Gitea Actions. Handles building and deploying Vue and Node apps automatically when code is pushed.

