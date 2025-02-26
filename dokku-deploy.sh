#!/bin/bash
set -e  # Exit on any error

# Default values
DEFAULT_APP_NAME="qdrant"
SKIP_API_KEY=false

# Parse optional flag
for arg in "$@"; do
  case "$arg" in
    --skip-api-key)
      SKIP_API_KEY=true
      shift  # Remove the flag from the arguments
      ;;
  esac
done

# Parse arguments - check if first argument contains @ (likely a host)
if [[ "$1" == *"@"* ]] && [ -z "$2" ]; then
  # First arg is host, use default app name
  APP_NAME=$DEFAULT_APP_NAME
  DOKKU_HOST=$1
  DOMAIN=$2
else 
  # Normal order: appname, host, domain
  APP_NAME=${1:-$DEFAULT_APP_NAME}
  DOKKU_HOST=$2
  DOMAIN=$3
fi

# Validate required arguments
if [ -z "$DOKKU_HOST" ]; then
  echo "Error: Missing required argument user@host"
  echo "Usage: $0 [appname] [user@host] [domain] [--skip-api-key]"
  echo "   OR: $0 [user@host] [domain] [--skip-api-key]"
  echo ""
  echo "Arguments:"
  echo "  appname       Name of the Dokku app (default: qdrant)"
  echo "  user@host     SSH connection string for the Dokku server (required)"
  echo "  domain        Domain name for the app (default: appname.hostname)"
  echo ""
  echo "Options:"
  echo "  --skip-api-key  Skip generating and setting a random API key"
  exit 1
fi

# If domain not provided, extract it from DOKKU_HOST
if [ -z "$DOMAIN" ]; then
  # Extract host part from user@host
  HOST_PART=$(echo $DOKKU_HOST | cut -d '@' -f 2)
  DOMAIN="${APP_NAME}.${HOST_PART}"
fi

echo "Deploying $APP_NAME to $DOKKU_HOST with domain $DOMAIN"
if [ "$SKIP_API_KEY" = true ]; then
  echo "WARNING: Skipping API key generation. Your Qdrant instance will be unsecured!"
else
  echo "Will secure Qdrant with a random API key (use --skip-api-key to disable)"
fi
echo "Will prompt for your password ONCE for the entire deployment"

# Run all commands in a single SSH session with clear headers
ssh -t $DOKKU_HOST "
  echo \"==== Creating app ====\"
  dokku apps:create $APP_NAME || true
  
  echo \"==== Setting up storage ====\"
  dokku storage:ensure-directory $APP_NAME
  
  echo \"==== Mounting storage ====\"
  dokku storage:mount $APP_NAME /var/lib/dokku/data/storage/$APP_NAME:/qdrant/storage
  
  echo \"==== Configuring domains ====\"
  dokku domains:report $APP_NAME | grep \"Domains app vhosts\" | grep -o \"[^ ]*packer[^ ]*\" | xargs -I{} dokku domains:remove $APP_NAME {} || true
  dokku domains:add $APP_NAME $DOMAIN
  
  echo \"==== Setting up ports ====\"
  dokku ports:set $APP_NAME http:80:6333 || echo \"Warning: Port setting failed, may need to set manually\"
  
  if [ \"$SKIP_API_KEY\" = false ]; then
    echo \"==== Setting up API key security ====\"
    API_KEY=\$(openssl rand -base64 32)
    dokku config:set $APP_NAME QDRANT__SERVICE__API_KEY=\$API_KEY
    echo \"API key generated and set for $APP_NAME\"
    echo \"Your Qdrant API key is: \$API_KEY\"
    echo \"⚠️  SAVE THIS KEY! It will not be shown again. ⚠️\"
    echo \"You will need to provide this key in the 'api-key' header for all requests.\"
  else
    echo \"==== SECURITY WARNING ====\"
    echo \"API key generation was skipped. Your Qdrant instance is NOT SECURED!\"
  fi
  
  echo \"==== Enabling Let's Encrypt ====\"
  dokku letsencrypt:enable $APP_NAME || echo \"Warning: Let's Encrypt setup failed, may need to configure manually\"
  
  echo \"Deployment commands completed for $APP_NAME\"
"

echo "=============================="
echo "✅ Deployment of $APP_NAME complete!"
echo "✅ Your app should be available at: https://$DOMAIN"
echo ""
echo "To check the app status, run:"
echo "  ssh $DOKKU_HOST \"dokku apps:report $APP_NAME\""
