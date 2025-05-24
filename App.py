#!/usr/bin/env python3
"""
Ollama with Gemma 3 1B monitoring application
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

"New instance"

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

def main():
    logger.info("Starting Ollama with Gemma 3 1B monitoring service")
    
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