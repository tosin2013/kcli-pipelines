if [ ! -z $DEPLOY_OPENSHIFT ];
then 
    if [ $DEPLOY_OPENSHIFT == true ];
    then 
        echo "Deploying OpenShift"
        sudo yq eval ".deploy_openshift = true" -i /opt/qubinode_navigator/inventories/${TARGET_SERVER}/group_vars/control/${DEPLOYMENT_CONFIG}  || exit $?
    else 
        echo "Not deploying OpenShift"
        yq eval ".deploy_openshift = false" -i /opt/qubinode_navigator/inventories/${TARGET_SERVER}/group_vars/control/${DEPLOYMENT_CONFIG}  || exit $?
    fi
fi

if [ ! -z ${LAUNCH_STEPS} ];
then
    if [ $LAUNCH_STEPS == true ];
    then 
        echo "Auto depolying Launch Steps"
        yq eval ".launch_steps = true" -i /opt/qubinode_navigator/inventories/${TARGET_SERVER}/group_vars/control/${DEPLOYMENT_CONFIG}  || exit $?
        yq eval ".installer_wait = true" -i /opt/qubinode_navigator/inventories/${TARGET_SERVER}/group_vars/control/${DEPLOYMENT_CONFIG}  || exit $?
    else 
        echo "Skipping Launch Steps"
        yq eval ".launch_steps = false" -i /opt/qubinode_navigator/inventories/${TARGET_SERVER}/group_vars/control/${DEPLOYMENT_CONFIG}  || exit $?
        yq eval ".installer_wait = false" -i /opt/qubinode_navigator/inventories/${TARGET_SERVER}/group_vars/control/${DEPLOYMENT_CONFIG}  || exit $?
    fi
fi 

if [ ! -z ${TAG} ];
then
    if [ $TAG == "4.15" ];
    then 
        echo "DEPLOYING 4.15"
    else 
        echo "Skipping Launch Steps"
        yq eval ".tag = ${TAG}" -i /opt/qubinode_navigator/inventories/${TARGET_SERVER}/group_vars/control/${DEPLOYMENT_CONFIG}  || exit $?
    fi
fi 


if [ ! -z ${DISCONNECTED_INSTALL} ];
then
    if [ $DISCONNECTED_INSTALL == true ];
    then 
        echo "RUNNING DISCONNECTED"
        yq eval ".disconnected = false" -i /opt/qubinode_navigator/inventories/${TARGET_SERVER}/group_vars/control/${DEPLOYMENT_CONFIG}  || exit $?
    else 
        echo "Skipping Disconnected setting"
       
    fi
fi 
