#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing packages from packages.txt..."
sudo apt update
xargs -a "$DOTFILES_DIR/packages.txt" sudo apt install -y

echo "Installing i3blocks-contrib scripts..."
git clone --depth 1 https://github.com/vivien/i3blocks-contrib.git /tmp/i3blocks-contrib
sudo mkdir -p /usr/share/i3blocks
for name in volume memory disk iface wifi bandwidth cpu_usage battery; do
  sudo cp "/tmp/i3blocks-contrib/$name/$name" "/usr/share/i3blocks/$name"
done
sudo chmod +x /usr/share/i3blocks/*
rm -rf /tmp/i3blocks-contrib

echo "Setting up i3blocks-mpris venv..."
python3 -m venv ~/.venvs/spotify-i3blocks
~/.venvs/spotify-i3blocks/bin/pip install i3blocks-mpris

echo "Symlinking dotfiles with stow..."
cd "$DOTFILES_DIR"
stow i3
stow i3blocks

echo "Done. Reload i3 with mod+shift+c or restart your session."
