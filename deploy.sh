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

# Configure Ollama to listen on all interfaces
echo "Configuring Ollama to listen on all interfaces..."
# Set environment variable globally
echo 'OLLAMA_HOST=0.0.0.0' | sudo tee /etc/systemd/system.conf.d/ollama.conf
echo 'OLLAMA_HOST=0.0.0.0' | sudo tee /etc/environment.d/ollama.conf
export OLLAMA_HOST=0.0.0.0

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

# Create or update the systemd service file
echo "Setting up Ollama service with proper network configuration..."
cat > ollama.service << EOF
[Unit]
Description=Ollama Service
After=network.target

[Service]
Type=simple
User=root
Environment="OLLAMA_HOST=0.0.0.0"
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=ollama

[Install]
WantedBy=multi-user.target
EOF

# Copy the systemd service file
sudo cp ollama.service /etc/systemd/system/

# Make sure directory exists for systemd config
sudo mkdir -p /etc/systemd/system.conf.d/

# Create a systemd drop-in to set the environment variable
echo "Creating systemd environment configuration..."
sudo mkdir -p /etc/systemd/system/ollama.service.d/
cat > override.conf << EOF
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
EOF
sudo cp override.conf /etc/systemd/system/ollama.service.d/

# Reload systemd and restart the service
sudo systemctl daemon-reload
sudo systemctl restart ollama.service
sudo systemctl enable ollama.service

# Wait for Ollama service to be fully started
echo "Waiting for Ollama service to start..."
sleep 5

# Verify Ollama is listening on all interfaces
echo "Verifying Ollama network configuration..."
if ss -tulpn | grep -q ".*:11434"; then
    echo "✅ Ollama is properly configured to listen on all interfaces."
else
    echo "❌ Ollama is not listening on all interfaces. Attempting to fix..."
    sudo systemctl stop ollama.service
    OLLAMA_HOST=0.0.0.0 sudo -E /usr/local/bin/ollama serve &
    sleep 5
    if ss -tulpn | grep -q ".*:11434"; then
        echo "✅ Ollama is now properly configured to listen on all interfaces."
        
        # Kill the temporary process and start the service properly
        sudo pkill -f "ollama serve"
        sudo systemctl start ollama.service
    else
        echo "❌ Failed to configure Ollama to listen on all interfaces."
    fi
fi

# Verify IP addresses and network configuration
echo "Network configuration:"
ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}'

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
export OLLAMA_HOST=0.0.0.0
nohup venv/bin/python App.py > app.log 2>&1 &

# Check if the service is active
if ! systemctl is-active --quiet ollama.service; then
  echo "❌ ollama.service is not running."
  sudo systemctl status ollama.service --no-pager
  exit 1
fi

echo "✅ Ollama with Gemma-3-1b deployed successfully!" 