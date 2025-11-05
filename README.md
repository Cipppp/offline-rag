# Offline RAG System with Open Web UI

A complete offline Retrieval Augmented Generation (RAG) system with a modern chat interface.

## Features

- **Modern UI**: Open Web UI - professional chat interface
- **Document Analysis**: Upload PDFs and ask questions
- **Completely Offline**: No internet connection required
- **Easy Deployment**: Run from USB stick or install to system
- **Pre-configured Models**: llama3:8b-instruct-q6_K and nomic-embed-text included

## Requirements

- Ubuntu 24.04 (or bootable USB)
- Docker & Docker Compose
- 8GB+ RAM recommended
- 20GB disk space (for models)
- 32GB+ USB drive (for bootable deployment)

## Quick Start

### Option 1: Standard Installation

```bash
# Start the system
./start-prod.sh

# Download models (first time only)
./setup-models.sh

# Open browser
http://localhost:3000
```

### Option 2: Bootable USB Deployment

```bash
# Create bootable USB bundle
./create-bootable-usb.sh

# Follow instructions to create bootable USB
# Boot from USB and run installer
```

### Option 3: USB Bundle (Pre-installed Ubuntu)

```bash
# Create USB bundle
./export-bundle.sh

# Copy to USB and run on Ubuntu system
./import-and-run.sh
```

## How to Use

1. Open http://localhost:3000 in your browser
2. Select the **llama3:8b-instruct-q6_K** model from the dropdown
3. Upload PDFs using the document manager icon (top right)
4. Start chatting and asking questions about your documents!

## Tech Stack

- **Open Web UI** - Modern chat interface with built-in RAG support
- **Ollama** - LLM runtime
- **llama3:8b-instruct-q6_K** - Language model (4.7GB)
- **nomic-embed-text** - Embeddings for RAG (274MB)

## Useful Commands

```bash
# Start
./start-prod.sh

# Stop
docker compose -f docker-compose.prod.yml down

# View logs
docker compose -f docker-compose.prod.yml logs -f

# Check status
docker ps
```

## Directory Structure

```
.
-- app/
    -- main.py              # FastAPI application
    -- requirements.txt     # Python dependencies
    -- Dockerfile            # App container config
    -- static/
        -- index.html      # Web UI
-- docker-compose.prod.yml  # Production setup
-- start-prod.sh           # Startup script
-- setup-models.sh         # Model download script
```

## Troubleshooting

**Container won't start:**
```bash
docker compose -f docker-compose.prod.yml logs
```

**Models not found:**
```bash
./setup-models.sh
```

**Port already in use:**
Edit `docker-compose.prod.yml` and change `3000:8080` to `9000:8080`

## Deployment Options

### 1. Export Bundle (Installed Ubuntu)
Creates a portable bundle to transfer to Ubuntu systems:
```bash
./export-bundle.sh
```
Output: `usb-bundle/` folder (~12GB) with everything needed

### 2. Bootable USB (No Ubuntu Required)
Creates a complete bootable system:
```bash
./create-bootable-usb.sh
```
This creates:
- Bootable Ubuntu Live environment
- All Docker images and models pre-packaged
- Auto-installer script

**Creating the bootable USB:**
1. Use Rufus (Windows) or Etcher (Mac/Linux)
2. Flash `usb-bundle/ubuntu-24.04.1-desktop-amd64.iso` to USB
3. After flashing, copy remaining folders to the USB
4. Boot from USB and run the installer

**Booting from USB:**
1. Insert USB and boot from it
2. Select "Try Ubuntu" (Live session)
3. Wait for desktop to load
4. Open terminal and navigate to USB mount
5. Run: `./scripts/install.sh`
6. Open browser to http://localhost:3000

**Note**: Live USB sessions don't persist data after reboot. For permanent installation, install Ubuntu to the hard drive first.

## Architecture
```
┌─────────────────────────────────────────┐
│         Open Web UI (Port 3000)         │
│  - Chat Interface                       │
│  - Document Upload & Management         │
│  - Built-in RAG Engine                  │
│  - Vector Database (ChromaDB)           │
└───────────────┬─────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────┐
│          Ollama (Port 11434)            │
│  - llama3:8b-instruct-q6_K (Q&A)            │
│  - nomic-embed-text (Embeddings)       │
└─────────────────────────────────────────┘
```

## Open Web UI Features

- **Document Management**: Upload and organize multiple PDFs
- **RAG Support**: Built-in retrieval augmented generation
- **Chat History**: Save and revisit conversations
- **Model Selection**: Easy switching between models
- **Markdown Support**: Rich text formatting in responses
- **No Authentication**: Configured for offline single-user use

## Bundle Contents

**export-bundle.sh output:**
- `ollama-image.tar.gz` - Ollama Docker image
- `open-webui-image.tar.gz` - Open Web UI image
- `ollama-models/` - Pre-downloaded AI models
- `project/` - RAG system source code
- `import-and-run.sh` - Installation script

**create-bootable-usb.sh output:**
- Everything from export-bundle.sh, plus:
- `ubuntu-24.04.1-desktop-amd64.iso` - Ubuntu Live ISO
- `scripts/install.sh` - Automated installer
- `autostart/` - Auto-launch configuration
- `README.txt` and `QUICKSTART.txt` - Instructions

## System Requirements

**Minimum:**
- CPU: 4 cores
- RAM: 8GB
- Storage: 25GB free

**Recommended:**
- CPU: 6+ cores
- RAM: 16GB
- Storage: 50GB free
- SSD for better performance

**USB Requirements:**
- Standard bundle: 16GB+ USB drive
- Bootable bundle: 32GB+ USB drive

## Security Notes

- Authentication disabled by default (offline single-user)
- No external network connections required
- All data stays local
- To enable auth: Set `WEBUI_AUTH=true` in docker-compose.prod.yml

