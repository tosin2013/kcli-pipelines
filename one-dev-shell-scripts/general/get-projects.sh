#!/bin/bash

# Configuration
#ONEDEV_SERVER_URL="http://your-onedev-server.com"
export ONEDEV_SERVER_URL="http://147.75.203.1:6610"
export API_TOKEN="Gbq7ifBkfuuxa9shlnjlm2GkZRgCHo3abhu4GBHU"
ENDPOINT="/api/projects"  # Example endpoint to list projects

# Make a GET request to the OneDev API to list projects
response=$(curl -s -H "Authorization: Bearer $API_TOKEN" "$ONEDEV_SERVER_URL$ENDPOINT")

# Check if the response contains valid JSON
if echo "$response" | jq . > /dev/null 2>&1; then
    echo "Valid JSON response:"
    # Extract project IDs
    project_ids=$(echo "$response" | jq '.[].id')
    echo "Project IDs:"
    echo "$project_ids"
else
    echo "Invalid or empty JSON response:"
    echo "$response"
fi
