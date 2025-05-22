#!/usr/bin/env python3
import requests
import json
import argparse
import sys
from datetime import datetime

def check_ollama_status(host="localhost", port=11434):
    """Check the status of the Ollama service and Llama 3.2 model"""
    base_url = f"http://{host}:{port}"
    
    try:
        print(f"Checking Ollama service at {base_url}...")
        
        # Check API health
        response = requests.get(f"{base_url}/api/tags")
        if response.status_code != 200:
            print(f"❌ Ollama API returned status code: {response.status_code}")
            return False
            
        models_data = response.json()
        
        # Print models information
        print(f"✅ Ollama service is running")
        print("\nAvailable models:")
        
        if 'models' in models_data and models_data['models']:
            for model in models_data['models']:
                print(f" - {model['name']} ({model.get('size', 'unknown size')})")
            
            # Check if Llama 3.2 is available
            if any(model['name'] == 'llama3' for model in models_data['models']):
                print("\n✅ Llama 3.2 model is available")
                
                # Test the model
                print("\nTesting Llama 3.2 model with a simple prompt...")
                test_response = requests.post(
                    f"{base_url}/api/generate",
                    json={"model": "llama3", "prompt": "What is your name?", "stream": False}
                )
                
                if test_response.status_code == 200:
                    result = test_response.json()
                    print(f"Model response: {result.get('response', 'No response')}")
                    print("\n✅ Llama 3.2 model is working correctly!")
                else:
                    print(f"\n❌ Failed to test model: {test_response.status_code}")
            else:
                print("\n❌ Llama 3.2 model is not available")
                return False
        else:
            print("No models found")
            return False
            
        # Success!
        print(f"\nStatus check completed successfully at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        return True
        
    except requests.exceptions.ConnectionError:
        print(f"❌ Failed to connect to Ollama service at {base_url}")
        return False
    except Exception as e:
        print(f"❌ Error checking Ollama status: {e}")
        return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Check Ollama deployment status')
    parser.add_argument('--host', default='localhost', help='Ollama host (default: localhost)')
    parser.add_argument('--port', type=int, default=11434, help='Ollama port (default: 11434)')
    
    args = parser.parse_args()
    
    if not check_ollama_status(args.host, args.port):
        sys.exit(1) 