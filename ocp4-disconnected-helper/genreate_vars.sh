#!/bin/bash

# Convert YAML to JSON
yq eval -o=json '.' extra_vars/setup-harbor-registry-vars.yml  > output.json

# Load the certificate contents into a shell variable
certificate=$(cat harbor.rtodgpoc.com.bundle.crt)
certificate_key=$(cat harbor.rtodgpoc.com.key)

# Use jq to update the ssl_certificate field with the certificate
jq --arg cert "$certificate" '.ssl_certificate = $cert' output.json > /tmp/1.json
jq --arg cert "$certificate_key" '.ssl_certificate_key = $cert' /tmp/1.json > test_new.json

# Convert JSON back to YAML
yq eval --output-format=yaml '.' test_new.json > output.yaml

