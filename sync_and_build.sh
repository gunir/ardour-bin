#!/bin/bash

# Sync, Build and Download script for Andour (Ardour)
# Requires GitHub CLI (gh) authenticated

set -e

# Configuration
REPO="gunir/ardour-bin"
ARTIFACT_NAME="ardour-linux-bundle"
OUTPUT_DIR="bin"
BRANCH=$(git rev-parse --abbrev-ref HEAD)

echo "🚀 Syncing new version to GitHub..."

# 1. Commit and Push
if [[ -n $(git status -s) ]]; then
    echo "📦 Committing local changes..."
    git add .
    git commit -m "Automated build sync: $(date +'%Y-%m-%d %H:%M:%S')"
fi

echo "📤 Pushing to $BRANCH..."
git push origin "$BRANCH"

echo "⏳ Waiting for GitHub Action build to complete..."
# 2. Wait for the run to finish
# We get the ID of the latest run for the current branch
RUN_ID=$(gh run list --workflow "build.yml" --branch "$BRANCH" --limit 1 --json databaseId --jq '.[0].databaseId')

if [ -z "$RUN_ID" ]; then
    echo "❌ Error: Could not find the workflow run."
    exit 1
fi

gh run watch "$RUN_ID"

# 3. Download Binary
echo "📥 Downloading bundle from GitHub artifacts..."
mkdir -p "$OUTPUT_DIR"

# Download the specific artifact
gh run download "$RUN_ID" -n "$ARTIFACT_NAME" -D "$OUTPUT_DIR"

# If it's a tarball, extract it
if [ -f "$OUTPUT_DIR/ardour-linux-x86_64.tar.gz" ]; then
    echo "📦 Extracting bundle..."
    tar -xzf "$OUTPUT_DIR/ardour-linux-x86_64.tar.gz" -C "$OUTPUT_DIR"
    rm "$OUTPUT_DIR/ardour-linux-x86_64.tar.gz"
fi

# 4. Finalize
# The bundle has bin/ and lib/ structures
REAL_BIN=$(find "$OUTPUT_DIR/bin" -type f -name "ardour-*" -executable | head -n 1)

if [ -f "$REAL_BIN" ]; then
    chmod +x "$REAL_BIN"
    echo "✅ Success! Bundle is ready in: $OUTPUT_DIR"
    echo "💡 To run it, you may need to set LD_LIBRARY_PATH:"
    # Determine the actual lib path (it might be lib/ardour7 or similar)
    LIB_PATH=$(find "$OUTPUT_DIR/lib" -maxdepth 1 -type d -name "ardour*" | head -n 1)
    echo "   export LD_LIBRARY_PATH=\$PWD/$LIB_PATH:\$LD_LIBRARY_PATH"
    echo "   ./$REAL_BIN"
else
    echo "⚠️ Warning: Could not find the Ardour executable in the downloaded bundle."
    ls -R "$OUTPUT_DIR"
fi
