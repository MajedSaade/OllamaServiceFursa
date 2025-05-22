#!/bin/bash
# Exit on any error with details
set -e

# Print execution steps
set -x

echo "Starting Ollama Llama 3.2 deployment..."

# Install Python dependencies if needed
if ! python3 -c "import requests, yaml" &>/dev/null; then
    echo "Installing Python dependencies..."
    sudo apt-get update
    sudo apt-get install -y python3-requests python3-yaml || \
    python3 -m pip install --break-system-packages requests pyyaml
fi

# Get the current user for the service file
CURRENT_USER=$(whoami)
echo "Current user: $CURRENT_USER"

# Update the service file with the current user
sed -i "s/User=ubuntu/User=$CURRENT_USER/g" ollama.service

# Install Ollama if not already installed
if ! command -v ollama &> /dev/null; then
    echo "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    sleep 5
fi

# Copy the systemd service file and restart service
sudo cp ollama.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl restart ollama.service
sudo systemctl enable ollama.service

# Wait for Ollama to be fully up
echo "Waiting for Ollama service to start..."
sleep 10

# Check if Ollama is running
if ! curl -s -f http://localhost:11434/api/tags &>/dev/null; then
    echo "Ollama service not responding. Starting manually..."
    sudo systemctl status ollama.service --no-pager || true
    nohup ollama serve > ollama.log 2>&1 &
    sleep 15
fi

# Check if we can connect to Ollama now
if curl -s -f http://localhost:11434/api/tags > /dev/null; then
    echo "✅ Ollama API is accessible!"
    
    # Check if Llama 3.2 is already downloaded
    if ollama list | grep -q "llama3"; then
        echo "✅ Llama 3.2 model already downloaded"
    else
        echo "Downloading Llama 3.2 model..."
        ollama pull llama3
    fi
    
    # Verify model is working
    echo -e "\nTesting Llama 3.2 model..."
    curl -X POST http://localhost:11434/api/generate -d '{
      "model": "llama3",
      "prompt": "Hello, please introduce yourself briefly.",
      "stream": false
    }'
    echo -e "\n"
    
    echo "Deployment completed successfully!"
else
    echo "❌ Cannot connect to Ollama API after multiple attempts."
    exit 1
fi 