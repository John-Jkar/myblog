#!/bin/bash
set -e

echo "=== 🚀 Hugo Deployment Script ==="
echo ""

# Step 1: Verify we're on main branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "❌ ERROR: Must be on 'main' branch"
    echo "   Current branch: $CURRENT_BRANCH"
    exit 1
fi
echo "✓ On branch: $CURRENT_BRANCH"

# Step 2: Clean any uncommitted public/ files
echo "🧹 Cleaning generated files..."
git checkout -- public/ 2>/dev/null || true
rm -rf public/ 2>/dev/null || true

# Step 3: Build the site
echo "🔨 Building Hugo site..."
hugo
echo "✓ Build complete"

# Step 4: Verify build succeeded
if [ ! -f "public/index.html" ]; then
    echo "❌ ERROR: Build failed - public/index.html not found"
    exit 1
fi
echo "✓ Build verified"

# Step 5: Switch to gh-pages branch
echo "SetBranch: gh-pages..."
git checkout gh-pages 2>/dev/null || git checkout -b gh-pages

# Step 6: Clean old deployment files
echo "🧹 Cleaning old files..."
git rm -rf . 2>/dev/null || true

# Step 7: Copy built files to root
echo "📦 Copying built files..."
cp -r ../public/* .

# Step 8: Verify deployment structure
if [ ! -f "index.html" ]; then
    echo "❌ ERROR: index.html not found at root"
    git checkout main
    exit 1
fi
echo "✓ Deployment structure verified"

# Step 9: Commit and push
echo "💾 Committing changes..."
git add -A
COMMIT_MSG="Deploy: $(date '+%Y-%m-%d %H:%M')"
git commit -m "$COMMIT_MSG" || echo "⚠️ No changes to commit"
echo "✓ Committed: $COMMIT_MSG"

echo "📤 Pushing to GitHub..."
git push -f origin gh-pages
echo "✓ Pushed successfully"

# Step 10: Return to main
echo "SetBranch: main..."
git checkout main

echo ""
echo "✅✅✅ Deployment successful! ✅✅✅"
echo ""
echo "Your site is live at: https://john-jkar.github.io/myblog/"
echo "Wait 1-2 minutes for GitHub Pages to update."
