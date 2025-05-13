#!/usr/bin/env bash
set -e

USER_NAME="$(whoami)"
HOME_DIR="${HOME:-/home/$USER_NAME}"
echo "Detected user: $USER_NAME"

# Alternative method to list domains without mapfile
DOMAINS=()
for d in "$HOME_DIR/domains"/*/; do
  if [ -d "$d" ]; then
    DOMAINS+=("$(basename "$d")")
  fi
done

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

read -p "Enter port [default 4642]: " PORT < /dev/tty
PORT="${PORT:-4642}"
read -p "Enter UUID [default cdc72a29-c14b-4741-bd95-e2e3a8f31a56]: " UUID < /dev/tty
UUID="${UUID:-cdc72a29-c14b-4741-bd95-e2e3a8f31a56}"

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
fi

echo "Node.js version: $(node -v)"
echo "npm version: $(npm -v)"

TARGET_DIR="$HOME_DIR/domains/$DOMAIN/public_html"
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

BASE_RAW="https://raw.githubusercontent.com/pprunbot/webhosting-node/main"
for file in app.js .htaccess package.json ws.php; do
  curl -fsSL "$BASE_RAW/$file" -o "$file"
done

# Escape values
ESCAPED_DOMAIN=$(printf '%s\n' "$DOMAIN" | sed 's/[&/\]/\\&/g')
ESCAPED_UUID=$(printf '%s\n' "$UUID" | sed 's/[&/\]/\\&/g')

# Replace config in app.js
sed -i \
  -e "s|const DOMAIN = process.env.DOMAIN.*|const DOMAIN = process.env.DOMAIN || '$ESCAPED_DOMAIN';|" \
  -e "s|const port = process.env.PORT.*|const port = process.env.PORT || $PORT;|" \
  -e "s|const UUID = process.env.UUID.*|const UUID = process.env.UUID || '$ESCAPED_UUID';|" \
  app.js

npm install -g pm2

pm2 start app.js --name "webhost-$DOMAIN"
pm2 save

CRON_CMD="@reboot sleep 30 && $HOME_DIR/.local/node/bin/pm2 resurrect --no-daemon"
( crontab -l 2>/dev/null | grep -v -F "$CRON_CMD" || true; echo "$CRON_CMD" ) | crontab -

echo "✅ Installation complete. PM2 is managing app.js under name webhost-$DOMAIN."
