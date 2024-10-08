#export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -xe
if [ -f /opt/kcli-pipelines/helper_scripts/default.env ];
then 
  source /opt/kcli-pipelines/helper_scripts/default.env
else
  echo "default.env file does not exist"
  exit 1
fi

if [ ! -d /opt/ocp4-disconnected-helper ];
then 
    cd /opt/
    git clone https://github.com/tosin2013/ocp4-disconnected-helper.git
    cd ocp4-disconnected-helper
else
    cd /opt/ocp4-disconnected-helper
    git config pull.rebase false
    git config --global --add safe.directory /opt/ocp4-disconnected-helper
    git pull
fi 

if [ "$EUID" -ne 0 ]
then 
  export USE_SUDO="sudo"
fi

export USE_SUDO="sudo"

if [ -f /opt/images/ ];
then 
    cd /opt/images
    $USE_SUDO rm -rf *
    $USE_SUDO  rm -rf  .oc-mirror.log
fi