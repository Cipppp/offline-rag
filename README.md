# Offline RAG System with Open Web UI

Complete offline AI chat system with document Q&A capabilities.

## Prerequisites

- Ubuntu 24.04
- Docker & Docker Compose
- 8GB+ RAM
- 50GB+ disk space

## Installation

```bash
# Clone repository
git clone https://github.com/Cipppp/offline-rag.git
cd offline-rag

# Start system
./start-prod.sh

# Download models (first time only)
./setup-models.sh

# Access UI
http://localhost:3000
```

## Usage

1. Select **llama3:8b-instruct-q6_K** model
2. Upload PDFs via document icon (top right)
3. Ask questions about your documents

## Create Bootable USB

**On Ubuntu machine:**

```bash
# Install prerequisites and create bundle
./create-bootable-usb.sh

# Output: usb-bundle/ (~14GB)
```

**Create bootable USB:**

1. Flash ISO to USB:
   - Use Rufus (Windows) or Etcher (Mac/Linux)
   - Select: `usb-bundle/ubuntu-24.04.1-desktop-amd64.iso`
   - Flash to 32GB+ USB drive

2. Copy remaining files to USB:
   - ollama-image.tar.gz
   - open-webui-image.tar.gz
   - ollama-models/
   - project/
   - scripts/
   - *.txt files

**Use bootable USB:**

1. Boot computer from USB (F12/F9/Esc)
2. Select "Try Ubuntu"
3. Run `scripts/install.sh`
4. Access `http://localhost:3000`

## Commands

```bash
# Start
./start-prod.sh

# Stop
docker compose -f docker-compose.prod.yml down

# View logs
docker compose -f docker-compose.prod.yml logs -f

# Check status
docker ps

# List models
docker exec ollama ollama list
```

## Tech Stack

- **UI**: Open Web UI
- **LLM Runtime**: Ollama
- **Language Model**: llama3:8b-instruct-q6_K (6.6GB)
- **Embeddings**: nomic-embed-text (274MB)
- **Vector DB**: ChromaDB (embedded)

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
│  - llama3:8b-instruct-q6_K (Q&A)       │
│  - nomic-embed-text (Embeddings)       │
└─────────────────────────────────────────┘
```

## System Requirements

**Minimum:**

- 4 CPU cores
- 8GB RAM
- 50GB storage

**Recommended:**

- 6+ CPU cores
- 16GB RAM
- 100GB storage
- SSD

## Troubleshooting

**Containers won't start:**

```bash
docker compose -f docker-compose.prod.yml logs
```

**Models not found:**

```bash
./setup-models.sh
```

**Port already in use:**

Edit `docker-compose.prod.yml`, change `3000:8080` to `9000:8080`

**Out of disk space:**

```bash
# Clean Docker
docker system prune -af

# Remove ISO from bundle (saves 6GB)
rm usb-bundle/ubuntu-24.04.1-desktop-amd64.iso
```

## Security

- No authentication by default (offline single-user)
- No external network connections
- All data stays local
- To enable auth: Set `WEBUI_AUTH=true` in docker-compose.prod.yml
