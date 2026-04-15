#!/bin/bash
set -e

# 1. Git & Project Configuration
read -p "GitHub Username: " GIT_USER
read -s -p "GitHub Token: " GIT_TOKEN
echo ""
read -p "Git Clone URL: " FULL_URL
read -p "Branch: " BRANCH
read -p "Project Name: " PROJECT
read -p "Target Port: " PORT

DIR_NAME="BACKEND_$PROJECT"
CONTAINER_NAME="${PROJECT,,}_backend"

# 2. Setup directory and clone
mkdir -p "/aplikasi/$DIR_NAME"
cd "/aplikasi/$DIR_NAME"

if [[ "$FULL_URL" == https* ]]; then
    PROTOCOL="https"
else
    PROTOCOL="http"
fi

CLEAN_URL=$(echo "$FULL_URL" | sed 's|https\?://||')
AUTH_URL="$PROTOCOL://$GIT_USER:$GIT_TOKEN@$CLEAN_URL"


git clone -b "$BRANCH" "$AUTH_URL" .
git remote set-url origin "$AUTH_URL"

# 3. Dockerfile detection
DOCKERFILE_PATH=$(find . -maxdepth 1 -iname "dockerfile" | head -n 1)
if [ -z "$DOCKERFILE_PATH" ]; then
    echo "Error: No Dockerfile found."
    exit 1
fi

# 4. Environment configuration
echo "Opening nano for .env configuration. Paste contents and save (Ctrl+O, Enter, Ctrl+X)."
read -p "Press Enter to continue..."
nano .env

# 5. Build and run
docker build -f "$DOCKERFILE_PATH" -t "$CONTAINER_NAME" .
docker run -d \
  -t -i \
  -p "$PORT:5000" \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  "$CONTAINER_NAME"

echo "Deployment complete for $PROJECT on port $PORT"
