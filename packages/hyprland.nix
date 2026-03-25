{ pkgs }:

with pkgs; [

  bc
  hyprland
  jq
  grim
  nwg-displays
  slurp
  hyprland-qt-support
  wlogout
  htop
  bat
  socat
  bottom
  eza
  fzf
  git
  swaynotificationcenter
  yazi
  btop
  nmap
  swww
  file
  wallust
  wl-clipboard
  hyprlock
  findutils
  imagemagick
  ffmpeg
  swww
  mpvpaper
  procps
  libnotify
  thunar
  alacritty
  kitty
  waybar
  hyprlock
  hyprpaper
  rofi
  wofi
  eww

  # KDE / Qt bridge
  hyprland-qt-support
  kdePackages.xdg-desktop-portal-kde
  qt6.qtwayland
  libsForQt5.qtwayland
]
