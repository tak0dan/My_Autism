#!/usr/bin/env bash
# /* ---- 💫 https://github.com/LinuxBeginnings 💫 ---- */  ##
# Simple bash script to check and update your system

iDIR="$HOME/.config/swaync/images"

# Check for required tools
if ! command -v kitty &> /dev/null; then
  notify-send -i "$iDIR/error.png" "Need Kitty:" "Kitty terminal not found."
  exit 1
fi

# -------- NixOS --------
if grep -q "NixOS" /etc/os-release 2>/dev/null; then
  notify-send -i "$iDIR/ja.png" -u low "NixOS" "Rebuilding system configuration..."

  if command -v nixorcist &> /dev/null; then
    kitty -T update -e sudo nixorcist rebuild || kitty -T update -e sudo nixos-rebuild switch --upgrade
  else
    kitty -T update -e sudo nixos-rebuild switch --upgrade
  fi

  exit 0
fi

# -------- Arch --------
if command -v paru &> /dev/null; then
  kitty -T update -e paru -Syu
  notify-send -i "$iDIR/ja.png" -u low "Arch-based system" "has been updated."

elif command -v yay &> /dev/null; then
  kitty -T update -e yay -Syu
  notify-send -i "$iDIR/ja.png" -u low "Arch-based system" "has been updated."

# -------- Fedora --------
elif command -v dnf &> /dev/null; then
  kitty -T update -e sudo dnf update --refresh -y
  notify-send -i "$iDIR/ja.png" -u low "Fedora system" "has been updated."

# -------- Debian --------
elif command -v apt &> /dev/null; then
  kitty -T update -e bash -c "sudo apt update && sudo apt upgrade -y"
  notify-send -i "$iDIR/ja.png" -u low "Debian/Ubuntu system" "has been updated."

# -------- openSUSE --------
elif command -v zypper &> /dev/null; then
  kitty -T update -e sudo zypper dup -y
  notify-send -i "$iDIR/ja.png" -u low "openSUSE system" "has been updated."

# -------- Unsupported --------
else
  notify-send -i "$iDIR/error.png" -u critical "Unsupported system" "This script does not support your distribution."
  exit 1
fi
