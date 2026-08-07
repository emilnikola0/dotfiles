#!/usr/bin/env bash
set -euo pipefail

# Robust installer for my dotfiles (Debian/Ubuntu-like systems)
# Major improvements over previous version:
# - Refuse to run as root
# - Check for apt availability
# - Ensure essential helper packages are included (git, stow, python3-venv, fontconfig, curl, wget, build-essential)
# - Safer temp dir handling and cleanup via trap
# - Check for commands before using them and give clear warnings
# - Avoid running stow as root

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="${HOME}"
PACKAGES_FILE="$DOTFILES_DIR/packages.txt"

echo "Preparing system for dotfiles install..."

# Basic environment checks
if [ "$(id -u)" -eq 0 ]; then
  echo "Error: Do NOT run this script as root. Run as your normal user; the script will use sudo where needed." >&2
  exit 1
fi

if ! command -v apt >/dev/null 2>&1; then
  echo "Error: apt not found. This installer only supports apt-based systems (Debian/Ubuntu)." >&2
  exit 1
fi

if [ ! -f "$PACKAGES_FILE" ]; then
  echo "Error: packages.txt not found in $DOTFILES_DIR" >&2
  exit 1
fi

# Read packages.txt, ignore blank lines and full-line comments, strip inline comments and whitespace
mapfile -t PKGS < <(grep -E -v '^\s*($|#)' "$PACKAGES_FILE" | sed -E 's/\s+#.*$//' | sed -E 's/^\s+|\s+$//g' | grep -E -v '^$' || true)

# Ensure a few essential packages are present even if not listed
EXTRAS=(git stow python3-venv fontconfig curl wget build-essential neovim i3lock imagemagick pulseaudio-utils python3-pip flatpak thunar fonts-firacode)
for e in "${EXTRAS[@]}"; do
  found=false
  for p in "${PKGS[@]}"; do
    if [ "$p" = "$e" ]; then found=true; break; fi
  done
  if ! $found; then
    PKGS+=("$e")
  fi
done

# Deduplicate PKGS while preserving order
declare -A _seen
_unique_pkgs=()
for p in "${PKGS[@]}"; do
  if [ -n "$p" ] && [ -z "${_seen[$p]:-}" ]; then
    _seen[$p]=1
    _unique_pkgs+=("$p")
  fi
done
PKGS=("${_unique_pkgs[@]}")

if [ ${#PKGS[@]} -eq 0 ]; then
  echo "No packages to install. Check packages.txt." && exit 0
fi

echo "The following packages will be installed (apt):"
printf '  %s\n' "${PKGS[@]}"

# Update apt and install packages
echo "Updating apt and installing packages..."
sudo apt update
sudo apt install -y "${PKGS[@]}"

# Prepare cleanup for temporary directories
TMPDIRS=()
cleanup() {
  for d in "${TMPDIRS[@]:-}"; do
    if [ -n "$d" ] && [ -d "$d" ]; then
      rm -rf "$d" || true
    fi
  done
}
trap cleanup EXIT

# Install fonts (Meslo / Nerd Font) into local fonts if Meslo not present
if ! command -v fc-list >/dev/null 2>&1; then
  echo "Warning: fc-list not found (fontconfig). Some font installation checks may not work." >&2
fi
FONT_CHECK=$(fc-list 2>/dev/null | grep -i "Meslo" || true)
if [ -z "$FONT_CHECK" ]; then
  echo "Installing Meslo (Nerd Font) to $USER_HOME/.local/share/fonts..."
  mkdir -p "$USER_HOME/.local/share/fonts"
  tmpdir=$(mktemp -d)
  TMPDIRS+=("$tmpdir")
  # Try to fetch a Meslo patched font from Nerd Fonts repository. This may fail if URL/layout changes.
  if command -v git >/dev/null 2>&1; then
    git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git "$tmpdir/nerd-fonts" || true
    # Copy a few common Meslo files if present (best-effort)
    find "$tmpdir/nerd-fonts/patched-fonts" -type f -iname "*Meslo*" -exec cp -v {} "$USER_HOME/.local/share/fonts/" \; || true
  else
    echo "git not available to fetch nerd-fonts; skipping Meslo install from upstream." >&2
  fi
  # Refresh font cache
  fc-cache -f 2>/dev/null || true
fi

# Install i3blocks-contrib scripts used by config
if command -v git >/dev/null 2>&1; then
  echo "Installing i3blocks-contrib scripts..."
  TMP_I3BLOCKS=$(mktemp -d)
  TMPDIRS+=("$TMP_I3BLOCKS")
  git clone --depth 1 https://github.com/vivien/i3blocks-contrib.git "$TMP_I3BLOCKS" || true
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
else
  echo "Warning: git not available; skipping i3blocks-contrib installation." >&2
fi

# Set up i3blocks-mpris venv in the user's home
echo "Setting up i3blocks-mpris virtualenv..."
mkdir -p "$USER_HOME/.venvs"
if command -v python3 >/dev/null 2>&1 && python3 -m venv "$USER_HOME/.venvs/spotify-i3blocks" 2>/dev/null; then
  "$USER_HOME/.venvs/spotify-i3blocks/bin/python" -m pip install --upgrade pip setuptools wheel || true
  "$USER_HOME/.venvs/spotify-i3blocks/bin/pip" install i3blocks-mpris || true
else
  echo "Warning: python3 venv creation failed. Ensure python3-venv is installed and re-run." >&2
fi

# Ensure flatpak + flathub and install Spotify (best-effort)
if ! command -v flatpak >/dev/null 2>&1; then
  echo "Installing flatpak..."
  sudo apt install -y flatpak || true
fi
if command -v flatpak >/dev/null 2>&1; then
  if ! flatpak remote-list | grep -q flathub; then
    echo "Adding Flathub remote..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
  fi
  # Try installing Spotify via flatpak (non-fatal if it fails)
  flatpak install -y flathub com.spotify.Client || true
else
  echo "flatpak not available; skipping flatpak steps." >&2
fi

# Symlink dotfiles using stow (run as the invoking user)
echo "Symlinking dotfiles with stow..."
cd "$DOTFILES_DIR"
if ! command -v stow >/dev/null 2>&1; then
  echo "Warning: stow not found. Install stow (it was included in packages to install) or install it and re-run to create symlinks." >&2
else
  # Stow modules - prefer discovering directories to avoid hardcoding too much
  for d in */; do
    mod="${d%/}"
    # Skip common non-module files or directories
    case "$mod" in
      .git|.github|scripts|README*|LICENSE) continue ;;
    esac
    # Only attempt to stow directories that contain files
    if [ -d "$mod" ]; then
      echo "Stowing $mod..."
      stow "$mod" || true
    fi
  done
fi

# Post-install notes
cat <<EOF
Install complete (best-effort). Next manual steps you may want to perform:
- Check i3 and i3blocks configs for hard-coded paths like /home/<user>/ and replace them with \$HOME.
- Ensure scripts referenced by i3 (e.g. ~/.config/i3/scripts/toggletouchpad.sh, ~/.screenlayout/display-setup.sh) exist or add them to the repo.
- Add your wallpaper to the path referenced by i3 or update the config.
- If i3lock-fancy is used but not available, either install it or adjust xss-lock to use i3lock.

If something failed earlier in the script, review the warnings above and re-run after fixing missing dependencies.
EOF

echo "Done. Reload i3 with mod+shift+c or restart your session."
