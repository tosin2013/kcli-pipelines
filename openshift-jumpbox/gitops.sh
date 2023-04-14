#!/bin/bash 
# Check if the user is logged in to OpenShift
if ! oc whoami &> /dev/null; then
  echo "Error: You are not logged in to OpenShift."
  exit 1
fi


curl -OL https://raw.githubusercontent.com/tosin2013/openshift-demos/master/quick-scripts/deploy-gitea.sh
chmod +x deploy-gitea.sh
./deploy-gitea.sh

git clone https://github.com/tosin2013/sno-quickstarts.git