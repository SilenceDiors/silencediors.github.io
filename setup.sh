#!/bin/bash

# 博客设置脚本
echo "🚀 Setting up your blog..."

# 检查是否在正确的目录
if [ ! -f "_config.yml" ]; then
    echo "❌ Error: _config.yml not found. Please run this script in the blog root directory."
    exit 1
fi

# 安装依赖
echo "📦 Installing dependencies..."
bundle install

# 创建必要的目录
echo "📁 Creating directories..."
mkdir -p _posts
mkdir -p _drafts

echo "✅ Setup complete!"
echo ""
echo "To start the local server, run:"
echo "  bundle exec jekyll serve"
echo ""
echo "Then visit: http://localhost:4000"

