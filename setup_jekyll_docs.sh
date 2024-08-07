#!/bin/bash
set -euo pipefail
set -x 
# Script to install Jekyll and set up a docs template with Just the Docs theme on Ubuntu 22.04 LTS

# Use environment variables or default values
GITHUB_USERNAME=${GITHUB_USERNAME:-"tosin2013"}
GITHUB_REPO=${GITHUB_REPO:-"kcli-pipelines"}
CATEGORIES=${CATEGORIES:-"deployment,development"}
SITE_TITLE=${SITE_TITLE:-"kcli-pipelines"}
SITE_EMAIL=${SITE_EMAIL:-"tosin.akinosho@gmail.com"}
SITE_DESCRIPTION=${SITE_DESCRIPTION:-"kcli-pipelines is a repository that contains the necessary scripts and configurations to automate the setup and deployment of various environments. It leverages the capabilities of kcli (KubeVirt Command Line Interface) to manage VMs and other resources efficiently. The repository is structured to include different profiles and workflows for multiple operating systems and deployment scenarios."}
SITE_BASEURL=${SITE_BASEURL:-"/docs"}
SITE_URL=${SITE_URL:-"https://${GITHUB_USERNAME}.github.io/${GITHUB_REPO}"}
TWITTER_USERNAME=${TWITTER_USERNAME:-"tech0827"}

# Update the system packages
echo "Updating system packages..."
sudo apt-get update -y

# Install Ruby and other dependencies
echo "Installing Ruby and dependencies..."
sudo apt-get install ruby-full build-essential zlib1g-dev -y

# Set up Ruby environment variables
echo "Setting up Ruby environment variables..."
echo '# Install Ruby Gems to ~/gems' >> ~/.bashrc
echo 'export GEM_HOME="$HOME/gems"' >> ~/.bashrc
echo 'export PATH="$HOME/gems/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Install Jekyll and bundler
echo "Installing Jekyll and bundler..."
gem install jekyll bundler

# Verify the Jekyll installation
echo "Verifying Jekyll installation..."
jekyll -v

echo "Jekyll installation completed."

# Create a new Jekyll site in the docs directory
echo "Creating a new Jekyll site in the docs directory..."
jekyll new docs
cd docs

# Add Just the Docs theme to the Gemfile
echo "Adding Just the Docs theme to the Gemfile..."
echo "gem \"just-the-docs\"" >> Gemfile

# Update the _config.yml file
echo "Configuring _config.yml..."
cat > _config.yml << EOF
title: ${SITE_TITLE}
email: ${SITE_EMAIL}
description: >- # this means to ignore newlines until "baseurl:"
  ${SITE_DESCRIPTION}

baseurl: "${SITE_BASEURL}" # the subpath of your site, e.g. /blog
url: "${SITE_URL}" # the base hostname & protocol for your site, e.g. http://example.com
twitter_username: ${TWITTER_USERNAME}
github_username: ${GITHUB_USERNAME}

# Build settings
theme: just-the-docs
plugins:
  - jekyll-feed
  - jekyll-seo-tag
  - jekyll-sitemap

# Just the Docs configuration
aux_links:
  "View on GitHub":
    - "https://github.com/${GITHUB_USERNAME}/${GITHUB_REPO}"
aux_links_new_tab: true
heading_anchors: true

# Enable collection for categories
collections:
  category:
    output: true

# Default layout for category pages
defaults:
  - scope:
      path: ""
      type: category
    values:
      layout: category
EOF

# Install the necessary gems
echo "Installing necessary gems..."
bundle install

# Create a sample documentation page
echo "Creating a sample documentation page..."
cat << EOF > index.md
---
layout: default
title: Home
nav_order: 1
description: "Welcome to the documentation for ${SITE_TITLE}."
permalink: /
---

# Welcome to ${SITE_TITLE} Documentation

${SITE_DESCRIPTION}

## Categories

EOF

# Create category pages
IFS=',' read -ra CATEGORY_ARRAY <<< "$CATEGORIES"
for category in "${CATEGORY_ARRAY[@]}"; do
  echo "Creating category page for ${category}..."
  mkdir -p "_category"
  cat << EOF > "_category/${category}.md"
---
layout: category
title: ${category^}
nav_order: 2
has_children: true
permalink: /${category}/
---

# ${category^}

This is the main page for the ${category} category. Add your ${category}-related documentation here.

EOF

  echo "- [${category^}](/${category}/)" >> index.md

  # Create a sample sub-page for each category
  mkdir -p "${category}"
  cat << EOF > "${category}/sample-${category}-page.md"
---
layout: default
title: Sample ${category^} Page
parent: ${category^}
nav_order: 1
---

# Sample ${category^} Page

This is a sample page for the ${category} category. Add your ${category}-specific content here.

## Getting started with ${category^}

1. Step 1
2. Step 2
3. Step 3

EOF
done

echo "## Next steps

- Add more pages to your documentation
- Customize the theme to fit your needs
- Explore the Just the Docs features and options
" >> index.md

echo "Setup complete! Your docs template is now ready in the 'docs' directory."
echo "You can start the Jekyll server by running 'bundle exec jekyll serve' in the 'docs' directory."
echo "Remember to review and update the settings in the _config.yml file as needed."
