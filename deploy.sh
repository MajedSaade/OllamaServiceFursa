#!/bin/bash
set -e

# Print execution steps
set -x

echo "Starting Ollama Mistral deployment..."

# Function to install Python packages using pip directly
install_with_pip_directly() {
    echo "Installing packages directly with pip --break-system-packages flag..."
    python3 -m pip install --break-system-packages -r requirements.txt
}

# Try to set up Python environment
echo "Setting up Python environment..."
if ! command -v python3 &> /dev/null; then
    echo "Python3 not found, installing..."
    sudo apt-get update
    sudo apt-get install -y python3
fi

# Try multiple approaches for Python dependencies
if command -v apt-get &> /dev/null; then
    # Try installing packages with apt
    echo "Installing Python packages via apt..."
    sudo apt-get update
    if ! sudo apt-get install -y python3-requests python3-yaml; then
        echo "Apt installation failed, trying pip with break-system-packages flag"
        install_with_pip_directly
    fi
else
    # If apt is not available, use pip directly
    install_with_pip_directly
fi

# Install Ollama if not already installed
if ! command -v ollama &> /dev/null; then
    echo "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    # Wait for the service to start
    sleep 5
fi

# Copy the systemd service file
sudo cp ollama.service /etc/systemd/system/

# Reload systemd daemon and restart the service
sudo systemctl daemon-reload
sudo systemctl restart ollama.service
sudo systemctl enable ollama.service

# Wait for Ollama to be fully up
sleep 10

# Pull the Mistral model if not already pulled
if ! ollama list | grep -q mistral; then
    echo "Pulling Mistral model..."
    ollama pull mistral
fi

# Run the Python setup script
python3 setup_ollama.py

# Check if the service is active
if ! systemctl is-active --quiet ollama.service; then
    echo "❌ ollama.service is not running."
    sudo systemctl status ollama.service --no-pager
    exit 1
else
    echo "✅ Ollama service is running successfully with Mistral model!"
    ollama list
fi

# Run a quick model test
echo -e "\nTesting Mistral model..."
curl -X POST http://localhost:11434/api/generate -d '{
  "model": "mistral",
  "prompt": "Hello, please introduce yourself briefly.",
  "stream": false
}'
echo -e "\n"

echo "Deployment completed successfully!" 