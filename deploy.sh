#!/bin/bash
set -e

echo "Starting Ollama with Mistral deployment..."

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

# Allow Ollama port through firewall if UFW is active
echo "Configuring firewall to allow Ollama access..."
if command -v ufw &> /dev/null && sudo ufw status | grep -q "active"; then
    sudo ufw allow 11434/tcp
    echo "Firewall rule added for Ollama (port 11434)"
fi

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

# Check if Mistral model is already pulled
echo "Checking if Mistral model is already available..."
if ollama list | grep -q "mistral"; then
    echo "Mistral model is already pulled and available."
else
    # Pull the Mistral model
    echo "Pulling Mistral model..."
    ollama pull mistral
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

echo "✅ Ollama with Mistral deployed successfully!"
echo "The Ollama API is available at http://$(hostname -I | awk '{print $1}'):11434/api" 