#!/bin/bash
set -x

# Check if action is provided
if [ -z "$1" ]; then
  echo "No action specified. Use 'create' or 'delete'."
  exit 1
fi

# Define the action
ACTION=$1

# Define the API endpoint
API_ENDPOINT="http://147.75.203.1:6610/~api/job-runs"

# Define the request body
REQUEST_BODY=$(cat <<EOF
{
  "@type": "JobRunOnCommit",
  "projectId": 2,
  "commitHash": "18e64db5bd5754e220a4f2ec2c8e9d5d13d4e5ee",
  "jobName": "External - OpenShift Agent Based Installer Helper",
  "params": {
    "GIT_REPO": ["https://github.com/tosin2013/kcli-pipelines.git"],
    "CICD_PIPELINE": ["true"],
    "ACTION": ["$ACTION"],
    "GUID": ["bv895"],
    "IP_ADDRESS": ["147.75.203.1"],
    "ZONE_NAME": ["sandbox2256.opentlc.com"],
    "AWS_ACCESS_KEY": ["AWS_ACCESS_KEY"],  
    "AWS_SECRET_KEY": ["AWS_SECRET_KEY"], 
    "VM_PROFILE": ["openshift-agent-install"],
    "FOLDER_NAME": ["sno-bond0-signal-vlan"],
    "TARGET_SERVER": ["rhel8-equinix"],
    "DEPLOY_OPENSHIFT": ["true"],
    "DISCONNECTED_INSTALL": ["false"],
    "COMMUNITY_VERSION": ["false"],
    "VERBOSE_LEVEL": ["-v"]
  },
  "refName": "refs/heads/main",
  "reason": "Triggering job via API"
}
EOF
)

# Trigger the job using curl
curl -u admin:r3dh@t123 -X POST -H "Content-Type: application/json" -d "$REQUEST_BODY" "$API_ENDPOINT"
