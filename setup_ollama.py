#!/usr/bin/env python3
import os
import time
import requests
import subprocess
import json
import sys

def check_ollama_running():
    """Check if Ollama server is running and accessible"""
    try:
        response = requests.get("http://localhost:11434/api/tags")
        return response.status_code == 200
    except requests.exceptions.ConnectionError:
        print("Ollama server is not accessible")
        return False

def check_llama_model():
    """Check if Llama 3.2 3B model is available"""
    try:
        response = requests.get("http://localhost:11434/api/tags")
        if response.status_code == 200:
            models = response.json()
            if 'models' in models:
                return any(model['name'] == 'llama3:3b' for model in models['models'])
        return False
    except Exception as e:
        print(f"Error checking model: {e}")
        return False

def setup_ollama_firewall():
    """Setup firewall rules for Ollama if needed"""
    try:
        # Check if ufw is installed and active
        ufw_status = subprocess.run(["which", "ufw"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if ufw_status.returncode == 0:
            status = subprocess.run(["sudo", "ufw", "status"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            if b"Status: active" in status.stdout:
                print("Firewall is active, adding rule for Ollama port 11434...")
                subprocess.run(["sudo", "ufw", "allow", "11434/tcp"], check=True)
                print("✅ Firewall rule added for Ollama")
    except Exception as e:
        print(f"Note: Could not configure firewall: {e}")

def main():
    print("Setting up Ollama with Llama 3.2 (3B)...")
    
    # Wait for Ollama server to be fully up
    if not check_ollama_running():
        print("ERROR: Ollama server is not running.")
        sys.exit(1)
    
    # Configure firewall if needed
    setup_ollama_firewall()
    
    # Verify Llama model
    if check_llama_model():
        print("✅ Llama 3.2 (3B) model is ready!")
    else:
        print("Llama 3.2 (3B) model isn't available. Make sure to run 'ollama pull llama3:3b'")
    
    print("Ollama setup completed!")

if __name__ == "__main__":
    main() 