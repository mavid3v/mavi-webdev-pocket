#!/usr/bin/env bash
#
# Mavi's Web Development Pocket Script

# --- Visuals ---
RESET="\e[0m"
BLUE="\e[34m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
BOLD="\e[1m"

# --- User detection ---
CURRENT_USER="${SUDO_USER:-${USER:-$(logname 2>/dev/null || echo root)}}"

# --- Temp work dir + cleanup ---
WORKDIR="$(mktemp -d -t mavi-webdev-XXXXXXXX)"
cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

# --- Spinner used while waiting for background installs ---
spinner_wait() {
  local pid=$1
  local delay=0.12
  local spinstr='|/-\'
  printf " "
  while kill -0 "$pid" 2>/dev/null; do
    for i in $(seq 0 3); do
      printf "\b${YELLOW}%s${RESET}" "${spinstr:$i:1}"
      sleep "$delay"
    done
  done
  printf "\b"
}

# --- Install package (apt) quietly with spinner, checks exit code ---
install_pkg() {
  local pkg="$1"
  printf "${BLUE}[→] Installing %s...${RESET} " "$pkg"
  apt-get install -y "$pkg" -qq >/dev/null 2>&1 & install_pid=$!
  spinner_wait "$install_pid"
  wait "$install_pid"
  rc=$?
  if [[ $rc -ne 0 ]]; then
    printf "${RED}[✘] Failed to install %s (apt rc=%d)${RESET}\n" "$pkg" "$rc"
    exit 1
  fi
  printf "${GREEN}[✔] %s installed${RESET}\n" "$pkg"
}

# --- Ensure root ---
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}[✘] Please run this script as root (sudo).${RESET}"
  exit 1
fi

echo -e "${BOLD}${BLUE}=== Mavi's Web Development Pocket Script ===${RESET}"

# --- Step 0: Check for required apt packages (bulk check + one update) ---
REQUIRED_PACKAGES=(curl wget tar unzip git jq xz-utils zip libglu1-mesa build-essential)
MISSING=()
for pkg in "${REQUIRED_PACKAGES[@]}"; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    MISSING+=("$pkg")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo -e "${BLUE}[→] Updating apt caches (quiet)${RESET}"
  apt-get update -qq >/dev/null
  for pkg in "${MISSING[@]}"; do
    install_pkg "$pkg"
  done
else
  echo -e "${GREEN}[✔] All base dependencies are already installed${RESET}"
fi

# --- Utility to check command presence (by command name) ---
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# --- Step 1: Google Chrome (deb) ---
if ! command_exists google-chrome && ! command_exists google-chrome-stable; then
  echo -e "${BLUE}[→] Downloading Google Chrome...${RESET}"
  wget --show-progress "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" -O "$WORKDIR/google-chrome.deb"
  install_pkg "$WORKDIR/google-chrome.deb"
  rm -f "$WORKDIR/google-chrome.deb"
else
  echo -e "${YELLOW}[!] Google Chrome already installed, skipping.${RESET}"
fi

# --- Step 2: Visual Studio Code (deb) ---
if ! command_exists code; then
  echo -e "${BLUE}[→] Downloading Visual Studio Code...${RESET}"
  wget --show-progress "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" -O "$WORKDIR/vscode.deb"
  install_pkg "$WORKDIR/vscode.deb"
  rm -f "$WORKDIR/vscode.deb"
else
  echo -e "${YELLOW}[!] VS Code already installed, skipping.${RESET}"
fi

# --- Step 3: JetBrains Toolbox (detect versioned folders & optionally init) ---
echo -e "${BLUE}[→] Checking JetBrains Toolbox in /opt...${RESET}"
toolbox_dir=$(find /opt -maxdepth 1 -type d -name "jetbrains-toolbox*" | head -n 1 || true)

if [[ -n "$toolbox_dir" ]]; then
  echo -e "${YELLOW}[!] JetBrains Toolbox present at: ${toolbox_dir}${RESET}"
  # If user config doesn't exist, run once silently to initialize
  user_toolbox_config="/home/${CURRENT_USER}/.local/share/JetBrains/Toolbox"
  if [[ ! -d "$user_toolbox_config" ]]; then
    echo -e "${BLUE}[→] Running Toolbox once to initialize for user ${CURRENT_USER}...${RESET}"
    nohup "${toolbox_dir}/jetbrains-toolbox" >/dev/null 2>&1 &
  else
    echo -e "${GREEN}[✔] Toolbox already initialized for ${CURRENT_USER}${RESET}"
  fi
else
  echo -e "${BLUE}[→] Downloading JetBrains Toolbox (latest)...${RESET}"
  # Use JetBrains JSON releases API (requires jq)
  toolbox_json_url="https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release"
  toolbox_url=$(curl -s "$toolbox_json_url" | jq -r '.[].downloads.linux.link' | head -n 1)
  if [[ -z "$toolbox_url" || "$toolbox_url" == "null" ]]; then
    echo -e "${RED}[✘] Failed to determine JetBrains Toolbox download URL.${RESET}"
  else
    wget --show-progress "$toolbox_url" -O "$WORKDIR/jetbrains-toolbox.tar.gz"
    tar -xzf "$WORKDIR/jetbrains-toolbox.tar.gz" -C /opt
    # find the newly extracted directory
    new_toolbox_dir=$(find /opt -maxdepth 1 -type d -name "jetbrains-toolbox*" | head -n 1 || true)
    if [[ -n "$new_toolbox_dir" ]]; then
      # If there's no canonical /opt/jetbrains-toolbox, create one pointing to extracted dir
      if [[ ! -e /opt/jetbrains-toolbox ]]; then
        mv "$new_toolbox_dir" /opt/jetbrains-toolbox 2>/dev/null || true
        new_toolbox_dir="/opt/jetbrains-toolbox"
      fi
      chmod +x "${new_toolbox_dir}/jetbrains-toolbox" || true
      nohup "${new_toolbox_dir}/jetbrains-toolbox" >/dev/null 2>&1 &
      echo -e "${GREEN}[✔] JetBrains Toolbox installed at ${new_toolbox_dir}${RESET}"
    else
      echo -e "${RED}[✘] Failed to extract JetBrains Toolbox properly.${RESET}"
    fi
    rm -f "$WORKDIR/jetbrains-toolbox.tar.gz"
  fi
fi

# --- Step 4: Node.js LTS ---
if ! command_exists node; then
  echo -e "${BLUE}[→] Installing Node.js (LTS)...${RESET}"
  curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - >/dev/null 2>&1
  install_pkg nodejs
else
  echo -e "${YELLOW}[!] Node.js already installed, skipping.${RESET}"
fi

# --- Step 5: Java JDK & JRE ---
if ! command_exists java; then
  install_pkg default-jdk
  install_pkg default-jre
else
  echo -e "${YELLOW}[!] Java already installed, skipping.${RESET}"
fi

# --- Step 6: build-essential (ensured earlier but double-check) ---
if ! dpkg -s build-essential >/dev/null 2>&1; then
  install_pkg build-essential
else
  echo -e "${YELLOW}[!] build-essential already installed, skipping.${RESET}"
fi

# --- Step 7: MongoDB Compass & Mongosh (best-effort via Mongo pages) ---
echo -e "${BLUE}[→] Fetching MongoDB Compass & Mongosh download URLs...${RESET}"
compass_url=$(curl -s "https://www.mongodb.com/try/download/compass" | grep -oP 'https://downloads.mongodb.com/compass/mongodb-compass_[^"]+_amd64.deb' | head -n 1 || true)
mongosh_url=$(curl -s "https://www.mongodb.com/try/download/compass" | grep -oP 'https://downloads.mongodb.com/compass/mongodb-mongosh_[^"]+_amd64.deb' | head -n 1 || true)

if [[ -n "$compass_url" ]]; then
  if ! command_exists mongodb-compass; then
    echo -e "${BLUE}[→] Downloading MongoDB Compass...${RESET}"
    wget --show-progress "$compass_url" -O "$WORKDIR/mongodb-compass.deb"
    install_pkg "$WORKDIR/mongodb-compass.deb"
    rm -f "$WORKDIR/mongodb-compass.deb"
  else
    echo -e "${YELLOW}[!] MongoDB Compass already installed, skipping.${RESET}"
  fi
else
  echo -e "${YELLOW}[!] Could not determine MongoDB Compass URL automatically, skipping download.${RESET}"
fi

if [[ -n "$mongosh_url" ]]; then
  if ! command_exists mongosh; then
    echo -e "${BLUE}[→] Downloading MongoDB Shell (mongosh)...${RESET}"
    wget --show-progress "$mongosh_url" -O "$WORKDIR/mongosh.deb"
    install_pkg "$WORKDIR/mongosh.deb"
    rm -f "$WORKDIR/mongosh.deb"
  else
    echo -e "${YELLOW}[!] mongosh already installed, skipping.${RESET}"
  fi
else
  echo -e "${YELLOW}[!] Could not determine mongosh URL automatically, skipping download.${RESET}"
fi

# --- Step 8: Flutter SDK (user-specified exact archive) ---
if [[ ! -d "/opt/flutter" ]]; then
    echo -e "${BLUE}[→] Installing Flutter SDK (latest stable)...${RESET}"
    FLUTTER_URL=$(curl -s https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json | \
        jq -r '.current_release.stable as $stable |
               .releases[] | select(.hash == $stable) |
               "https://storage.googleapis.com/flutter_infra_release/releases/" + .archive')
    if [[ -z "$FLUTTER_URL" || "$FLUTTER_URL" == "null" ]]; then
        echo -e "${RED}[✘] Failed to determine latest Flutter SDK URL.${RESET}"
        exit 1
    fi
    wget --show-progress "$FLUTTER_URL" -O "$WORKDIR/flutter.tar.xz"
    if xz -t "$WORKDIR/flutter.tar.xz" >/dev/null 2>&1 || file "$WORKDIR/flutter.tar.xz" | grep -qi 'XZ compressed data\|tar archive'; then
        tar -xf "$WORKDIR/flutter.tar.xz" -C /opt
        mv /opt/flutter* /opt/flutter 2>/dev/null || true
        echo -e "${GREEN}[✔] Flutter installed at /opt/flutter${RESET}"
    else
        echo -e "${RED}[✘] Downloaded Flutter archive is invalid.${RESET}"
        rm -f "$WORKDIR/flutter.tar.xz"
        exit 1
    fi
    rm -f "$WORKDIR/flutter.tar.xz"
    echo -e "${YELLOW}[!] Add /opt/flutter/bin to your PATH (e.g. export PATH=\"/opt/flutter/bin:\$PATH\")${RESET}"
else
    echo -e "${YELLOW}[!] Flutter already installed at /opt/flutter, skipping.${RESET}"
fi

# --- Final summary / greeting ---
echo -e "\n${GREEN}[✔] All requested tasks processed.${RESET}"
echo -e "${BLUE}Happy coding, ${CURRENT_USER}!${RESET}"
