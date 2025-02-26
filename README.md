# Qdrant on Dokku
A simple deployment toolset for running [Qdrant](https://qdrant.tech/), a vector similarity search engine, on [Dokku](https://dokku.com/), a Docker-powered PaaS.
## Overview
This repository provides:
1. A minimal Dockerfile for running Qdrant on Dokku based on the official image
2. Deployment scripts to automate setup and cleanup
3. Configuration for proper persistent storage
## Requirements
- A Dokku server with SSH access
- Dokku 0.25.0+ installed on the server
- SSH key-based authentication configured (recommended)
## Quick Start
### Deploying Qdrant
```bash
# Basic deployment with default settings (includes API key generation)
./dokku-deploy.sh user@your-dokku-server.com
# Custom app name and domain
./dokku-deploy.sh myqdrant user@your-dokku-server.com myqdrant.example.com
# Deploy without generating an API key (not recommended for production)
./dokku-deploy.sh qdrant user@your-dokku-server.com --skip-api-key
```
### Cleaning Up
```bash
# Basic cleanup (preserves persistent storage)
./dokku-cleanup.sh qdrant user@your-dokku-server.com
# Full cleanup including storage (use with caution!)
./dokku-cleanup.sh qdrant user@your-dokku-server.com --delete-storage
```
## Accessing Qdrant

After deployment, your Qdrant instance will be available at:

- **Web UI Console**: `https://[app-name].[your-dokku-server]` 
  (e.g., `https://qdrant.example.com`)
- **API Endpoint**: `https://[app-name].[your-dokku-server]`

The deployment script configures:
- HTTP port forwarding (port 80 → 6333)
- HTTPS with Let's Encrypt (port 443 → 6333)
- API key authentication

**Note**: When accessing the Qdrant API, remember to include your API key in the `api-key` header. The Web UI will prompt you for this key.

## Deployment Details
The deployment process:
1. Creates a Dokku app
2. Sets up persistent storage with proper permissions
3. Mounts storage to the container
4. Configures domain routing
5. Sets up HTTP port forwarding (port 6333)
6. Generates and sets a random API key for security (unless --skip-api-key is used)
7. Enables Let's Encrypt SSL (if available)
## Storage Considerations
By default, Qdrant data is stored in `/var/lib/dokku/data/storage/[app-name]`. This location is mounted to `/qdrant/storage` inside the container.
The storage directory uses UID/GID 32767, which is a common practice for Dokku applications to ensure proper permissions.
## Customization
### Custom Configuration
To use a custom Qdrant config:
1. Create your `config.yaml` file
2. Modify the Dockerfile to copy your config:
```dockerfile
FROM qdrant/qdrant
COPY ./config.yaml /qdrant/config/production.yaml
EXPOSE 6333
```
### Environment Variables
You can set environment variables for Qdrant through Dokku:
```bash
dokku config:set qdrant QDRANT_ENABLE_COLLECT_TELEMETRY=false
```
### Security
**Important:** By default, the deployment script secures your Qdrant instance by generating a random API key. This key will be displayed once during deployment - make sure to save it!
```bash
# The script automatically generates and sets an API key:
dokku config:set qdrant QDRANT_API_KEY=$RANDOM_GENERATED_KEY
```
You will need to provide this API key in the `api-key` header for all requests to your Qdrant instance.
If you've lost your API key, you can generate a new one:
```bash
# Generate a new random API key
API_KEY=$(openssl rand -base64 32)
# Set it in Dokku
dokku config:set qdrant QDRANT_API_KEY=$API_KEY
# Save the key somewhere secure
echo "Your new Qdrant API key is: $API_KEY"
```
For production environments, consider these additional security measures:
- Setting up a VPC or private network for your Dokku server
- Implementing IP-based access restrictions
- Using a reverse proxy with additional authentication
## Troubleshooting
### Common Issues
- **Permission errors**: Make sure storage directories have UID/GID 32767
- **Port conflicts**: Verify no other apps are using port 6333
- **Let's Encrypt failures**: Ensure DNS is properly configured for your domain
### Checking Logs
```bash
dokku logs qdrant -t
```
## License
MIT License
## Acknowledgements
- [Qdrant](https://qdrant.tech/) for the excellent vector database
- [Dokku](https://dokku.com/) for the self-hosted PaaS platform
