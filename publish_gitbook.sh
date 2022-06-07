gitbook install && gitbook build

cd ~/Documents/GitBook/github-pages/

cp -R ../_book/* .

git add .

git commit -m "shell script commit"

git push -u origin main
