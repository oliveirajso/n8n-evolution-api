#!/bin/bash

set -e

ZROK_DIR="./.zrok"
ENV_FILE="./.env"

mkdir -p "$ZROK_DIR"

echo "=== zrok v1 Setup (URL fixa / reserved) ==="

# -----------------------------
# Step 1: Enable
# -----------------------------
echo ""
echo "Step 1: Enable zrok environment"
read -s -p "Enter your zrok ENABLE token: " ENABLE_TOKEN
echo ""

if [ -z "$ENABLE_TOKEN" ]; then
  echo "Error: token cannot be empty"
  exit 1
fi

docker run --rm -it \
  --user root \
  -v "$(pwd)/$ZROK_DIR:/home/ziggy/.zrok" \
  openziti/zrok:1.1.11 enable "$ENABLE_TOKEN"

echo "✔ zrok enabled"

# Fix permissions so non-root containers work
sudo chown -R 1000:1000 "$ZROK_DIR"
chmod -R 755 "$ZROK_DIR"

# -----------------------------
# Step 2: Reserve
# -----------------------------
echo ""
echo "Step 2: Reserve public share (URL fixa)"

OUTPUT=$(docker run --rm -it \
  -v "$(pwd)/$ZROK_DIR:/home/ziggy/.zrok" \
  openziti/zrok:1.1.11 reserve public)

echo "$OUTPUT"

SHARE_TOKEN=$(echo "$OUTPUT" | grep -oE 'Reserved share token: .*' | awk '{print $4}')

if [ -z "$SHARE_TOKEN" ]; then
  echo "Could not auto-detect token."
  read -p "Enter the reserved share token manually: " SHARE_TOKEN
fi

if [ -z "$SHARE_TOKEN" ]; then
  echo "Error: no share token provided"
  exit 1
fi

echo "✔ Reserved token: $SHARE_TOKEN"

# -----------------------------
# Step 3: Update .env
# -----------------------------
echo ""
echo "Step 3: Updating .env"

if [ ! -f "$ENV_FILE" ]; then
  touch "$ENV_FILE"
fi

if grep -q "^ZROK_SHARE_TOKEN=" "$ENV_FILE"; then
  sed -i "s/^ZROK_SHARE_TOKEN=.*/ZROK_SHARE_TOKEN=$SHARE_TOKEN/" "$ENV_FILE"
else
  echo "" >> "$ENV_FILE"
  echo "# zrok" >> "$ENV_FILE"
  echo "ZROK_SHARE_TOKEN=$SHARE_TOKEN" >> "$ENV_FILE"
fi

echo "✔ .env updated"

echo ""
echo "=== DONE ==="
echo "Now use in docker-compose:"
echo "command: share reserved \$ZROK_SHARE_TOKEN"