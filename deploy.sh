#!/bin/bash

# 部署脚本
echo "🚀 Deploying blog to GitHub..."

# 检查 git 是否初始化
if [ ! -d ".git" ]; then
    echo "📦 Initializing git repository..."
    git init
    git remote add origin https://github.com/SilenceDiors/silencediors.github.io.git
fi

# 添加所有文件
echo "📝 Adding files..."
git add .

# 提交
echo "💾 Committing changes..."
git commit -m "Update blog: $(date +%Y-%m-%d)"

# 推送
echo "🚀 Pushing to GitHub..."
git branch -M main
git push -u origin main

echo "✅ Deployment complete!"
echo "Your blog will be available at: https://silencediors.github.io"
echo ""
echo "Note: It may take a few minutes for GitHub Pages to build your site."

