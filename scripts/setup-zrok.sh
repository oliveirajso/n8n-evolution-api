#!/bin/bash

# Configuration
ZROK_DIR="./.zrok"
ENV_FILE="./.env"

# Ensure .zrok directory exists
mkdir -p "$ZROK_DIR"

echo "=== zrok Setup for Docker ==="
echo "This script will help you enable your zrok environment and reserve a public share."

# 1. Enable zrok environment
echo ""
echo "Step 1: Enable zrok"
echo "Please enter your zrok Enable Token (from https://zrok.io):"
read -r -s ENABLE_TOKEN

if [ -z "$ENABLE_TOKEN" ]; then
    echo "Error: Token cannot be empty."
    exit 1
fi

echo "Enabling zrok environment..."
docker run --rm -v "$(pwd)/$ZROK_DIR:/root/.zrok" openziti/zrok enable "$ENABLE_TOKEN"

if [ $? -ne 0 ]; then
    echo "Error: Failed to enable zrok environment."
    exit 1
fi
echo "zrok environment enabled successfully."

# 2. Reserve public share
echo ""
echo "Step 2: Reserve Public Share"
echo "Reserving public share for 'n8n:5678'..."

# Run reserve command and capture output
# We use a unique name based on timestamp to avoid collisions if re-run, or let zrok generate one?
# zrok reserve public <target> --backend-mode <mode> --unique-name <name>
# If we don't specify unique-name, zrok generates one.
# We need to capture the SHARE TOKEN. zrok reserve returns: "your reserved share token is: <token>"

OUTPUT=$(docker run --rm -v "$(pwd)/$ZROK_DIR:/root/.zrok" openziti/zrok reserve public n8n:5678 --backend-mode web 2>&1)
echo "$OUTPUT"

# Extract token (assuming output contains "token: <token>" or similar, adjusting regex as needed)
# Typical output: "your reserved share token is: uvw-xyz-123"
SHARE_TOKEN=$(echo "$OUTPUT" | grep -oP '(?<=token is: )\S+')

if [ -z "$SHARE_TOKEN" ]; then
    echo "Warning: Could not automatically extract share token from output."
    echo "Please copy the share token from the output above manually."
    read -p "Enter Share Token: " SHARE_TOKEN
fi

if [ -z "$SHARE_TOKEN" ]; then
    echo "Error: No share token provided."
    exit 1
fi

echo "Share Token captured: $SHARE_TOKEN"

# 3. Update .env
echo ""
echo "Step 3: Update .env"

if grep -q "ZROK_SHARE_TOKEN=" "$ENV_FILE"; then
    # Replace existing
    # Using perl for in-place edit to avoid sed macos/linux differences if any (though this is linux)
    sed -i "s/ZROK_SHARE_TOKEN=.*/ZROK_SHARE_TOKEN=$SHARE_TOKEN/" "$ENV_FILE"
else
    # Append
    echo "" >> "$ENV_FILE"
    echo "# zrok Configuration" >> "$ENV_FILE"
    echo "ZROK_SHARE_TOKEN=$SHARE_TOKEN" >> "$ENV_FILE"
fi

echo ".env updated with ZROK_SHARE_TOKEN."
echo ""
echo "=== Setup Complete ==="
echo "You can now run: docker-compose up -d"
