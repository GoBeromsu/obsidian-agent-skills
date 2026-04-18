#!/bin/bash

# Quartz Static Site Deployment Script
# Copies content directly to Blog vault, builds, commits only content files.

set -e

# Load environment variables from Ataraxia vault
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
if [ -f "$VAULT_DIR/.env" ]; then
    source "$VAULT_DIR/.env"
fi

# Validate required environment variables
if [ -z "$QUARTZ_REPO_PATH" ]; then
    echo "Error: QUARTZ_REPO_PATH not set in .env"
    exit 1
fi

if [ -z "$DEPLOY_SITE_URL" ]; then
    echo "Error: DEPLOY_SITE_URL not set in .env"
    exit 1
fi

# Validate paths exist
if [ ! -d "$QUARTZ_REPO_PATH" ]; then
    echo "Error: Quartz repository not found at $QUARTZ_REPO_PATH"
    exit 1
fi

if [ ! -d "$QUARTZ_REPO_PATH/content" ]; then
    echo "Error: content/ directory not found in $QUARTZ_REPO_PATH"
    exit 1
fi

# Configuration
BRANCH="${DEPLOY_GIT_BRANCH:-v5}"
REMOTE="${DEPLOY_GIT_REMOTE:-origin}"
CONTENT_DIR="$QUARTZ_REPO_PATH/content"

echo "Starting Quartz deployment..."
echo "Quartz repository: $QUARTZ_REPO_PATH"
echo "Content directory: $CONTENT_DIR"

# Step 1/3: Process Eagle images if needed
EAGLE_FILES=$(grep -rl "file:///" "$CONTENT_DIR" --include="*.md" 2>/dev/null || true)
if [ -n "$EAGLE_FILES" ] && [ -n "$EAGLE_LIBRARY_PATH" ] && [ -d "$EAGLE_LIBRARY_PATH/images" ]; then
    echo ""
    echo "Step 1/3: Processing Eagle images..."
    node "$SCRIPT_DIR/process-eagle-images.mjs" "$CONTENT_DIR" "$EAGLE_LIBRARY_PATH" "$CONTENT_DIR/_attachments"
else
    echo ""
    echo "Step 1/3: No Eagle images to process (skipped)"
fi

# Verify no Eagle paths remain
EAGLE_COUNT=$(grep -r "file:///" "$CONTENT_DIR" --include="*.md" 2>/dev/null | grep -v "AGENTS.md" | wc -l | tr -d ' ' || echo 0)
if [ "$EAGLE_COUNT" -ne 0 ]; then
    echo "Warning: Found $EAGLE_COUNT Eagle file:/// paths in content"
fi

# Step 2/3: Build the site
cd "$QUARTZ_REPO_PATH"
echo ""
echo "Step 2/3: Building Quartz site..."
npx quartz build

# Step 3/3: Commit and push (only content files)
echo ""
echo "Step 3/3: Committing and pushing to $REMOTE/$BRANCH..."

# Only stage content files — never git add .
git add content/ || true
git add _attachments/ 2>/dev/null || true

CHANGES=$(git diff --cached --name-only)
if [ -z "$CHANGES" ]; then
    echo "No changes to deploy. Site is already up to date."
    exit 0
fi

git diff --cached --stat

# Generate commit message from changed files
ARTICLE_COUNT=$(echo "$CHANGES" | grep -cE "content/.*\.md$" || true)
INDEX_COUNT=$(echo "$CHANGES" | grep -cE "content/.*index\.md$" || true)
NEW_ARTICLES=$((ARTICLE_COUNT - INDEX_COUNT))

if [ "$NEW_ARTICLES" -gt 0 ]; then
    FIRST_ARTICLE=$(echo "$CHANGES" | grep -E "content/.*\.md$" | grep -v "index\.md" | head -1 | xargs basename | sed 's/\.md$//')
    if [ "$NEW_ARTICLES" -eq 1 ]; then
        COMMIT_MSG="feat: add $FIRST_ARTICLE"
    else
        COMMIT_MSG="feat: add $NEW_ARTICLES new articles"
    fi
else
    IMAGE_CHANGES=$(echo "$CHANGES" | grep -c "_attachments" || true)
    if [ "$IMAGE_CHANGES" -gt 0 ]; then
        COMMIT_MSG="fix: update Eagle image paths"
    else
        COMMIT_MSG="fix: update content"
    fi
fi

echo ""
echo "Commit message: $COMMIT_MSG"
git commit -m "$COMMIT_MSG"
git push "$REMOTE" "$BRANCH"

echo ""
echo "Deployment completed successfully!"
echo "Commit: $COMMIT_MSG"
echo "Site: $DEPLOY_SITE_URL"
echo ""
echo "GitHub Actions will deploy the changes in a few moments"
