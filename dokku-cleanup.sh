#!/bin/bash
set -e  # Exit on any error

# Initialize variables
REMOVE_STORAGE=false

# Parse optional flag
for arg in "$@"; do
  case "$arg" in
    --delete-storage)
      REMOVE_STORAGE=true
      shift  # Remove the flag from the arguments
      ;;
  esac
done

# Get positional arguments
APP_NAME=$1
DOKKU_HOST=$2

# Validate required arguments
if [ -z "$APP_NAME" ] || [ -z "$DOKKU_HOST" ]; then
  echo "Error: Missing required arguments"
  echo "Usage: $0 app_name user@host [--delete-storage]"
  echo ""
  echo "Arguments:"
  echo "  app_name       Name of the Dokku app to clean up (required)"
  echo "  user@host      SSH connection string for the Dokku server (required)"
  echo ""
  echo "Options:"
  echo "  --delete-storage  Also remove the persistent storage directory (use with caution!)"
  echo ""
  echo "Examples:"
  echo "  $0 qdrant sam@dokku.example.com            # Clean up qdrant app"
  echo "  $0 myapp sam@dokku.example.com --delete-storage  # Clean up myapp including storage"
  exit 1
fi

echo "Cleaning up $APP_NAME on $DOKKU_HOST"
if [ "$REMOVE_STORAGE" = true ]; then
  echo "WARNING: Storage directory will also be removed!"
fi

# Run all cleanup commands in a single SSH session
ssh -t $DOKKU_HOST "
  echo \"Checking if app exists...\"
  if dokku apps:exists $APP_NAME; then
    echo \"App exists. Performing cleanup...\"
    
    echo \"Cleaning up Let's Encrypt (if enabled)...\"
    dokku letsencrypt:cleanup $APP_NAME || true
    
    echo \"Unmounting storage...\"
    dokku storage:list $APP_NAME | awk '{print \$1}' | xargs -I{} dokku storage:unmount $APP_NAME {} || true
    
    echo \"Destroying app...\"
    dokku apps:destroy $APP_NAME --force
    
    if [ \"$REMOVE_STORAGE\" = true ]; then
      echo \"Removing storage directory...\"
      sudo rm -rf /var/lib/dokku/data/storage/$APP_NAME || true
    else
      echo \"Skipping storage directory removal (use --delete-storage flag to remove storage)\"
    fi
    
    echo \"Cleaning up any remaining nginx configs...\"
    sudo rm -f /etc/nginx/conf.d/$APP_NAME*.conf || true
    sudo service nginx reload || true
    
    echo \"Running dokku cleanup...\"
    dokku cleanup
    
    echo \"App $APP_NAME successfully cleaned up!\"
  else
    echo \"App $APP_NAME does not exist. Nothing to clean up.\"
  fi
"

echo "Cleanup complete!"
