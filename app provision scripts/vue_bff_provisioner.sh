#!/bin/bash
set -e
# parameters
read -p "Project Name : " PROJECT
read -p "Target Port : " PORT
read -p "Git Username: " GIT_USER
read -s -p "Git Token: " GIT_TOKEN
echo ""
read -p "Git VUE URL: " FULL_URL
read -p "Git Branch: " BRANCH
read -p "BFF Git URL: " BFF_URL
read -p "BFF Brach: " BFF_BRANCH

DIR_PATH="/aplikasi/FRONTEND_$PROJECT"
CONTAINER_NAME="${PROJECT}_frontend"

# bff repo full link

if [[ "$BFF_URL" == https* ]]; then
    BFF_PROTOCOL="https"
else
    BFF_PROTOCOL="http"
fi

CLEAN_BFF_URL=$(echo "$BFF_URL" | sed 's|https\?://||')
AUTH_BFF_URL="$BFF_PROTOCOL://$GIT_USER:$GIT_TOKEN@$CLEAN_BFF_URL"

# clearing previous deployment and directory setup
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

rm -rf "${DIR_PATH:?}"
mkdir -p "$DIR_PATH"
cd "$DIR_PATH"


# bff setup
git clone -b "$BFF_BRANCH" "$AUTH_BFF_URL" .
git remote set-url origin "$AUTH_BFF_URL"

# dockerfile generation
cat <<EOF > dockerfile
FROM node:20-alpine
WORKDIR /app
COPY src ./src
COPY package.json ./
COPY ecosystem.config.js ./
COPY .env ./
COPY VUE_SRC ./VUE_SRC
RUN apk add yarn
ENV NPM_CONFIG_LOGLEVEL warn
RUN npm install --production
WORKDIR "/app/VUE_SRC"
ENV NODE_OPTIONS="--max-old-space-size=2560"
RUN yarn global add @vue/cli
RUN npm install --force
RUN npm run build
RUN npm install -g pm2
WORKDIR /app
EXPOSE 5000
CMD [ "pm2-runtime", "start", "ecosystem.config.js" ]
EOF

# .env generation
echo "port = 5000" > .env




# vue setup
if [[ "$FULL_URL" == https* ]]; then
    PROTOCOL="https"
else
    PROTOCOL="http"
fi

CLEAN_URL=$(echo "$FULL_URL" | sed 's|https\?://||')
AUTH_URL="$PROTOCOL://$GIT_USER:$GIT_TOKEN@$CLEAN_URL"


echo "Cloning Vue Source into VUE_SRC."
git clone -b "$BRANCH" "$AUTH_URL" VUE_SRC
cd VUE_SRC
git remote set-url origin "$AUTH_URL"
cd ..

# build and run
docker build -t "$CONTAINER_NAME" .
docker run -d -t -i \
  -v "$DIR_PATH/VUE_SRC/dist:/dist" \
  -p "$PORT:5000" \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  "$CONTAINER_NAME:latest"

echo "Frontend $PROJECT is live on port $PORT"
