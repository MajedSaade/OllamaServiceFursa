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

### Connecting from External Machines

The Ollama service is configured to listen on all network interfaces (0.0.0.0), allowing you to connect from external machines. To access the service from outside the EC2 instance:

1. Make sure your EC2 security group allows inbound traffic on port 11434
2. Use your EC2 instance's public IP or DNS name:

```bash
curl -X POST http://YOUR_EC2_IP:11434/api/generate -d '{
  "model": "gemma3:1b",
  "prompt": "What is the capital of France?"
}'
```

### Connecting Mypolybot to Ollama

To connect Mypolybot to your Ollama service:

1. Make sure the Ollama service is running and listening on all interfaces (should show `*:11434` when running `ss -tulpn | grep 11434`)
2. Configure Mypolybot to connect to the correct IP address of your instance:
   - Use the public IP or DNS name if connecting from outside the network
   - Example configuration: `http://YOUR_EC2_IP:11434/api/chat`
3. Ensure there are no firewall rules blocking the connection between Mypolybot and the Ollama instance

If you're still having trouble connecting Mypolybot to Ollama:
- Check the App.py log (`cat ollama_monitor.log`) to verify network configuration
- Test connectivity manually: `curl -X GET http://YOUR_EC2_IP:11434/api/tags`
- Verify the Gemma model is available: `ollama list | grep gemma3:1b`

If you're having connection issues:
- Verify the Ollama service is listening on all interfaces: `ss -tulpn | grep 11434`
- Check your EC2 security group settings to ensure port 11434 is open
- Confirm your EC2 instance doesn't have a firewall blocking the connection

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