#!/bin/bash

# Create Bootable USB Bundle - Complete offline RAG system with Ubuntu Live
# This script creates everything needed for a bootable USB that runs without any pre-installed OS

set -e

# Install prerequisites
sudo apt update
sudo apt install -y git
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
rm get-docker.sh

BUNDLE_DIR="./usb-bundle"
ISO_URL="https://releases.ubuntu.com/24.04.1/ubuntu-24.04.1-desktop-amd64.iso"
ISO_FILE="ubuntu-24.04.1-desktop-amd64.iso"

echo "=========================================="
echo "Creating Bootable USB Bundle"
echo "=========================================="
echo ""
echo "This will create a complete bootable system that includes:"
echo "  - Ubuntu 24.04 Live ISO"
echo "  - Docker images (Ollama + Open Web UI)"
echo "  - Pre-downloaded AI models"
echo "  - Auto-installer scripts"
echo ""
echo "Requirements:"
echo "  - 20GB+ free disk space for bundle creation"
echo "  - 16GB+ USB drive for final deployment"
echo "  - Internet connection (for downloading Ubuntu ISO)"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Create bundle directory
echo ""
echo "Step 1: Creating bundle directory..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"

# Download Ubuntu ISO if not present
echo ""
echo "Step 2: Downloading Ubuntu 24.04 ISO..."
if [ -f "$ISO_FILE" ]; then
    echo "  ISO already exists, skipping download..."
else
    echo "  Downloading from Ubuntu servers (3.8GB, this may take a while)..."
    curl -L -o "$ISO_FILE" "$ISO_URL"
fi
mv "$ISO_FILE" "$BUNDLE_DIR/" 2>/dev/null || cp "$ISO_FILE" "$BUNDLE_DIR/"

# Save Docker images
echo ""
echo "Step 3: Saving Docker images..."
echo "  - Pulling and saving Ollama image..."
docker pull ollama/ollama:latest
docker save ollama/ollama:latest | gzip > "$BUNDLE_DIR/ollama-image.tar.gz"

echo "  - Pulling and saving Open Web UI image..."
docker pull ghcr.io/open-webui/open-webui:main
docker save ghcr.io/open-webui/open-webui:main | gzip > "$BUNDLE_DIR/open-webui-image.tar.gz"

# Export Ollama models
echo ""
echo "Step 4: Exporting Ollama models..."
echo "  - Checking if models are downloaded..."

# Check if ollama container is running
if ! docker ps | grep -q ollama; then
    echo "  - Starting Ollama temporarily..."
    docker compose -f docker-compose.prod.yml up -d ollama
    sleep 5
fi

# Check and pull models if needed
if ! docker exec ollama ollama list | grep -q "llama3:8b-instruct-q6_K"; then
    echo "  - Pulling llama3:8b-instruct-q6_K (this may take a while)..."
    docker exec ollama ollama pull llama3:8b-instruct-q6_K
fi

if ! docker exec ollama ollama list | grep -q "nomic-embed-text"; then
    echo "  - Pulling nomic-embed-text..."
    docker exec ollama ollama pull nomic-embed-text
fi

# Copy models from ollama container
echo "  - Copying models..."
docker cp ollama:/root/.ollama "$BUNDLE_DIR/ollama-models"

# Copy project files
echo ""
echo "Step 5: Copying project files..."
mkdir -p "$BUNDLE_DIR/project"
rsync -av \
    --exclude='venv' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.git' \
    --exclude='usb-bundle' \
    --exclude='app' \
    --exclude='main.py' \
    --exclude='index.html' \
    --exclude='requirements.txt' \
    --exclude='Dockerfile' \
    --exclude='docker-compose_dev.yml' \
    ./ "$BUNDLE_DIR/project/"

# Create scripts directory
echo ""
echo "Step 6: Creating installer scripts..."
mkdir -p "$BUNDLE_DIR/scripts"

# Create the main installer script for Live USB
cat > "$BUNDLE_DIR/scripts/install.sh" << 'INSTALLER_EOF'
#!/bin/bash

# Auto-installer for Live USB - Runs in Ubuntu Live session

set -e

echo "=========================================="
echo "Offline RAG System - Live USB Installer"
echo "=========================================="
echo ""
echo "This will install and start the RAG system in this Live session."
echo ""

# Detect USB mount point
USB_MOUNT=$(df -h | grep -E '/media/ubuntu/|/mnt/' | head -1 | awk '{print $6}')
if [ -z "$USB_MOUNT" ]; then
    echo "Error: Could not detect USB mount point."
    echo "Please navigate to the USB drive directory and run this script."
    exit 1
fi

echo "USB detected at: $USB_MOUNT"
echo ""

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    sudo apt-get update
    sudo apt-get install -y docker.io docker-compose
    sudo systemctl start docker
    sudo usermod -aG docker ubuntu
    echo "Docker installed."
    echo ""
fi

# Create working directory
WORK_DIR="$HOME/rag-system"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Load Docker images
echo "Loading Docker images..."
echo "  - Loading Ollama (this takes a few minutes)..."
sudo docker load < "$USB_MOUNT/ollama-image.tar.gz"

echo "  - Loading Open Web UI..."
sudo docker load < "$USB_MOUNT/open-webui-image.tar.gz"

# Copy project files
echo ""
echo "Copying project files..."
cp -r "$USB_MOUNT/project/"* "$WORK_DIR/"

# Start Ollama temporarily to load models
echo ""
echo "Setting up AI models..."
sudo docker compose -f docker-compose.prod.yml up -d ollama
sleep 5

# Copy models
echo "  - Loading pre-trained models..."
sudo docker cp "$USB_MOUNT/ollama-models/." ollama:/root/.ollama/

# Restart to pick up models
sudo docker compose -f docker-compose.prod.yml restart ollama
sleep 3

# Start the full system
echo ""
echo "Starting RAG System..."
sudo docker compose -f docker-compose.prod.yml up -d

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "Open Web UI is now running at:"
echo "  http://localhost:3000"
echo ""
echo "Opening browser..."
xdg-open http://localhost:3000 2>/dev/null || firefox http://localhost:3000 2>/dev/null || true
echo ""
echo "To stop the system:"
echo "  cd $WORK_DIR && sudo docker compose -f docker-compose.prod.yml down"
echo ""
echo "NOTE: This is a Live session - data will be lost on reboot."
echo "To make permanent, install Ubuntu to hard drive first."
echo ""
INSTALLER_EOF

chmod +x "$BUNDLE_DIR/scripts/install.sh"

# Create desktop shortcut for installer
cat > "$BUNDLE_DIR/scripts/RAG-System-Installer.desktop" << 'DESKTOP_EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=RAG System Installer
Comment=Install and start the Offline RAG System
Exec=bash -c 'cd /media/ubuntu/*/scripts && ./install.sh; exec bash'
Icon=utilities-terminal
Terminal=true
Categories=System;
DESKTOP_EOF

chmod +x "$BUNDLE_DIR/scripts/RAG-System-Installer.desktop"