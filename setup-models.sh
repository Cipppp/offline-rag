#!/bin/bash

echo "======================================"
echo "Setting up Ollama models..."
echo "======================================"

echo "Waiting for Ollama service to start..."
until curl -s http://localhost:11434/api/tags > /dev/null 2>&1; do
    sleep 2
    echo "Still waiting for Ollama..."
done

echo "✓ Ollama is ready!"
echo ""

# Pull required models
echo "Pulling llama3:8b-instruct-q6_K model (this may take a while)..."
docker exec ollama ollama pull llama3:8b-instruct-q6_K

echo ""
echo "Pulling nomic-embed-text model..."
docker exec ollama ollama pull nomic-embed-text

echo ""
echo "======================================"
echo "✓ All models installed successfully!"
echo "======================================"
echo ""
echo "Available models:"
docker exec ollama ollama list
