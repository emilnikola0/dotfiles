#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="${HOME}"
PACKAGES_FILE="$DOTFILES_DIR/packages.txt"

echo "Preparing system for dotfiles install..."

if [ ! -f "$PACKAGES_FILE" ]; then
  echo "Error: packages.txt not found in $DOTFILES_DIR" >&2
  exit 1
fi

# Read packages.txt, ignore blank lines and comments
mapfile -t PKGS < <(grep -E -v '^\s*($|#)' "$PACKAGES_FILE" || true)

# Ensure a few essential packages are present even if not listed
EXTRAS=(neovim i3lock imagemagick pulseaudio-utils python3-pip flatpak thunar fonts-firacode)
for e in "${EXTRAS[@]}"; do
  found=false
  for p in "${PKGS[@]}"; do
    if [ "$p" = "$e" ]; then found=true; break; fi
  done
  if ! $found; then
    PKGS+=("$e")
  fi
done

if [ ${#PKGS[@]} -eq 0 ]; then
  echo "No packages to install. Check packages.txt." && exit 0
fi

echo "Updating apt and installing packages..."
sudo apt update
sudo apt install -y "${PKGS[@]}"

# Install fonts (Meslo / Nerd Font) into local fonts if Meslo not present
FONT_CHECK=$(fc-list | grep -i "Meslo" || true)
if [ -z "$FONT_CHECK" ]; then
  echo "Installing Meslo (Nerd Font) to $USER_HOME/.local/share/fonts..."
  mkdir -p "$USER_HOME/.local/share/fonts"
  tmpdir=$(mktemp -d)
  # Try to fetch a Meslo patched font from Nerd Fonts repository. This may fail if URL/layout changes.
  if command -v git >/dev/null 2>&1; then
    git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git "$tmpdir/nerd-fonts"
    # Copy a few common Meslo files if present (best-effort)
    find "$tmpdir/nerd-fonts/patched-fonts" -type f -iname "*Meslo*" -exec cp -v {} "$USER_HOME/.local/share/fonts/" \; || true
  fi
  # Refresh font cache
  fc-cache -f || true
  rm -rf "$tmpdir"
fi

# Install i3blocks-contrib scripts used by config
echo "Installing i3blocks-contrib scripts..."
TMP_I3BLOCKS="/tmp/i3blocks-contrib"
rm -rf "$TMP_I3BLOCKS"
git clone --depth 1 https://github.com/vivien/i3blocks-contrib.git "$TMP_I3BLOCKS"
sudo mkdir -p /usr/share/i3blocks
SCRIPTS=(volume memory disk iface wifi bandwidth cpu_usage battery)
for name in "${SCRIPTS[@]}"; do
  src="$TMP_I3BLOCKS/$name/$name"
  if [ -f "$src" ]; then
    sudo cp "$src" "/usr/share/i3blocks/$name"
  else
    # try to find the file anywhere in the repo (best-effort)
    f=$(find "$TMP_I3BLOCKS" -type f -name "$name" -print -quit || true)
    if [ -n "$f" ]; then
      sudo cp "$f" "/usr/share/i3blocks/$name"
    else
      echo "Warning: i3blocks-contrib script '$name' not found in upstream repo." >&2
    fi
  fi
done
sudo chmod +x /usr/share/i3blocks/* || true
rm -rf "$TMP_I3BLOCKS"

# Set up i3blocks-mpris venv in the user's home
echo "Setting up i3blocks-mpris virtualenv..."
mkdir -p "$USER_HOME/.venvs"
python3 -m venv "$USER_HOME/.venvs/spotify-i3blocks"
"$USER_HOME/.venvs/spotify-i3blocks/bin/python" -m pip install --upgrade pip setuptools wheel
"$USER_HOME/.venvs/spotify-i3blocks/bin/pip" install i3blocks-mpris

# Ensure flatpak + flathub and install Spotify (best-effort)
if ! command -v flatpak >/dev/null 2>&1; then
  echo "Installing flatpak..."
  sudo apt install -y flatpak
fi
if ! flatpak remote-list | grep -q flathub; then
  echo "Adding Flathub remote..."
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi
# Try installing Spotify via flatpak (non-fatal if it fails)
flatpak install -y flathub com.spotify.Client || true

# Symlink dotfiles using stow (run as the invoking user)
echo "Symlinking dotfiles with stow..."
cd "$DOTFILES_DIR"
# Do not run stow as sudo to ensure symlinks are created in the user's home
stow i3 || true
stow i3blocks || true
stow nvim || true

# Post-install notes
cat <<EOF
Install complete (best-effort). Next manual steps you may want to perform:
- Check i3 and i3blocks configs for hard-coded paths like /home/emiln/ and replace them with \$HOME.
- Ensure scripts referenced by i3 (~/.config/i3/scripts/toggletouchpad.sh, ~/.screenlayout/display-setup.sh) exist or add them to the repo.
- Add your wallpaper to the path referenced by i3 or update the config.
- If i3lock-fancy is used but not available, either install it or adjust xss-lock to use i3lock.
EOF

echo "Done. Reload i3 with mod+shift+c or restart your session."
