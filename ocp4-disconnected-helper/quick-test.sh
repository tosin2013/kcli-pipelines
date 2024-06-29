#!/bin/bash

export HARBOR_SERVER_URL="harbor.rtodgpoc.com"
export USERNAME="admin"
export PASSWORD="notHarbor12345"

curl -X GET \
  -u ${USERNAME}:${PASSWORD} \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  https://${HARBOR_SERVER_URL}/api/v2.0/csrf

curl -X POST \
  -u ${USERNAME}:${PASSWORD} \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -H "X-Harbor-CSRF-Token: <csrf-token>" \
  -d '{
    "project_name": "my-new-project",
    "description": "This is a new project."
  }' \
  https://${HARBOR_SERVER_URL}/api/v2.0/projects