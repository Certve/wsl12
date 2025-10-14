#!/bin/bash
# Playit installation script - Auto Installer Made by <3 Hopingboy
# Tested on Ubuntu/Debian

set -e

echo "=== Updating system ==="
sudo apt update -y && sudo apt upgrade -y

echo "=== Installing required dependencies ==="
sudo apt install -y sudo curl gpg

echo "=== Adding Playit APT repository ==="
curl -fsSL https://playit-cloud.github.io/ppa/key.gpg | \
  gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/playit.gpg >/dev/null

echo "deb [signed-by=/etc/apt/trusted.gpg.d/playit.gpg] https://playit-cloud.github.io/ppa/data ./" | \
  sudo tee /etc/apt/sources.list.d/playit-cloud.list

echo "=== Updating package list ==="
sudo apt update -y

echo "=== Installing Playit ==="
sudo apt install -y playit

echo "=== Enabling Playit service ==="
sudo systemctl enable --now playit

echo "=== Running Playit setup ==="
playit setup

echo "✅ Playit installation complete!"
echo "➡️ Run 'playit status' to check the tunnel status."
