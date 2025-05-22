#!/bin/bash
# Exit on any error with details
set -e

# Print execution steps
set -x

echo "Starting Ollama Gemma 3 1B deployment..."

# Check disk space and clean up if needed
echo "Checking disk space..."
AVAILABLE_SPACE=$(df -h / | awk 'NR==2 {print $4}')
USAGE_PERCENT=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')

echo "Available space: $AVAILABLE_SPACE, Usage: $USAGE_PERCENT%"

if [ "$USAGE_PERCENT" -gt 80 ]; then
    echo "Disk space critical at $USAGE_PERCENT%. Cleaning up..."
    
    # Clean package cache
    sudo apt-get clean
    sudo apt-get autoclean
    sudo apt-get autoremove -y
    
    # Remove old logs
    sudo journalctl --vacuum-time=1d
    
    # Clean temp files
    sudo rm -rf /tmp/*
    
    # Remove old Ollama models if they exist (except gemma3:1b)
    if [ -d ~/.ollama/models ]; then
        echo "Selectively removing old Ollama models to free space (keeping gemma3:1b if present)..."
        # List all models
        if ollama list 2>/dev/null | grep -v "gemma3:1b" | grep -q ":"; then
            # Get models besides gemma3:1b
            other_models=$(ollama list 2>/dev/null | grep -v "gemma3:1b" | grep ":" | awk '{print $1}')
            for model in $other_models; do
                echo "Removing model: $model"
                ollama rm $model
            done
        fi
    fi
    
    # Show new disk space
    echo "Disk space after cleanup:"
    df -h /
fi

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

# Get the current user for the service file
CURRENT_USER=$(whoami)
echo "Current user: $CURRENT_USER"

# Update the service file with the current user
sed -i "s/User=ubuntu/User=$CURRENT_USER/g" ollama.service
cat ollama.service

# Install Ollama if not already installed
if ! command -v ollama &> /dev/null; then
    echo "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    # Wait for the service to start
    sleep 5
fi

# Kill any existing Ollama processes to ensure clean startup
echo "Stopping any existing Ollama processes..."
sudo pkill -f ollama || echo "No ollama processes running"

# Copy the systemd service file
sudo cp ollama.service /etc/systemd/system/

# Reload systemd daemon and restart the service
sudo systemctl daemon-reload
sudo systemctl stop ollama.service || echo "Service was not running"
sudo systemctl start ollama.service
sudo systemctl enable ollama.service

# Check service status and logs
echo "Checking Ollama service status..."
sudo systemctl status ollama.service --no-pager || true

echo "Checking Ollama service logs..."
sudo journalctl -u ollama.service --no-pager -n 30 || true

# Wait longer for Ollama to be fully up
echo "Waiting for Ollama service to be fully operational..."
sleep 30

# Check if Ollama is running via service status
if ! systemctl is-active --quiet ollama.service; then
    echo "⚠️ Ollama service is not showing as active. Trying manual start..."
    # Try running Ollama directly if service isn't working
    nohup ollama serve > ollama.log 2>&1 &
    sleep 10
fi

# Check disk space again before pulling model
AVAILABLE_SPACE_MB=$(df -BM / | awk 'NR==2 {print $4}' | sed 's/M//')
echo "Available space before pulling model: ${AVAILABLE_SPACE_MB}MB"

# Test Ollama connectivity
echo "Testing Ollama connectivity..."
if ! curl -s -f http://localhost:11434/api/tags > /dev/null; then
    echo "❌ Cannot connect to Ollama API. Showing logs:"
    cat ollama.log || echo "No log file found"
    echo "Trying alternative approach with direct server..."
    # Start Ollama serve in background and continue
    nohup ollama serve > ollama.log 2>&1 &
    sleep 20
fi

# Check if we can connect to Ollama now
if curl -s -f http://localhost:11434/api/tags > /dev/null; then
    echo "✅ Ollama API is now accessible!"
    
    # Check if model already exists before pulling
    if ollama list 2>/dev/null | grep -q "gemma3:1b"; then
        echo "✅ Gemma 3 1B model already exists, skipping download"
    else
        # Gemma 3 1B requires at least 2GB free space
        if [ "$AVAILABLE_SPACE_MB" -lt 2000 ]; then
            echo "❌ Not enough disk space to pull Gemma 3 1B model (${AVAILABLE_SPACE_MB}MB available)"
            echo "Please expand your disk or use a smaller model"
            exit 1
        fi
    
        # Pull the Gemma 3 1B model
        echo "Pulling Gemma 3 1B model..."
        ollama pull gemma3:1b
    fi

    # Check if the model was pulled successfully
    if ollama list | grep -q "gemma3:1b"; then
        echo "✅ Gemma 3 1B model pulled successfully!"
        
        # Run the Python setup script
        python3 setup_ollama.py

        # Run a quick model test
        echo -e "\nTesting Gemma 3 1B model..."
        curl -X POST http://localhost:11434/api/generate -d '{
          "model": "gemma3:1b",
          "prompt": "Hello, please introduce yourself briefly.",
          "stream": false
        }'
        echo -e "\n"
        
        echo "Deployment completed successfully!"
    else
        echo "❌ Failed to pull Gemma 3 1B model."
        exit 1
    fi
else
    echo "❌ Cannot connect to Ollama API after multiple attempts."
    exit 1
fi 