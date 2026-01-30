#!/bin/bash

# 1. 构建笔记 (使用 HonKit 适配 M4 Mac)
npx honkit build

# 2. 进入发布目录 (使用相对路径，更稳)
# 既然 github-pages 在当前目录下，直接 cd 进去即可
cd ./github-pages/

# 3. 清空旧内容（保留 .git）
# 这一步会把你之前误推上来的源码文件全部清理掉
rm -rf `ls | grep -v '.git'`

# 4. 拷贝构建结果
# 因为刚才 cd 进了子目录，所以 _book 在上一层
cp -R ../_book/* .

# 5. 重新添加 CNAME
echo 'missf.top' > CNAME

# 6. 拷贝 GitHub 项目用的 README 文件
cp ../GitHub_README.md README.md

# 7. 补充：添加 .nojekyll 文件
# 这能确保 GitHub Pages 不会过滤掉 GitBook 的下划线资源文件
touch .nojekyll

# 8. Git 提交并推送
timestamp=$(date "+%Y-%m-%d %H:%M:%S")
commit_message="Publish GitBook site at $timestamp"

git add .
git commit -m "$commit_message"

# 这里建议加一个 -f (强制推送)
# 因为你之前把源码推到了 main 分支，现在要用网页文件覆盖它
git push -u origin main -f
