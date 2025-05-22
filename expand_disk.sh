#!/bin/bash
set -e

echo "AWS EC2 Disk Expansion Script"
echo "============================"
echo ""
echo "This script will help you expand your EC2 disk capacity."
echo ""

# Check current disk usage
echo "Current disk usage:"
df -h /

# Check if running on EC2
if [ ! -f /sys/hypervisor/uuid ] || [ "$(head -c 3 /sys/hypervisor/uuid)" != "ec2" ]; then
    echo "Warning: This may not be an EC2 instance. Some operations might fail."
fi

echo ""
echo "Options:"
echo "1. Expand existing EBS volume (requires AWS CLI + permissions)"
echo "2. Add swap space to provide more memory"
echo "3. Clean up disk space (aggressive)"
echo "4. Exit"
echo ""

read -p "Choose an option (1-4): " option

case $option in
    1)
        echo "Installing AWS CLI if not present..."
        if ! command -v aws &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y awscli
        fi
        
        echo "To expand your EBS volume:"
        echo "1. Get your instance ID:"
        instanceid=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
        echo "   Instance ID: $instanceid"
        
        echo "2. Get your volume ID:"
        echo "   Run: aws ec2 describe-instances --instance-id $instanceid --query 'Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId' --output text"
        
        echo "3. Modify the volume size (replace vol-xxx with your volume ID):"
        echo "   Run: aws ec2 modify-volume --volume-id vol-xxx --size 20"
        
        echo "4. After the volume is modified, expand the partition:"
        echo "   Run: sudo growpart /dev/xvda 1"
        
        echo "5. Resize the filesystem:"
        echo "   Run: sudo resize2fs /dev/xvda1"
        
        echo "Instructions have been provided. You'll need to run these commands with proper AWS permissions."
        ;;
    2)
        echo "Adding 2GB of swap space..."
        
        # Check if swap already exists
        if swapon --show | grep -q "/swapfile"; then
            echo "Swap file already exists. Removing it first..."
            sudo swapoff /swapfile
            sudo rm /swapfile
        fi
        
        # Create new swap file
        echo "Creating 2GB swap file..."
        sudo fallocate -l 2G /swapfile
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        
        # Make swap permanent
        if ! grep -q "/swapfile" /etc/fstab; then
            echo "Adding swap to fstab..."
            echo "/swapfile swap swap defaults 0 0" | sudo tee -a /etc/fstab
        fi
        
        echo "Swap added successfully:"
        free -h
        ;;
    3)
        echo "Performing aggressive disk cleanup..."
        
        # Clean package cache
        sudo apt-get clean
        sudo apt-get autoclean
        sudo apt-get autoremove -y
        
        # Remove old logs
        sudo journalctl --vacuum-time=1d
        
        # Remove cached packages that can be re-downloaded
        sudo apt-get clean
        
        # Remove old kernels (CAUTION)
        echo "Removing old kernels..."
        sudo apt-get autoremove --purge -y
        
        # Clear temp directories
        sudo rm -rf /tmp/*
        
        # Clear user cache
        rm -rf ~/.cache/*
        
        # Clear thumbnails
        rm -rf ~/.thumbnails/*
        
        # Remove all Ollama models
        if [ -d ~/.ollama/models ]; then
            echo "Removing Ollama models to free space..."
            rm -rf ~/.ollama/models/*
        fi
        
        # Remove apt lists
        sudo rm -rf /var/lib/apt/lists/*
        
        # Show new disk space
        echo "Disk space after cleanup:"
        df -h /
        ;;
    4)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

echo ""
echo "Disk expansion operations completed."
echo "Current disk status:"
df -h / 