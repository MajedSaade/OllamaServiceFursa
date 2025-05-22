#!/usr/bin/env python3
import os
import time
import requests
import subprocess
import json
import yaml
import sys
from pathlib import Path

def check_ollama_running():
    """Check if Ollama server is running and accessible"""
    try:
        response = requests.get("http://localhost:11434/api/tags")
        if response.status_code == 200:
            return True
        else:
            print(f"Ollama server returned status code: {response.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        print("Ollama server is not accessible")
        return False

def get_model_list():
    """Get list of available models in Ollama"""
    try:
        response = requests.get("http://localhost:11434/api/tags")
        if response.status_code == 200:
            return response.json()
        return None
    except Exception as e:
        print(f"Error getting model list: {e}")
        return None

def check_mistral_model():
    """Check if Mistral model is available"""
    models = get_model_list()
    if models and 'models' in models:
        return any(model['name'] == 'mistral' for model in models['models'])
    return False

def generate_config():
    """Generate configuration file for Ollama"""
    config = {
        'server': {
            'host': '0.0.0.0',
            'port': 11434
        },
        'models': {
            'default': 'mistral'
        },
        'deployment': {
            'timestamp': time.time(),
            'version': '1.0.0'
        }
    }
    
    with open('ollama_config.yaml', 'w') as f:
        yaml.dump(config, f, default_flow_style=False)
    
    print("Generated configuration file: ollama_config.yaml")

def test_model():
    """Test the Mistral model with a simple prompt"""
    try:
        print("Testing Mistral model with a simple prompt...")
        response = requests.post(
            "http://localhost:11434/api/generate",
            json={"model": "mistral", "prompt": "Say hello world", "stream": False}
        )
        
        if response.status_code == 200:
            result = response.json()
            print(f"Model response: {result.get('response', 'No response')}")
            return True
        else:
            print(f"Failed to test model: {response.status_code}")
            return False
    except Exception as e:
        print(f"Error testing model: {e}")
        return False

def setup_ollama_firewall():
    """Setup firewall rules for Ollama if firewall is active"""
    try:
        # Check if ufw is installed and active
        ufw_status = subprocess.run(["which", "ufw"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if ufw_status.returncode == 0:
            print("Checking firewall status...")
            status = subprocess.run(["sudo", "ufw", "status"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            if b"Status: active" in status.stdout:
                print("Firewall is active, adding rule for Ollama port 11434...")
                subprocess.run(["sudo", "ufw", "allow", "11434/tcp"], check=True)
                print("✅ Firewall rule added for Ollama")
    except Exception as e:
        print(f"Note: Could not configure firewall: {e}")
        print("You may need to manually open port 11434 if your firewall is active")

def main():
    print("Setting up Ollama with Mistral...")
    
    # Wait for Ollama server to be fully up (if just started)
    retries = 10
    while retries > 0 and not check_ollama_running():
        print(f"Waiting for Ollama server to start... ({retries} retries left)")
        time.sleep(5)
        retries -= 1
    
    if not check_ollama_running():
        print("ERROR: Ollama server is not running. Exiting.")
        sys.exit(1)
    
    # Check if Mistral model is available
    if not check_mistral_model():
        print("Mistral model is not available. Trying to pull it...")
        subprocess.run(["ollama", "pull", "mistral"], check=True)
    
    # Generate configuration
    generate_config()
    
    # Configure firewall if needed
    setup_ollama_firewall()
    
    # Test the model
    if test_model():
        print("✅ Mistral model is working correctly!")
    else:
        print("⚠️ Could not verify Mistral model functionality.")
    
    print("Ollama setup completed!")

if __name__ == "__main__":
    main() 