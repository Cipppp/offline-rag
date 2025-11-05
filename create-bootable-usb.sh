#!/bin/bash

# Create Bootable USB Bundle - Complete offline RAG system with Ubuntu Live
# This script creates everything needed for a bootable USB that runs without any pre-installed OS

set -e

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
echo "  - 32GB+ USB drive for final deployment"
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
    --exclude='usb-bundle 2' \
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

# Create quick start guide
cat > "$BUNDLE_DIR/QUICKSTART.txt" << 'QUICKSTART_EOF'
BOOTABLE USB - QUICK START GUIDE
=================================

CREATING THE BOOTABLE USB:
1. You need a 32GB+ USB drive (all data will be erased!)
2. Download and install:
   - Windows: Rufus (https://rufus.ie)
   - Mac/Linux: Etcher (https://www.balena.io/etcher/)

3. Flash the Ubuntu ISO to USB:
   - Open Rufus or Etcher
   - Select: usb-bundle/ubuntu-24.04.1-desktop-amd64.iso
   - Select your USB drive
   - Click "Flash" or "Start"
   - Wait for completion

4. After flashing, the USB will be reformatted. You need to copy the remaining files:
   - Re-insert the USB drive
   - Copy these folders to the USB drive:
     * ollama-image.tar.gz
     * open-webui-image.tar.gz
     * ollama-models/
     * project/
     * scripts/
     * QUICKSTART.txt (this file)

BOOTING FROM USB:
1. Insert USB into target computer
2. Restart computer
3. Press boot menu key during startup:
   - Dell: F12
   - HP: F9 or Esc
   - Lenovo: F12
   - ASUS: F8 or Esc
   - Acer: F12
   - Mac: Hold Option key
4. Select the USB drive from boot menu
5. Choose "Try Ubuntu" (Live session)
6. Wait for desktop to load

RUNNING THE RAG SYSTEM:
1. Double-click "Files" icon on desktop
2. Navigate to the USB drive (usually in /media/ubuntu/)
3. Open the "scripts" folder
4. Double-click "install.sh"
5. Wait for installation (5-10 minutes)
6. Browser will open automatically to http://localhost:3000

USING THE SYSTEM:
1. In Open Web UI, select "llama3:8b-instruct-q6_K" model
2. Click the document icon (top right) to upload PDFs
3. Start chatting and asking questions!

IMPORTANT NOTES:
- Live USB sessions don't save data after reboot
- You need to run the installer each time you boot
- For permanent installation, install Ubuntu to hard drive first
- Requires 8GB+ RAM for best performance

TROUBLESHOOTING:
- If Docker not found: Wait a minute and try again
- If USB not detected: Manually navigate to /media/ubuntu/YOUR_USB/scripts
- If models not loading: Check USB has all folders copied correctly

SYSTEM REQUIREMENTS:
- 64-bit computer with 8GB+ RAM
- USB 3.0 port recommended (faster loading)
- 20GB free RAM/storage during Live session
QUICKSTART_EOF

# Create detailed README for bootable USB
cat > "$BUNDLE_DIR/README-BOOTABLE.txt" << 'README_EOF'
BOOTABLE USB BUNDLE - COMPLETE OFFLINE RAG SYSTEM
==================================================

This bundle contains everything needed to run a complete AI-powered RAG system
from a bootable USB drive, without requiring any pre-installed operating system.

WHAT'S INCLUDED:
================
1. ubuntu-24.04.1-desktop-amd64.iso (3.8GB)
   - Bootable Ubuntu Live environment

2. ollama-image.tar.gz (2.7GB)
   - Ollama AI runtime Docker image

3. open-webui-image.tar.gz (1.5GB)
   - Open Web UI Docker image

4. ollama-models/ (~5GB)
   - llama3:8b-instruct-q6_K - Language model
   - nomic-embed-text - Embedding model

5. project/
   - Docker configurations
   - RAG system setup

6. scripts/
   - install.sh - Auto-installer
   - Desktop shortcut

TOTAL SIZE: ~13GB
USB REQUIRED: 32GB+ recommended

TWO-STEP DEPLOYMENT PROCESS:
============================

STEP 1: CREATE BOOTABLE USB
---------------------------
1. Use Rufus (Windows) or Etcher (Mac/Linux)
2. Flash ubuntu-24.04.1-desktop-amd64.iso to USB
3. After flashing completes, re-insert USB
4. Copy remaining files to USB:
   - ollama-image.tar.gz
   - open-webui-image.tar.gz
   - ollama-models/
   - project/
   - scripts/
   - *.txt files

STEP 2: BOOT AND INSTALL
-----------------------
1. Boot target computer from USB
2. Select "Try Ubuntu" (Live session)
3. Wait for desktop
4. Open Files, navigate to USB drive
5. Run scripts/install.sh
6. Wait 5-10 minutes
7. Access at http://localhost:3000

WHY TWO STEPS?
==============
- ISO creates bootable environment
- Remaining files contain the actual application
- This approach allows maximum compatibility
- ISO must be flashed; other files are copied

FEATURES:
=========
- No internet required
- No pre-installed OS needed
- Complete AI chat system
- Document Q&A with RAG
- Modern web interface
- Completely private and offline

TECHNICAL DETAILS:
==================
- OS: Ubuntu 24.04 Live
- Runtime: Docker + Docker Compose
- LLM: Llama 3 (8B parameters)
- UI: Open Web UI
- Vector DB: ChromaDB (embedded)
- Port: 3000

LIMITATIONS:
============
- Live session: Data lost on reboot
- Requires 8GB+ RAM
- First run takes 5-10 minutes
- USB 3.0 recommended for speed

For permanent installation:
1. Install Ubuntu to hard drive
2. Then use the regular export-bundle.sh option

SUPPORT:
========
See project/README.md for detailed documentation.
README_EOF

# Create summary file
cat > "$BUNDLE_DIR/BUNDLE-CONTENTS.txt" << 'CONTENTS_EOF'
BOOTABLE USB BUNDLE - FILE LISTING
===================================

Required files for bootable USB deployment:

1. ubuntu-24.04.1-desktop-amd64.iso
   Purpose: Bootable Ubuntu Live environment
   Usage: Flash this to USB drive using Rufus/Etcher

2. ollama-image.tar.gz
   Purpose: Ollama Docker image
   Usage: Auto-loaded by installer

3. open-webui-image.tar.gz
   Purpose: Open Web UI Docker image
   Usage: Auto-loaded by installer

4. ollama-models/
   Purpose: Pre-downloaded AI models
   Usage: Auto-loaded by installer

5. project/
   Purpose: RAG system configuration
   Contains:
   - docker-compose.prod.yml
   - setup-models.sh
   - start-prod.sh
   - README.md

6. scripts/
   Purpose: Installation scripts
   Contains:
   - install.sh (main installer)
   - RAG-System-Installer.desktop (desktop shortcut)

7. Documentation:
   - QUICKSTART.txt (quick start guide)
   - README-BOOTABLE.txt (detailed instructions)
   - BUNDLE-CONTENTS.txt (this file)

DEPLOYMENT STEPS:
1. Flash ISO to USB
2. Copy all other files/folders to USB
3. Boot from USB
4. Run scripts/install.sh
CONTENTS_EOF

# Calculate and display sizes
echo ""
echo "=========================================="
echo "Bootable USB Bundle Created Successfully!"
echo "=========================================="
echo ""
echo "Location: $BUNDLE_DIR/"
echo ""
echo "Contents:"
du -sh "$BUNDLE_DIR"/* 2>/dev/null | sort -h
echo ""
echo "Total bundle size:"
du -sh "$BUNDLE_DIR"
echo ""
echo "=========================================="
echo "NEXT STEPS:"
echo "=========================================="
echo ""
echo "1. FLASH ISO TO USB:"
echo "   - Use Rufus (Windows) or Etcher (Mac/Linux)"
echo "   - Flash: $BUNDLE_DIR/ubuntu-24.04.1-desktop-amd64.iso"
echo "   - To a 32GB+ USB drive"
echo ""
echo "2. COPY FILES TO USB:"
echo "   After flashing, copy these to the USB:"
echo "   - ollama-image.tar.gz"
echo "   - open-webui-image.tar.gz"
echo "   - ollama-models/"
echo "   - project/"
echo "   - scripts/"
echo "   - *.txt files"
echo ""
echo "3. BOOT FROM USB:"
echo "   - Insert USB into target computer"
echo "   - Boot from USB (press F12/F9/Esc during startup)"
echo "   - Select 'Try Ubuntu'"
echo "   - Run scripts/install.sh from the USB"
echo ""
echo "See $BUNDLE_DIR/QUICKSTART.txt for detailed instructions!"
echo ""
