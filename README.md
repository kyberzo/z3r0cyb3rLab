![Labs Overview](/assets/Labs%20Set-Up%20Overview.png)
# Introduction
This repository contains various cybersecurity lab setups and practical exercises designed to enhance security skills and knowledge. The lab environment provides hands-on experience with security tools and techniques.

# TLDR;
- Prepare Proxmox Environment
- SSH key setup
- Create A Template Using ubuntu 24.04 Cloud-Init Image
- Using the CloudInit Ubuntu Server 24.04 Base Image create a Kubernetes Ready Template.

# Prerequisites and Environments
Most lab environments will be built using Proxmox virtualization. Some standalone labs can be performed in any virtualization platform, though VMware will be used primarily for standalone cases. For the time being requirements include:
-  Proxmox - any old machine will do to serve as your proxmox server, the higher RAM the better at minimum 16GB of RAM.

## Proxmox Intallation
Installation for Proxmox is stright forward, download and install it on a separate machine.
1. Go to the Proxmox Download center: https://www.proxmox.com/en/downloads
2. Download the Latest Proxmox VE latest ISO.
3. You can convert the Iso as a bootable USB drive, personally I use Ventoy
   - Ventoy is a standalone bootable drive that can launch a selected ISO from USB.
   - Ventoy can be found here: https://www.ventoy.net/en/download.html
4. Once you Have Ventoy on USB copy the Proxmox Iso.
5. Boot with the USB and Select and Install the Proxmox VE.

### Proxmox Post-Installation
> This mainly optional, specially to remove the Screen Nag about the enterprise subscription. [Post Install Script](https://community-scripts.github.io/ProxmoxVE/scripts?id=post-pve-install)

## SSH Key Setup
- This ssh key will be used for the virtual Machine templates as well as the ssh key for terraform and ansible automation, if you prefer to have a separate key you may do so.
   ```bash
   ssh-keygen -t rsa -C "automation" -f ./mylabskey
   ```
- Leave the passphrase blank on this key.
- For future use with ansible set the permissions
   ```bash
   chmod 400 mylabskey
   ```

## Base Template Preparation: Vanila Ubuntu Server
A preconfigured cloud init ubuntu image to serve as a base for building or installing other components.
### Create a virtual Machine (VM)
1. General
   - **Node:** pve (select the proxmox node if you are runnning proxmox on cluster oterwise leave the default)
   - **VM ID:** 900 (The VM ID number, i typically use a high number to keep my template below, ie 999)
   - **Name:** ubuntu-server-24-04-3-lts-template (The name of the VM which will be carried over when converting to template.)
2. OS
   - Select **"Do not use any media."** (we are going to use cloud init image)
3. System
   - Check the **"Qemu-Agent"** (Allows to control the VM from the proxmox interface ie Shutdown. This also requires installing the qemu-guest-agent to be installed in the guest VM)
4. Disk
   - Delete the disk. We will setup this later using the cloud init image.
5. CPU
   - Leave as default, this is a template.
6. Memory
   - Leave as default or set to only 1024 (1GB) as this is only a template.
7. Network
   - Leave as default (VMBr0) of set to your network settings.
8. Confirm
   - Review and click finish.

### Add CloudInit Drive
1. Select the Newly Created Virtual Machine 
2. Select **"Hardware"** on the Right Pane Window
3. Add **"CloudInit Drive"** 
   - **Storage:** local-lvm

### Set Your Default Values and Finalize Image
1. Values
   - User: {your user  name}
   - Password: {your password}
   - DNS Domain: use host settings
   - DNS Servers: use host settings
   - SSH Public Key: {your ssh public key}
   - IP Config (net0): Set DHCP (even if will be using static IP later)
2. Finalize the VM Image
   - Click on **"Regenerate Image"**

### Import the Cloud Image as Disk to the VM Template
1. SSH to the proxmox server or use the console on the proxmox server web GUI.
2. Download the Cloud Image
    ```bash
    wget https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-amd64.img
    ```
3. Rename the file extension of the image to .qcow2
    ```bash
    mv ubuntu-24.04-minimal-cloudimg-amd64.img ubuntu-24.04.qcow2
    ```
4. Resize the ubuntu-24.04.qcow2 cloud image
    ```bash
    qemu-img resize ubuntu-24.04.qcow2 24
    ```
5. Import the cloud image into Proxmox
    ```bash
    qm importdisk (VM ID) ubuntu-24.04.qcow2 local-lvm
    ```

### Attach the Imported Disk to the VM Template
1. Select the Created VM Template
2. On **Hardware** Tab at the right pane.
3. Double Click on "Unused Disk 0" or Click on "Edit" to attach the disk
   - This automatically set the unused disk attached, under **Disk Image** should show something like, local-lvm:vm-{VM ID}-disk-0
   - If your Host Machine (Proxmox Server) using SSD make sure to check **"ssd emulation"**
4. The Template VM Image should now have a Hard Disk

### Set the boot order
1. Select **"Options"** on the Left Menu of the Right Pane Just under the "CloudInit Image" Menu
2. Edit the **"Boot Order"**
3. Enable the Newly Added Disk and drag it up as the first option for booting.
4. Click **"OK"**

### Convert To Template
1. Select the Freshly Configured Virtual Image
2. Right Click and Select **"Convert To Template"**


## Base Template Preparation: Kubernetes Ready Ubuntu
A preconfigured built upon the Vanila Ubuntu Server for that will serve as template for building the kubernetes cluster. Some configuration will require manual setting, while possible in automation for now, preferrably we will premade some of the components and settings, ready for kuberenets cluster deployment.

### Create a Virtual Machine Using the Template
1. If you are using the same name used in the Vanila Template Creation **"ubuntu-server-24-04-3-lts-template"**. Right Click on the Template and Select **"Clone"**
2. Fill the the Necessary Fileds and Options.
   - Target Node: pve (your proxmox node)
   - Mode: Full Clone 
   - VM ID : 901 (This will be converted again as a Template and will kep this under the Vanila Ubuntu Template)
   - Name: ubuntu-server-2404-kubernetes-template (you may set your prefered name)

### Start the Created Virtual Machine "ubuntu-server-2404-kubernetes-template"
1. Connect via SSH or Use the Proxmox Console of the Virtual Machine.
2. install the qemu-guest-agent
    ```bash
    sudo apt update
    sudo apt install qemu-guest-agent
    ```
3. Proceed with the Other Configuration.

### Set-up a container runtime
For this lab environment, we will use `containerd` as our container runtime:
1. Install required packages:
    ```bash
    sudo apt update
    sudo apt install containerd
    ```
2. Create default containerd configuration:
    ```bash
    sudo mkdir -p /etc/containerd
    sudo containerd config default | sudo tee /etc/containerd/config.toml
    ```
3. Open the config.toml
    ```bash
    sudo nano /etc/containerd/config.toml
    ```
4. Search for "runc.options" by using CTRL+W
5. enable SystemdCgroup by setting it to "true"
    ```text
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
    ```
6. Write (CTRL+O) and Exit (CTRL+X)

### Verify Swap is Disabled
- Kubernetes requires swap to be disabled for optimal performance and scheduling:
1. Check current swap status:
    ```bash
    sudo swapon --show
    ```
2. Disable swap immediately:
    ```bash
    sudo swapoff -a
    ```
3. Prevent swap from enabling on reboot by commenting out swap entries in /etc/fstab:
    ```bash
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    ```
4. Verify swap is disabled:
    ```bash
    free -m
    ```

### Enable Bridging
Bridging must be enabled for proper communication between master and worker nodes:
- Required for Container Network Interface (CNI) functionality
- Prevents node connectivity issues when using Cilium as CNI
- Ensures proper network traffic flow in the Kubernetes cluster

1. Open sysctl.conf
    ```bash    
    sudo nano /etc/sysctl.conf
    ```
2. Make sure that this line is enabled or not commented.
    ```text
    net.ipv4.ip_forward=1
    ```
3. Create a file k8s.conf
    ```text
    sudo nano /etc/modules-load.d/k8s.conf
    ```
4. Add the entry.
    ```text
    br_netfilter
    ```

### Convert the Virtual Machine as a Template
1. Shutdown the Virtual Machine.
2. Right click on the Virtual Machine (if using the same as "ubuntu-server-2404-kubernetes-template")
3. Select **"Convert to Template"**
