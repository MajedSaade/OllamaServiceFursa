#!/usr/bin/env python3
"""
Ollama with Mistral monitoring application
"""
import os
import time
import requests
import json
import logging
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

OLLAMA_API_URL = "http://localhost:11434/api"
CHECK_INTERVAL = 60  # seconds

def check_ollama_status():
    """Check if Ollama service is running and Mistral model is available"""
    try:
        # Check Ollama server status
        response = requests.get(f"{OLLAMA_API_URL}/tags")
        if response.status_code != 200:
            logger.error(f"Ollama service not responding properly: {response.status_code}")
            return False
        
        # Check if Mistral model is available
        models = response.json().get('models', [])
        mistral_available = any(model.get('name', '') == 'mistral' for model in models)
        
        if not mistral_available:
            logger.warning("Mistral model not found in available models")
            return False
            
        logger.info("Ollama service is running with Mistral model available")
        return True
    except Exception as e:
        logger.error(f"Error checking Ollama status: {e}")
        return False

def test_mistral_response():
    """Test a simple Mistral model response"""
    try:
        payload = {
            "model": "mistral",
            "prompt": "What is the capital of France?",
            "stream": False
        }
        
        response = requests.post(f"{OLLAMA_API_URL}/generate", json=payload)
        if response.status_code == 200:
            result = response.json()
            logger.info(f"Mistral test response successful: {result.get('response', '')[:50]}...")
            return True
        else:
            logger.error(f"Failed to get response from Mistral: {response.status_code}")
            return False
    except Exception as e:
        logger.error(f"Error testing Mistral response: {e}")
        return False

def main():
    logger.info("Starting Ollama with Mistral monitoring service")
    
    while True:
        if check_ollama_status():
            # Test the model every hour with a simple query
            test_mistral_response()
        else:
            logger.warning("Ollama service or Mistral model not available, will retry...")
        
        # Wait before next check
        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    main() 