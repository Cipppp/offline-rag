#!/bin/bash

echo "======================================"
echo "Starting RAG System (Production Mode)"
echo "======================================"
echo ""

if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker first."
    exit 1
fi

echo "Starting Ollama and Open Web UI containers..."
docker compose -f docker-compose.prod.yml up -d

echo ""
echo "Waiting for services to be ready..."
sleep 10


if docker ps | grep -q ollama && docker ps | grep -q open-webui; then
    echo ""
    echo "======================================"
    echo "✓ RAG System is running!"
    echo "======================================"
    echo ""
    echo "Services:"
    echo "  • Ollama:       http://localhost:11434"
    echo "  • Open Web UI:  http://localhost:3000"
    echo ""
    echo "Next steps:"
    echo "  1. Run './setup-models.sh' to download models (first time only)"
    echo "  2. Open http://localhost:3000 in your browser"
    echo "  3. Upload documents via the UI and start chatting!"
    echo ""
    echo "To stop: docker compose -f docker-compose.prod.yml down"
    echo "To view logs: docker compose -f docker-compose.prod.yml logs -f"
else
    echo ""
    echo "⚠ Warning: Some containers may not have started properly."
    echo "Check logs with: docker compose -f docker-compose.prod.yml logs"
fi
