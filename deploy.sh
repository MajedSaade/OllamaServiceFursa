#!/bin/bash
set -e

echo "Starting Ollama with Gemma deployment..."

# Check if Ollama is already installed
if ! command -v ollama &> /dev/null; then
    echo "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    echo "Ollama installed successfully!"
else
    echo "Ollama is already installed."
fi

# Install required packages for Python virtual environment
echo "Installing Python prerequisites..."
sudo apt-get update
sudo apt-get install -y python3-full python3-venv

# Create a virtual environment
echo "Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install dependencies in the virtual environment
echo "Installing Python dependencies..."
pip install -r requirements.txt

# Copy the systemd service file
echo "Setting up Ollama service..."
sudo cp ollama.service /etc/systemd/system/

# Reload systemd and restart the service
sudo systemctl daemon-reload
sudo systemctl restart ollama.service
sudo systemctl enable ollama.service

# Wait for Ollama service to be fully started
echo "Waiting for Ollama service to start..."
sleep 5

# Make sure Ollama directories exist and are properly initialized
echo "Initializing Ollama directories..."
mkdir -p ~/.ollama
if [ ! -f ~/.ollama/id_ed25519 ]; then
    echo "Generating Ollama SSH key..."
    ssh-keygen -t ed25519 -f ~/.ollama/id_ed25519 -N ""
fi

# Restart Ollama to pick up the new key
sudo systemctl restart ollama.service
sleep 5

# Check if Gemma 3 1B model is already pulled
echo "Checking if Gemma 3 1B model is already available..."
if ollama list | grep -q "gemma3:1b"; then
    echo "Gemma 3 1B model is already pulled and available."
else
    # Pull the Gemma 3 1B model (815MB)
    echo "Pulling Gemma 3 1B model (815MB)..."
    ollama pull gemma3:1b
fi

# Run our monitoring script with the virtual environment
echo "Starting the monitoring Python script..."
nohup venv/bin/python app.py > app.log 2>&1 &

# Check if the service is active
if ! systemctl is-active --quiet ollama.service; then
  echo "❌ ollama.service is not running."
  sudo systemctl status ollama.service --no-pager
  exit 1
fi

echo "✅ Ollama with Gemma-3-1b deployed successfully!" 