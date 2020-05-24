#!/bin/bash

# Checkout
# Add all files
# Commit the changes
# Delete the master branch
# Rename the current branch to master
# Force update repository

git checkout --orphan latest_branch
git add -A
git commit -am "delete commit history"
git branch -D master
git branch -m master
git push -f origin master
