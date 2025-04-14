## 5 Steps for Creating Templates and Virtual Machines on Proxmox using Linux Distro's Cloud Images

This tutorial guides you through the process of creating Templates and Virtual Machines on Proxmox using cloud-based images from various Linux distributions. We provide clear instructions for Alma Linux 9, Amazon Linux 2, CentOS 9, Fedora 38, Oracle Linux 9, RHEL 9, Rocky Linux 9, and Ubuntu 23.04 Lynx Lobster.

Note: The instructions have been tested on Proxmox 8.0.4.

Let's begin by choosing the cloud-based image. If you already have your preferred Linux distribution, skip to the 1st step.

To assist in making informed choices when selecting a Linux distribution for your virtual machines, we've compiled a table showcasing key characteristics of each cloud image. This table provides a snapshot of important attributes, including kernel version, Python version, number of processes initialized after boot, number of packages installed, free memory after boot, VM disk size, root partition disk size, used size on the root partition, free size on the root partition, root filesystem type, and whether LVM is enabled. By understanding these characteristics, you can tailor your choices to the requirements of your specific use case, ensuring optimal performance and resource utilization. Please note that an official cloud image for Amazon Linux 2023 is currently unavailable to the public.

![image](https://user-images.githubusercontent.com/4968411/263145786-f7bcccc0-5017-4383-bc6d-7abe2f53f337.png)

----

### 1. Downloading the images

Start by downloading the necessary images for the distributions you intend to utilize. These images will lay the groundwork for creating templates and virtual machines in the subsequent sections.

```sh
ssh user@your-proxmox-server

su - root

export IMAGES_PATH="/mnt/pve/nfs-data/images/" # defines the path where the images will be stored and change the path to it.

cd ${IMAGES_PATH}

# Alma Linux 9
# https://wiki.almalinux.org/cloud/Generic-cloud.html
wget https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2

wget https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/CHECKSUM -O SHA256SUMS

sha256sum -c SHA256SUMS --ignore-missing

# Download instructions for others distributions images are presented bellow.

## Amazon Linux 2
## https://cdn.amazonlinux.com/os-images/latest/
## Amazon Linux 2023 not yet available as cloud image
# wget https://cdn.amazonlinux.com/os-images/2.0.20230727.0/kvm/amzn2-kvm-2.0.20230727.0-x86_64.xfs.gpt.qcow2

## Centos 9
## https://cloud.centos.org/centos/9-stream/x86_64/images/
# wget https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2

## Fedora 38
## https://alt.fedoraproject.org/cloud/
# wget https://download.fedoraproject.org/pub/fedora/linux/releases/38/Cloud/x86_64/images/Fedora-Cloud-Base-38-1.6.x86_64.qcow2

## Oracle Linux 9
## https://yum.oracle.com/oracle-linux-templates.html
# wget https://yum.oracle.com/templates/OracleLinux/OL9/u2/x86_64/OL9U2_x86_64-kvm-b197.qcow
## Can't find Oracle CHECKUM file and signature. Just the SHA256 on downloads page
# echo "840345cb866837ac7cc7c347cd9a8196c3a17e9c054c613eda8c2a912434c956 OL9U2_x86_64-kvm-b197.qcow" > SHA256SUMS-Oracle9
## Converting image to qcow2 format
# qemu-img convert -O qcow2 -o compat=0.10 OL9U2_x86_64-kvm-b197.qcow OL9U2_x86_64-kvm-b197.qcow2
# rm OL9U2_x86_64-kvm-b197.qcow

## Red Hat 9
## https://access.redhat.com/downloads/content/479/ver=/rhel---9/9.2/x86_64/product-software
## Needs to be logged in and get a personal link to download RHEL 9 cloud image

## Rocky Linux 9
## https://rockylinux.org/alternative-images
# wget https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2

## Ubuntu 23.04 Lunar Lobster
## https://cloud-images.ubuntu.com/
# wget https://cloud-images.ubuntu.com/lunar/current/lunar-server-cloudimg-amd64.img
```

----

### 2. Configuring VM and Cloud-init Settings

Set up the environment variables to define base config for for both virtual machines (VMs) and Cloud-init settings. These variables encompass VM configuration details such as CPU model, cores, memory, and resource pool. Moreover, we establish Cloud-init settings, specifying user information, SSH key, network parameters, and more. Cloud-init is an open-source tool used for initializing and configuring virtual machines in cloud environments, enabling automated provisioning of virtual machine settings. By configuring these variables, you ensure uniform settings across the VMs and templates you create.

Define the VM configuration:

```sh
export QEMU_CPU_MODEL="host" # Specifies the CPU model to be used for the VM according your environment and the desired CPU capabilities.
export VM_CPU_SOCKETS=1
export VM_CPU_CORES=2
export VM_MEMORY=4098
export VM_RESOURCE_POOL="CustomResourcePool" # Assigns the VM to a specific resource pool for management.
```

Define the Cloud-init configuration. The specified user will be created, and its public key will be defined as an authorized key, enabling remote access using the user's private key.

```sh
export CLOUD_INIT_USER="user" # Specifies the username to be created using Cloud-init.
export CLOUD_INIT_SSHKEY="/home/user/.ssh/id_rsa.pub" # Provides the path to the SSH public key for the user.
export CLOUD_INIT_IP="dhcp"
export CLOUD_INIT_NAMESERVER="1.1.1.1"
export CLOUD_INIT_SEARCHDOMAIN="example.com"
```

Choose the Linux distribution you are working with:

```sh
export TEMPLATE_ID=1001
export VM_NAME="alma9"
export VM_DISK_IMAGE="${IMAGES_PATH}/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
## Disk image for others distributions
# export VM_DISK_IMAGE="${IMAGES_PATH}/amzn2-kvm-2.0.20230727.0-x86_64.xfs.gpt.qcow2"
# export VM_DISK_IMAGE="${IMAGES_PATH}/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
# export VM_DISK_IMAGE="${IMAGES_PATH}/Fedora-Cloud-Base-38-1.6.x86_64.qcow2"
# export VM_DISK_IMAGE="${IMAGES_PATH}/OL9U2_x86_64-kvm-b197.qcow2"
# export VM_DISK_IMAGE="${IMAGES_PATH}/rhel-9.2-x86_64-kvm.qcow2"
# export VM_DISK_IMAGE="${IMAGES_PATH}/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
# export VM_DISK_IMAGE="${IMAGES_PATH}/lunar-server-cloudimg-amd64.img"
```

----

### 3. Creating a VM as the base for the Template

In this section, we guide you through the creation of a virtual machine that will serve as the foundation for the template. Utilizing the defined environment variables, we configure the VM settings and integrate Cloud-init specifications.

```sh
# Create VM. Change the cpu model
qm create ${TEMPLATE_ID} --name ${VM_NAME} --cpu ${QEMU_CPU_MODEL} --sockets ${VM_CPU_SOCKETS} --cores ${VM_CPU_CORES} --memory ${VM_MEMORY} --numa 1 --net0 virtio,bridge=vmbr0 --ostype l26 --agent 1 --pool ${VM_RESOURCE_POOL} --scsihw virtio-scsi-single

# Import Disk
qm set ${TEMPLATE_ID} --scsi0 local-lvm:0,import-from=${VM_DISK_IMAGE}

# Add Cloud-Init CD-ROM drive. This enables the VM to receive customization instructions during boot.
qm set ${TEMPLATE_ID} --ide2 local-lvm:cloudinit --boot order=scsi0

# Cloud-init network-data
qm set ${TEMPLATE_ID} --ipconfig0 ip=${CLOUD_INIT_IP} --nameserver ${CLOUD_INIT_NAMESERVER} --searchdomain ${CLOUD_INIT_SEARCHDOMAIN}

# Cloud-init user-data
qm set ${TEMPLATE_ID} --ciupgrade 1 --ciuser ${CLOUD_INIT_USER} --sshkeys ${CLOUD_INIT_SSHKEY}

# Cloud-init regenerate ISO image, ensuring that the VM will properly initialize with the desired parameters.
qm cloudinit update ${TEMPLATE_ID}
```

----

### 4. Converting the base VM to Template

By executing the provided commands, the VM is transformed into a reusable template. The template can be cloned to produce consistent virtual machines, reducing setup time and ensuring uniformity across your environment.

```sh
qm set ${TEMPLATE_ID} --name "${VM_NAME}-Template"

qm template ${TEMPLATE_ID}
```

----

### 5. Create a new VM by cloning the Template

Concluding the tutorial by cloning the template to create a new virtual machine

```sh
export VM_ID=$(pvesh get /cluster/nextid)

qm clone ${TEMPLATE_ID} ${VM_ID}  --name ${VM_NAME}

qm start ${VM_ID}
```

To access the cloned VM, utilize its IP address along with the user's private key for SSH authentication. Please note that some distributions, such as Amazon Linux 2 and Ubuntu 23.04, might not display the guest's IP directly on the Proxmox GUI due to the absence of the qemu-guest-agent package.

```sh
ssh user@192.168.0.123 -i ~/.ssh/id_rsa
```
