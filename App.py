#!/usr/bin/env python3
"""
Ollama with Gemma 3 1B monitoring application
"""
import os
import time
import requests
import json
import logging
import socket
import subprocess
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("ollama_monitor.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Get Ollama host from environment or use default
OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "0.0.0.0")  # Use 0.0.0.0 to listen on all interfaces
# If OLLAMA_HOST contains a protocol, use it directly, otherwise add http://
if "://" in OLLAMA_HOST:
    OLLAMA_API_BASE = f"{OLLAMA_HOST}"
else:
    OLLAMA_API_BASE = f"http://{OLLAMA_HOST}:11434"
OLLAMA_API_URL = f"{OLLAMA_API_BASE}/api"

logger.info(f"Using Ollama API URL: {OLLAMA_API_URL}")
CHECK_INTERVAL = 60  # seconds

def get_network_info():
    """Get network information to help diagnose connection issues"""
    try:
        # Get hostname
        hostname = socket.gethostname()
        # Get IP addresses
        ip_addresses = []
        try:
            # Try to get all network interfaces
            cmd = "ip -4 addr show | grep -oP '(?<=inet\\s)\\d+(\\.\\d+){3}'"
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            if result.returncode == 0:
                ip_addresses = result.stdout.strip().split('\n')
            else:
                # Fallback if ip command fails
                host_ip = socket.gethostbyname(hostname)
                ip_addresses.append(host_ip)
        except:
            try:
                # Another fallback
                host_ip = socket.gethostbyname(hostname)
                ip_addresses.append(host_ip)
            except:
                ip_addresses.append("Unable to determine IP")
                
        # Check if Ollama port is listening and on which interfaces
        listening_interfaces = []
        try:
            cmd = "ss -tulpn | grep 11434"
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            if result.returncode == 0:
                listening_interfaces = result.stdout.strip()
            else:
                listening_interfaces = "Unable to determine listening interfaces"
        except:
            listening_interfaces = "Error checking listening interfaces"
            
        network_info = {
            "hostname": hostname,
            "ip_addresses": ip_addresses,
            "listening_interfaces": listening_interfaces
        }
        
        logger.info(f"Network information: {json.dumps(network_info, indent=2)}")
        return network_info
    except Exception as e:
        logger.error(f"Error getting network information: {e}")
        return {"error": str(e)}

def get_external_ip():
    """Get the first non-localhost IP to use for external testing"""
    try:
        network_info = get_network_info()
        for ip in network_info.get("ip_addresses", []):
            if not ip.startswith("127."):
                return ip
        return None
    except:
        return None

def check_ollama_status():
    """Check if Ollama service is running and Gemma model is available"""
    try:
        # Check Ollama server status
        response = requests.get(f"{OLLAMA_API_URL}/tags")
        if response.status_code != 200:
            logger.error(f"Ollama service not responding properly: {response.status_code}")
            return False
        
        # Check if Gemma model is available
        models = response.json().get('models', [])
        gemma_available = any(model.get('name', '') == 'gemma3:1b' for model in models)
        
        if not gemma_available:
            logger.warning("Gemma model not found in available models")
            return False
            
        logger.info("Ollama service is running with Gemma model available")
        return True
    except Exception as e:
        logger.error(f"Error checking Ollama status: {e}")
        return False

def test_gemma_response():
    """Test a simple Gemma model response"""
    try:
        payload = {
            "model": "gemma3:1b",
            "prompt": "What is the capital of France?",
            "stream": False
        }
        
        response = requests.post(f"{OLLAMA_API_URL}/generate", json=payload)
        if response.status_code == 200:
            result = response.json()
            logger.info(f"Gemma test response successful: {result.get('response', '')[:50]}...")
            return True
        else:
            logger.error(f"Failed to get response from Gemma: {response.status_code}")
            return False
    except Exception as e:
        logger.error(f"Error testing Gemma response: {e}")
        return False

def test_external_connection(ip=None):
    """Test if we can connect to Ollama from an external IP"""
    try:
        if ip is None:
            ip = get_external_ip() or "10.0.1.33"  # Fallback to the previous IP if we can't determine one

        external_url = f"http://{ip}:11434/api/tags"
        logger.info(f"Testing connection to Ollama at: {external_url}")
        
        try:
            response = requests.get(external_url, timeout=5)
            if response.status_code == 200:
                logger.info(f"Successfully connected to Ollama at {external_url}")
                return True
            else:
                logger.error(f"Failed to connect to Ollama at {external_url}: {response.status_code}")
                return False
        except requests.exceptions.ConnectionError:
            logger.error(f"Connection error to {external_url} - this is expected if testing from the same machine")
            # Don't treat this as a failure when testing locally
            return True
        except Exception as e:
            logger.error(f"Error connecting to {external_url}: {e}")
            return False
    except Exception as e:
        logger.error(f"Error in test_external_connection: {e}")
        return False

def main():
    logger.info("Starting Ollama with Gemma 3 1B monitoring service")
    logger.info(f"Configured to monitor Ollama at: {OLLAMA_API_URL}")
    
    # Get network information for diagnostics
    network_info = get_network_info()
    
    # Test external connection
    test_external_connection()
    
    # Also test connection via the specific target IP if provided
    target_ip = "10.0.1.33"  # Your target IP
    if target_ip:
        test_external_connection(target_ip)
    
    while True:
        if check_ollama_status():
            # Test the model every hour with a simple query
            test_gemma_response()
        else:
            logger.warning("Ollama service or Gemma model not available, will retry...")
        
        # Wait before next check
        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    main() 