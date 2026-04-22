#!/bin/bash
set -e

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

if [ -f "$VAULT_DIR/.env" ]; then
    source "$VAULT_DIR/.env"
fi

# Validate Eagle library path
if [ -z "$EAGLE_LIBRARY_PATH" ]; then
    echo "Error: EAGLE_LIBRARY_PATH not set in .env"
    echo ""
    echo "Add the following to $VAULT_DIR/.env:"
    echo "EAGLE_LIBRARY_PATH=\"/path/to/Ataraxia.library\""
    exit 1
fi

if [ ! -d "$EAGLE_LIBRARY_PATH/images" ]; then
    echo "Error: Eagle library not found at $EAGLE_LIBRARY_PATH"
    echo "Expected directory: $EAGLE_LIBRARY_PATH/images"
    exit 1
fi

# Paths
SOURCE_DIR="$QUARTZ_REPO_PATH"
STAGING_DIR="$SOURCE_DIR/.deploy-staging"
ATTACHMENTS_DIR="$STAGING_DIR/_attachments"

echo "Preparing deployment staging..."
echo ""

# Step 1: Create fresh staging directory
echo "Cleaning previous staging..."
rm -rf "$STAGING_DIR"
mkdir -p "$ATTACHMENTS_DIR"

# Step 2: Copy content to staging (exclude staging itself and _attachments)
echo "Copying content to staging..."
rsync -a \
    --exclude='.deploy-staging' \
    --exclude='_attachments' \
    "$SOURCE_DIR/" "$STAGING_DIR/"

echo ""

# Step 3: Process Eagle images in staging
echo "Processing Eagle images..."
node "$SCRIPT_DIR/process-eagle-images.mjs" "$STAGING_DIR" "$EAGLE_LIBRARY_PATH" "$ATTACHMENTS_DIR"

echo ""
echo "Staging ready at: $STAGING_DIR"
echo "  Original notes preserved with Eagle paths"
echo "  Staging contains transformed content for deployment"
