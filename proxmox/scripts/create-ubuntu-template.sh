#!/bin/bash
# Script to create Ubuntu cloud-init template on Proxmox
# Run this script on each Proxmox node

set -e  # Exit on any error

# Configuration
TEMPLATE_ID=9000
TEMPLATE_NAME="ubuntu-cloud"
UBUNTU_VERSION="jammy"  # Ubuntu 22.04 LTS
DOWNLOAD_URL="https://cloud-images.ubuntu.com/${UBUNTU_VERSION}/current/${UBUNTU_VERSION}-server-cloudimg-amd64.img"
IMAGE_FILE="${UBUNTU_VERSION}-server-cloudimg-amd64.img"
STORAGE="local-lvm"
MEMORY=2048
BRIDGE="vmbr0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Proxmox Ubuntu Cloud-Init Template Creator ===${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   echo "Usage: sudo $0"
   exit 1
fi

# Check if template already exists
if qm status $TEMPLATE_ID &>/dev/null; then
    echo -e "${YELLOW}Warning: VM/Template with ID $TEMPLATE_ID already exists${NC}"
    read -p "Do you want to delete it and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing VM/Template $TEMPLATE_ID..."
        qm destroy $TEMPLATE_ID
    else
        echo "Aborting."
        exit 1
    fi
fi

# Navigate to template directory
cd /var/lib/vz/template/iso

# Download Ubuntu cloud image if not present
if [ -f "$IMAGE_FILE" ]; then
    echo -e "${YELLOW}Image file already exists. Skipping download.${NC}"
else
    echo "Downloading Ubuntu $UBUNTU_VERSION cloud image..."
    wget -q --show-progress "$DOWNLOAD_URL"

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to download cloud image${NC}"
        exit 1
    fi
fi

# Verify download
if [ ! -f "$IMAGE_FILE" ]; then
    echo -e "${RED}Error: Image file not found${NC}"
    exit 1
fi

echo ""
echo "Creating VM $TEMPLATE_ID..."

# Create VM
qm create $TEMPLATE_ID \
    --name "$TEMPLATE_NAME" \
    --memory $MEMORY \
    --cores 2 \
    --net0 virtio,bridge=$BRIDGE

echo "Importing disk..."

# Import disk
qm importdisk $TEMPLATE_ID "$IMAGE_FILE" $STORAGE

echo "Configuring VM..."

# Configure VM
qm set $TEMPLATE_ID --scsihw virtio-scsi-pci
qm set $TEMPLATE_ID --scsi0 ${STORAGE}:vm-${TEMPLATE_ID}-disk-0
qm set $TEMPLATE_ID --ide2 ${STORAGE}:cloudinit
qm set $TEMPLATE_ID --boot c
qm set $TEMPLATE_ID --bootdisk scsi0
qm set $TEMPLATE_ID --serial0 socket
qm set $TEMPLATE_ID --vga serial0

# Set agent
qm set $TEMPLATE_ID --agent enabled=1

# Set default cloud-init settings (can be overridden per VM)
qm set $TEMPLATE_ID --nameserver "8.8.8.8 8.8.4.4"
qm set $TEMPLATE_ID --ciuser ubuntu

echo "Converting to template..."

# Convert to template
qm template $TEMPLATE_ID

echo ""
echo -e "${GREEN}=== Template Creation Complete ===${NC}"
echo ""
echo "Template details:"
echo "  VM ID: $TEMPLATE_ID"
echo "  Name: $TEMPLATE_NAME"
echo "  Storage: $STORAGE"
echo ""

# Cleanup option
read -p "Do you want to delete the downloaded image file to save space? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing $IMAGE_FILE..."
    rm -f "$IMAGE_FILE"
    echo -e "${GREEN}Image file removed (saved ~700MB)${NC}"
else
    echo "Keeping image file for future use."
fi

echo ""
echo -e "${GREEN}Template $TEMPLATE_ID ($TEMPLATE_NAME) is ready!${NC}"
echo ""
echo "Verify with: qm list | grep $TEMPLATE_ID"
echo ""
