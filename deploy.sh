#!/bin/bash
set -e

echo "=== 🚀 Hugo Deployment Script ==="
echo ""

# Step 1: Verify we're on master branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "master" ]; then
    echo "❌ ERROR: Must be on 'master' branch"
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

# Step 5: Switch to gh-pages branch (create if doesn't exist)
echo "SetBranch: gh-pages..."
if git show-ref --verify --quiet refs/heads/gh-pages; then
    git checkout gh-pages
else
    git checkout -b gh-pages
fi

# Step 6: Clean old deployment files
echo "🧹 Cleaning old files..."
git rm -rf . 2>/dev/null || true

# Step 7: Copy built files to root
echo "📦 Copying built files..."
cp -r ../public/* .

# Step 8: Verify deployment structure
if [ ! -f "index.html" ]; then
    echo "❌ ERROR: index.html not found at root"
    git checkout master
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

# Step 10: Return to master
echo "SetBranch: master..."
git checkout master

echo ""
echo "✅✅✅ Deployment successful! ✅✅✅"
echo ""
echo "Your site is live at: https://john-jkar.github.io/myblog/"
echo "Wait 1-2 minutes for GitHub Pages to update."
