# Introduction
A Kubernetes cluster orchestration and provisioning solution utilizing Terraform and Ansible for automated deployment. This project demonstrates Infrastructure as Code (IaC) principles for setting up a complete Kubernetes environment using [cilium](https://cilium.io/) as CNI.

# Pre-requisites
Refer to the Main README.MD for Setting Up the Requirements to proceed.

## Control VM Requirements
- Workstation VM or Ubuntu Server (Headless) running in Proxmox VE
    - Serves as the automation controller for Terraform and Ansible deployments
    - Must have network connectivity to Proxmox and target nodes
## Template Requirements
- Kubernetes-ready VM template in Proxmox
    - Base template for creating cluster nodes
    - Pre-configured with necessary system requirements
    - This template will be used to create 1 Master Node and 3 Worker Nodes.

## Create Terraform User for Proxmox