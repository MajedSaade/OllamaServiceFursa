# Ollama Mistral Deployment

This repository contains an automated deployment solution for Ollama with the Mistral LLM model on an EC2 instance using GitHub Actions.

## Setup Instructions

### 1. Prerequisites

- An AWS EC2 instance running Linux
- GitHub repository
- SSH access to the EC2 instance

### 2. GitHub Secrets Configuration

Add the following secrets to your GitHub repository:

- `EC2_SSH_KEY`: Your private SSH key for connecting to the EC2 instance
- `EC2_HOST`: The hostname or IP address of your EC2 instance
- `EC2_USERNAME`: The username to connect to your EC2 instance (usually "ubuntu" for Ubuntu-based instances)

### 3. Repository Structure

- `.github/workflows/deploy.yaml`: GitHub Actions workflow file
- `deploy.sh`: Deployment script to install and configure Ollama
- `ollama.service`: Systemd service file for Ollama
- `setup_ollama.py`: Python script for additional setup and verification
- `requirements.txt`: Python dependencies
- `check_status.py`: Script to check the status of Ollama deployment

### 4. Deployment Process

1. Push your code to the `main` branch or manually trigger the workflow
2. GitHub Actions will:
   - Clone/update the repository on your EC2 instance
   - Execute the deployment script
   - Install Ollama if needed
   - Configure the systemd service
   - Pull the Mistral model
   - Verify the deployment

### 5. Accessing Ollama

Once deployed, Ollama will be accessible on your EC2 instance:
- API endpoint: `http://<your-ec2-ip>:11434/api/generate`

Example API usage:
```bash
curl -X POST http://<your-ec2-ip>:11434/api/generate -d '{
  "model": "mistral",
  "prompt": "Hello, how are you?",
  "stream": false
}'
```

## Manual Deployment

If you want to deploy manually:

```bash
git clone <your-repo-url>
cd <repo-name>
bash deploy.sh
```

## Using the Status Check Script

To verify that your Ollama deployment is working correctly:

```bash
python3 check_status.py
# Or to check a remote instance:
python3 check_status.py --host <your-ec2-ip>
```

## Troubleshooting

If the deployment fails, check:
1. Systemd service logs: `sudo journalctl -u ollama.service`
2. Ollama server status: `systemctl status ollama.service`
3. EC2 instance firewall settings (ensure port 11434 is open)

## Security Considerations

1. Ensure your EC2 security groups allow access to port 11434 only from trusted IPs
2. Use proper IAM roles and permissions for your EC2 instance
3. Keep your SSH keys secure and never commit them to the repository 