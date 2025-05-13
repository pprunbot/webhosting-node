#!/bin/bash

# Step 1: Detect username
USER=$(whoami)

# Step 2: Detect domain from existing directories
DOMAIN=$(ls -d /home/$USER/domains/*/ | xargs -n1 basename | head -n 1)
if [[ -z "$DOMAIN" ]]; then
  echo "No domain found. Please specify a domain."
  exit 1
fi

echo "Detected domain: $DOMAIN"

# Step 3: Detect if Node.js is installed
if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
  echo "Node.js or npm not found. Installing Node.js..."
  
  # Install Node.js if not installed
  mkdir -p ~/.local/node
  curl -fsSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o node.tar.gz
  tar -xzf node.tar.gz --strip-components=1 -C ~/.local/node
  echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bashrc
  source ~/.bashrc
  echo 'export PATH=$HOME/.local/node/bin:$PATH' >> ~/.bash_profile
  source ~/.bash_profile
  
  if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
    echo "Node.js and npm installation failed. Exiting..."
    exit 1
  fi
fi

# Step 4: Install PM2 globally
echo "Installing PM2..."
npm install -g pm2

# Step 5: Clone necessary files from GitHub repository
echo "Cloning necessary files..."
cd /home/$USER/domains/$DOMAIN/public_html
git clone https://github.com/pprunbot/webhosting-node.git .

# Step 6: Modify app.js with detected domain
echo "Modifying app.js with detected domain..."
sed -i "s|const DOMAIN = process.env.DOMAIN || '.*';|const DOMAIN = process.env.DOMAIN || '$DOMAIN';|" app.js

# Step 7: Run the server with PM2
echo "Starting the app with PM2..."
pm2 start app.js --name my-app
pm2 save

# Step 8: Add PM2 to crontab to resurrect on reboot
echo "Setting up crontab to resurrect PM2 on reboot..."
crontab -l | { cat; echo "@reboot sleep 30 && /home/$USER/.local/node/bin/pm2 resurrect --no-daemon"; } | crontab -

echo "Installation complete. The app is running with PM2 and will auto-resurrect on reboot."
