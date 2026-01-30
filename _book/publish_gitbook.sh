#!/bin/bash

# 构建 gitbook
gitbook install && gitbook build

# 进入 GitHub Pages 仓库并清空内容（保留 .git）
cd /Users/hercules/GitBook/github-pages/
rm -rf `ls | grep -v '.git'`

# 拷贝构建结果
cp -R ../_book/* .

# 重新添加 CNAME
echo 'missf.top' > CNAME  # 替换成你的域名

# 拷贝 GitHub 项目用的 README 文件
cp ../GitHub_README.md README.md

timestamp=$(date "+%Y-%m-%d %H:%M:%S")
commit_message="Publish GitBook site at $timestamp"

# Git 提交
git add .
git commit -m "$commit_message"
git push -u origin main
