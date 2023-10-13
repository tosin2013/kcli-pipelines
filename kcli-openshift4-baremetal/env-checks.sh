if [ ! -z $DEPLOY_OPENSHIFT ];
then 
    if [ $DEPLOY_OPENSHIFT == "true" ];
    then 
        echo "Deploying OpenShift"
    else 
        echo "Not deploying OpenShift"
        yq eval ".deploy_openshift = false" -i /opt/quibinode_navigator/inventories/${TARGET_SERVER}/group_vars/control/kcli-openshift4-baremetal.yml || exit $?
    fi
fi

if [ ! -z ${LAUNCH_STEPS} ];
then
    if [ $LAUNCH_STEPS == "true" ];
    then 
        echo "Auto depolying Launch Steps"
    else 
        echo "Skipping Launch Steps"
        yq eval ".launch_steps = false" -i /opt/quibinode_navigator/inventories/${TARGET_SERVER}/group_vars/control/kcli-openshift4-baremetal.yml || exit $?
    fi
fi 

if [ ! -z ${TAG} ];
then
    if [ $TAG == "4.13" ];
    then 
        echo "DEPLOYING 4.13"
    else 
        echo "Skipping Launch Steps"
        yq eval ".tag = ${TAG}" -i /opt/quibinode_navigator/inventories/${TARGET_SERVER}/group_vars/control/kcli-openshift4-baremetal.yml || exit $?
    fi
fi 