#!/usr/bin/env bash
set -e

# Detect SSH username and home
USER_NAME="$(whoami)"
HOME_DIR="${HOME:-/home/$USER_NAME}"
echo "Detected user: $USER_NAME"

# Domain detection
mapfile -t DOMAINS < <(ls -d "$HOME_DIR/domains"/*/ 2>/dev/null | xargs -n1 basename)
if (( ${#DOMAINS[@]} == 0 )); then
  echo "No domains found under $HOME_DIR/domains"
  exit 1
elif (( ${#DOMAINS[@]} == 1 )); then
  DOMAIN="${DOMAINS[0]}"
  echo "Using domain: $DOMAIN"
else
  echo "Multiple domains detected. Please choose one:"
  for i in "${!DOMAINS[@]}"; do
    printf "%d) %s\n" "$((i+1))" "${DOMAINS[i]}"
  done
  while true; do
    read -p "#? " CHOICE < /dev/tty
    if [[ "$CHOICE" =~ ^[0-9]+$ ]] && (( CHOICE>=1 && CHOICE<=${#DOMAINS[@]} )); then
      DOMAIN="${DOMAINS[CHOICE-1]}"
      break
    fi
    echo "Invalid choice, try again." >&2
  done
  echo "Selected domain: $DOMAIN"
fi

# Ask for port and UUID
read -p "Enter port [default 4642]: " PORT < /dev/tty
PORT="${PORT:-4642}"
read -p "Enter UUID [default cdc72a29-c14b-4741-bd95-e2e3a8f31a56]: " UUID < /dev/tty
UUID="${UUID:-cdc72a29-c14b-4741-bd95-e2e3a8f31a56}"

# Install Node.js locally if missing
if ! command -v node >/dev/null || ! command -v npm >/dev/null; then
  echo "Node.js or npm not found. Installing locally..."
  mkdir -p "$HOME_DIR/.local/node"
  curl -fsSL https://nodejs.org/dist/v20.12.2/node-v20.12.2-linux-x64.tar.gz -o node.tar.gz
  tar -xzf node.tar.gz --strip-components=1 -C "$HOME_DIR/.local/node"
  rm node.tar.gz
  echo 'export PATH="$HOME/.local/node/bin:$PATH"' >> "$HOME_DIR/.bashrc"
  echo 'export PATH="$HOME/.local/node/bin:$PATH"' >> "$HOME_DIR/.bash_profile"
  source "$HOME_DIR/.bashrc" || true
  source "$HOME_DIR/.bash_profile" || true
  if ! command -v node >/dev/null; then
    echo "Node.js installation failed." >&2
    exit 1
  fi
fi

echo "Node.js version: $(node -v)"
echo "npm version: $(npm -v)"

# Prepare target directory
TARGET_DIR="$HOME_DIR/domains/$DOMAIN/public_html"
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# Fetch files
BASE_RAW="https://raw.githubusercontent.com/pprunbot/webhosting-node/main"
for file in app.js .htaccess package.json ws.php; do
  curl -fsSL "$BASE_RAW/$file" -o "$file"
done

# Replace defaults in app.js
sed -i \
  -e "s|const DOMAIN = process.env.DOMAIN.*|const DOMAIN = process.env.DOMAIN || '$DOMAIN';|" \
  -e "s|const port = process.env.PORT.*|const port = process.env.PORT || $PORT;|" \
  -e "s|const UUID = process.env.UUID.*|const UUID = process.env.UUID || '$UUID';|" \
  app.js

# Install pm2
npm install -g pm2

# Start app
pm2 start app.js --name "webhost-$DOMAIN"
pm2 save

# Setup crontab for pm2 resurrect
CRON_CMD="@reboot sleep 30 && $HOME_DIR/.local/node/bin/pm2 resurrect --no-daemon"
( crontab -l 2>/dev/null | grep -v -F "$CRON_CMD" || true; echo "$CRON_CMD" ) | crontab -

echo "Installation complete. PM2 is managing app.js under name webhost-$DOMAIN."
