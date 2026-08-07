#!/bin/bash
set -e

echo "Installing packages..."
sudo apt update
sudo apt install -y i3 i3blocks flameshot brightnessctl playerctl \
  network-manager dex xss-lock scrot feh rofi kitty stow \
  sysstat python3-venv git

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
cd ~/dotfiles
stow i3
stow i3blocks

echo "Done. Reload i3 with mod+shift+c or restart your session."

