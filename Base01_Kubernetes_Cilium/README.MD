
# Introduction
A Kubernetes cluster orchestration and provisioning solution utilizing Terraform and Ansible for automated deployment. This project demonstrates Infrastructure as Code (IaC) principles for setting up a complete Kubernetes environment using [cilium](https://cilium.io/) as CNI. This is not a tutorial about Terraform and Ansible rather a ready made terraform and ansible is provided as reference for automating the creation of a Base Kuberenetes Cluster.

# Pre-requisites
Refer to the Main [README.MD](/README.md) for Setting Up the Proxmox Environment and Template Preparation.

## Staging or Automation Virtual Machine
- This can be a full Workstation GUI VM or a Headless Non-gui running in Proxmox VE
    - Serves as the automation controller for Terraform and Ansible deployments.
    - Must have network connectivity to Proxmox and target nodes.

## Create an API key Token For the Proxmox User
- In order to automate the creation of VM in proxmox you will need an API key token that the terraform will use.
![Add Token](/Base01_Kubernetes_Cilium/assets/add_terraform_token.png)

## Telmate Proxmox Provider Setup
To automate infrastructure provisioning with Terraform on Proxmox, you'll need the [Telmate Proxmox Provider](https://registry.terraform.io/providers/Telmate/proxmox/latest). Add the following configuration block in your `main.tf`:

```hcl
# https://registry.terraform.io/providers/Telmate/proxmox/latest
terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "3.0.2-rc04"
    }
  }
}
```
This provider enables Terraform to interact with your Proxmox infrastructure programmatically.

## Terraform and Ansiblle Installation on Staging Workstation VM
1. Install HashiCorp's GPG key.
   ```bash
   sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
   wget -O- https://apt.releases.hashicorp.com/gpg | \
   gpg --dearmor | \
   sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
   ```
2. Verify the GPG key's fingerprint. You may refer to [Terraform Installation](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli#install-terraform).
   ```bash
   gpg --no-default-keyring \
   --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
   --fingerprint
   ```
3. Add the official HashiCorp repository to your system.
   ```bash
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
   https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
   sudo tee /etc/apt/sources.list.d/hashicorp.list
   ```
4. Add Ansible Repository
   ```bash
   sudo apt-add-repository ppa:ansible/ansible
   ```
5. Update and Install Packages
   ```bash
   sudo apt update -y
   sudo apt install ansible terraform -y
   ```
# Modify Terraform Configuration Accordingly
1. Configure or set up the **vars.tf** under the "terraform" folder according to your setup.
2. Modify some of the key configurations in **main.tf**
  - clone = {the name template to use}
  - vmid
    - master, line number  84: vmid = 130
    - worker, line number 175: vmid = "${count.index + 131 }"
  - ipconfig0
    - master, line number  89: ipconfig0 = "ip=192.168.200.130/24,gw=192.168.200.1"
    - worker, line number 174: ipconfig0 = "ip=192.168.200.${count.index + 131 }/24,gw=192.168.200.1"
  - public ssh key
    - master, line number  97: <ssh_public_key_contents>
    - worker, line number 182: <ssh_public_key_contents>

# Modify Ansible Assets Configuration Accordingly
1. Configure or set-up the **k8s-assets.yml** under the "ansible" folder according to your set-up.
2. Make sure to set the Kubernetes Clusters IP Addresses

# Build the Kubernetes Cluster
1. Go to the **terraform** folder
   ```bash
   cd /Base01_Kubernetes_Cilium/terraform/
   ```
2. Initilize terraform
   ```bash
   terraform init
   ```
3. Run Terraform to orchestrate the virtual machine
   ```bash
   terraform apply
   ```
4. Change directory to "ansible"
   ```bash
   cd ..
   cd ansible
   ```
5. Prepare all Nodes
   ```bash
   ansible-playbook k8s-setup.yml -i k8s-assets.yml  --key-file ../../mylabskey
   ```
6. SetUp Master
   ```bash
   ansible-playbook k8s-master.yml -i k8s-assets.yml --key-file ../../mylabskey
   ```
7. Modify the **k8s-node_join.yml** join command
> 💡 **Tip**
> 
> Previous Ansible Playbook Outputs the Join Command
8. Run the join ansible
   ```bash
   ansible-playbook k8s-node_join.yml -i k8s-assets.yml --key-file ../../mylabskey
   ```
9. Connect to the Master Node via SSH or use the Console in proxmox and run the command to get the nodes status.
   ```bash
   kubectl get nodes
   ```
   - When all nodes are ready it should display similar to this.
   ```bash
   kyberzo@k8s-master:~$ kubectl get nodes
   NAME         STATUS   ROLES           AGE     VERSION
   k8s-master   Ready    control-plane   5m5s    v1.34.1
   k8s-node1    Ready    <none>          3m40s   v1.34.1
   k8s-node2    Ready    <none>          3m41s   v1.34.1
   k8s-node3    Ready    <none>          3m40s   v1.34.1
   ```
10. Verify Cilium Status.
   ```bash
   cilium status
   ```
   - Output when all is OK.
   ```bash
   kyberzo@k8s-master:~$ cilium status
       /¯¯\
    /¯¯\__/¯¯\    Cilium:             OK
    \__/¯¯\__/    Operator:           OK
    /¯¯\__/¯¯\    Envoy DaemonSet:    OK
    \__/¯¯\__/    Hubble Relay:       disabled
       \__/       ClusterMesh:        disabled

   DaemonSet              cilium                   Desired: 4, Ready: 4/4, Available: 4/4
   DaemonSet              cilium-envoy             Desired: 4, Ready: 4/4, Available: 4/4
   Deployment             cilium-operator          Desired: 1, Ready: 1/1, Available: 1/1
   Containers:            cilium                   Running: 4
                          cilium-envoy             Running: 4
                          cilium-operator          Running: 1
                          clustermesh-apiserver
                          hubble-relay
   Cluster Pods:          2/2 managed by Cilium
   Helm chart version:    1.18.2
   Image versions         cilium             quay.io/cilium/cilium:v1.18.2@sha256:858f807ea4e20e85e3ea3240a762e1f4b29f1cb5bbd0463b8aa77e7b097c0667: 4
                          cilium-envoy       quay.io/cilium/cilium-envoy:v1.34.7-1757592137-1a52bb680a956879722f48c591a2ca90f7791324@sha256:7932d656b63f6f866b6732099d33355184322123cfe1182e6f05175a3bc2e0e0: 4
                          cilium-operator    quay.io/cilium/operator-generic:v1.18.2@sha256:cb4e4ffc5789fd5ff6a534e3b1460623df61cba00f5ea1c7b40153b5efb81805: 1
   ```
