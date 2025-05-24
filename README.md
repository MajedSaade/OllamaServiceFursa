# Ollama with Gemma 3 1B (815MB) Automated Deployment

This repository contains automation scripts to deploy Ollama with the Gemma 3 1B model (approximately 815MB in size) on an EC2 instance using GitHub Actions for continuous deployment.

## Repository Structure

- `.github/workflows/deploy.yaml`: GitHub Actions workflow for deployment
- `deploy.sh`: Script to deploy Ollama and the Gemma model on the EC2 instance
- `ollama.service`: Systemd service file for running Ollama
- `app.py`: Python monitoring script for Ollama
- `requirements.txt`: Python dependencies

## Setup Instructions

### 1. Configure GitHub Secrets

Add the following secrets to your GitHub repository:

- `EC2_SSH_KEY`: Your private SSH key to connect to the EC2 instance
- `EC2_HOST`: The hostname or IP address of your EC2 instance
- `EC2_USERNAME`: The username to use when connecting to EC2 (e.g., `ubuntu`, `ec2-user`)

### 2. EC2 Instance Requirements

- Ubuntu or similar Linux distribution
- Python 3 installed
- Sufficient disk space for the Gemma model (at least 5GB free)
- Sufficient RAM (at least 8GB recommended)

### 3. Deployment

The deployment can be triggered in two ways:

1. Push to the `main` branch
2. Manually from the GitHub Actions tab in your repository

### 4. Verification

After deployment:

1. SSH into your EC2 instance
2. Check the status of the Ollama service: `sudo systemctl status ollama.service`
3. Check the logs: `cat ollama_monitor.log`

## Testing the Gemma Model

You can test the model directly on your EC2 instance:

```bash
curl -X POST http://localhost:11434/api/generate -d '{
  "model": "gemma3:1b",
  "prompt": "What is the capital of France?"
}'
```

## Troubleshooting

If you encounter issues:

1. Check if Ollama is running: `sudo systemctl status ollama.service`
2. Check logs: `cat ollama_monitor.log`
3. Restart the service: `sudo systemctl restart ollama.service`
4. Verify model is downloaded: `ollama list`

## Security Considerations

- This setup uses root permissions for the Ollama service
- Consider restricting access to the Ollama API with a firewall
- Use a secure SSH key and keep it private 