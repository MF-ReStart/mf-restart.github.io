#!/bin/bash

# --- 1. 构建阶段 ---
echo "🏗️  正在生成静态网页..."
# 确保使用 honkit build，删除可能导致报错的 install
npx honkit build

# 检查构建是否成功
if [ ! -d "_book" ]; then
    echo "❌ 错误：_book 文件夹未生成，请检查笔记语法！"
    exit 1
fi

# --- 2. 准备阶段 ---
echo "🧹 清理并准备发布目录..."
cd ./github-pages/

# 确保我们在发布目录，且保留 .git
if [ ! -d ".git" ]; then
    echo "❌ 错误：github-pages 目录丢失了 .git，请重新克隆仓库！"
    exit 1
fi

# 清空旧内容
rm -rf `ls | grep -v '.git'`

# --- 3. 同步阶段 ---
echo "🚚 正在拷贝新内容..."
cp -R ../_book/* .

# 物理删除所有不小心拷进来的 .DS_Store
find . -name ".DS_Store" -depth -exec rm {} \;

# 确保核心配置文件存在
echo 'missf.top' > CNAME
touch .nojekyll  # 防止 GitHub 屏蔽 _ 开头的文件夹

# 拷贝展示用的 README
if [ -f "../GitHub_README.md" ]; then
    cp ../GitHub_README.md README.md
fi

# --- 4. 推送阶段 ---
echo "☁️  正在推送到 GitHub..."
git add .
timestamp=$(date "+%Y-%m-%d %H:%M:%S")
git commit -m "Publish GitBook site at $timestamp (M4-Auto-Clean)"

# 强制推送以覆盖之前的任何错误版本
git push -u origin main -f

echo "✨ 全部完成！博客已在 $timestamp 更新。"
echo "💡 提示：如果网页没变化，请尝试 [Command+Shift+R] 强制刷新。"
