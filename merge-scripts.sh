# git remote add gitlab/main  git@gitlab.tosins-cloudlabs.com:tosin/kcli-pipelines.git
# git branch --set-upstream-to=gitlab/main  gitlab/main

git checkout gitlab/main
git pull gitlab/main main
echo "edit code"
echo "add changes"
git commit -m "getting changes from gitlab"
git checkout main
git merge gitlab/main