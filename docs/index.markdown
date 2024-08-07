---
layout: default
title: Home
nav_order: 1
description: "Welcome to the documentation for kcli-pipelines."
permalink: /
---

# Welcome to kcli-pipelines Documentation

kcli-pipelines is a repository that houses a collection of scripts and configurations that facilitate the deployment and management of VMs using the KCLI (Karmab's Command Line Interface) project. It leverages the capabilities of KCLI to automate workflows, ensuring that VMs are consistently and correctly deployed in various environments.

### Key Features of kcli-pipelines

- **Automated VM Deployments**: Automates the process of deploying VMs, reducing manual intervention and potential errors.
- **Multi-Environment Support**: Supports the creation and management of KCLI profiles for multiple environments, making it versatile for diverse infrastructure needs.
- **CI/CD Integration**: Provides scripts for integrating VM deployments into continuous integration and continuous deployment (CI/CD) pipelines, enhancing DevOps workflows.
- **Extensive Documentation**: Includes comprehensive documentation for configuring and deploying VMs, ensuring ease of use and implementation.

## Getting Started with kcli-pipelines

To get started with kcli-pipelines, you need to clone the repository and set up the necessary configurations. Here’s a step-by-step guide to help you begin:

### Step 1: Clone the Repository

```bash
git clone https://github.com/tosin2013/kcli-pipelines.git
cd kcli-pipelines
```

### Step 2: Configure KCLI Profiles

kcli-pipelines allows you to create KCLI profiles tailored for different environments. This configuration step is crucial for ensuring that your VMs are deployed according to your specific requirements.

- Navigate to the [configuration guide](https://github.com/tosin2013/kcli-pipelines/blob/main/docs/configure-kcli-profiles.md) to set up your profiles.

### Step 3: Deploying VMs

Once your profiles are configured, you can deploy VMs using the provided scripts. For instance, to deploy a VM using the `deploy-vm.sh` script, follow these steps:

```bash
./deploy-vm.sh -p <profile_name> -n <vm_name>
```

Refer to the [deployment documentation](https://github.com/tosin2013/kcli-pipelines/blob/main/docs/deploy-vm.md) for detailed instructions.


## Categories
- [deployment/index.md
- [development/index.md
- [configuration/index.md
- [troubleshooting/index.md
## Next steps

- Add more pages to your documentation
- Customize the theme to fit your needs
- Explore the Just the Docs features and options
