#!/bin/bash

# Export script - creates USB bundle for offline deployment with Open Web UI

set -e

BUNDLE_DIR="./usb-bundle"
echo "======================================"
echo "Creating USB Bundle with Open Web UI"
echo "======================================"
echo ""

# Create bundle directory
echo "Creating bundle directory..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"

# Save Docker images
echo ""
echo "Saving Docker images (this takes a while)..."
echo "  - Saving Ollama image..."
docker pull ollama/ollama:latest
docker save ollama/ollama:latest | gzip > "$BUNDLE_DIR/ollama-image.tar.gz"

echo "  - Saving Open Web UI image..."
docker pull ghcr.io/open-webui/open-webui:main
docker save ghcr.io/open-webui/open-webui:main | gzip > "$BUNDLE_DIR/open-webui-image.tar.gz"

# Export Ollama models
echo ""
echo "Exporting Ollama models..."
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
echo "Copying project files..."
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

# Create import script for Ubuntu
cat > "$BUNDLE_DIR/import-and-run.sh" << 'EOF'
#!/bin/bash

# Import script for Ubuntu 24.04

set -e

echo "======================================"
echo "Installing Offline RAG System"
echo "======================================"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    sudo apt-get update
    sudo apt-get install -y docker.io docker-compose
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    echo "Docker installed. You may need to log out and back in."
fi

# Load Docker images
echo ""
echo "Loading Docker images..."
echo "  - Loading Ollama..."
docker load < ollama-image.tar.gz

echo "  - Loading Open Web UI..."
docker load < open-webui-image.tar.gz

# Setup Ollama models
echo ""
echo "Setting up Ollama models..."
cd project

# Start ollama temporarily to load models
docker compose -f docker-compose.prod.yml up -d ollama
sleep 5

# Copy models
docker cp ../ollama-models/. ollama:/root/.ollama/

# Restart to pick up models
docker compose -f docker-compose.prod.yml restart ollama
sleep 3

# Start the full system
echo ""
echo "Starting RAG System..."
docker compose -f docker-compose.prod.yml up -d

echo ""
echo "======================================"
echo "Installation Complete!"
echo "======================================"
echo ""
echo "Open Web UI is running at:"
echo "  http://localhost:3000"
echo ""
echo "To stop:  cd project && docker compose -f docker-compose.prod.yml down"
echo "To start: cd project && docker compose -f docker-compose.prod.yml up -d"
echo ""
EOF

chmod +x "$BUNDLE_DIR/import-and-run.sh"

# Create README for bundle
cat > "$BUNDLE_DIR/README.txt" << 'EOF'
OFFLINE RAG SYSTEM WITH OPEN WEB UI - USB BUNDLE
=================================================

This bundle contains everything needed to run the RAG system offline on Ubuntu 24.04.

INSTALLATION:
1. Copy this entire folder to the Ubuntu machine
2. Open terminal in this folder
3. Run: chmod +x import-and-run.sh
4. Run: ./import-and-run.sh
5. Wait for installation to complete
6. Open browser to http://localhost:3000

REQUIREMENTS:
- Ubuntu 24.04
- 8GB+ RAM
- 20GB disk space
- Docker (will be installed if missing)

CONTENTS:
- ollama-image.tar.gz       (Ollama Docker image)
- open-webui-image.tar.gz   (Open Web UI Docker image)
- ollama-models/            (Pre-downloaded AI models)
- project/                  (Source code and configs)
- import-and-run.sh         (Installation script)

FEATURES:
- Modern chat interface with Open Web UI
- Document upload and RAG capabilities
- Completely offline - no internet required
- Pre-configured with llama3:8b-instruct-q6_K model

SIZE:
- Total bundle: ~10-12GB
- Requires USB drive with 16GB+ capacity

USAGE:
1. Open http://localhost:3000
2. Upload PDF documents using the document manager
3. Start chatting and asking questions!

SUPPORT:
See project/README.md for detailed documentation.
EOF

# Calculate sizes
echo ""
echo "======================================"
echo "Bundle Created Successfully!"
echo "======================================"
echo ""
echo "Location: $BUNDLE_DIR/"
echo ""
echo "Contents:"
du -sh "$BUNDLE_DIR"/*
echo ""
echo "Total size:"
du -sh "$BUNDLE_DIR"
echo ""
echo "Next steps:"
echo "1. Copy $BUNDLE_DIR to USB drive"
echo "2. Transfer to Ubuntu machine"
echo "3. Run ./import-and-run.sh on Ubuntu"
echo ""
