{ pkgs }:

with pkgs; [

  # =========================
  # Core KDE Apps
  # =========================
  kdePackages.dolphin
  kdePackages.konsole
  kdePackages.kcalc
  kdePackages.ksystemlog
  kdePackages.discover

  # =========================
  # KDE Runtime / Frameworks (Qt6)
  # =========================
  kdePackages.frameworkintegration
  kdePackages.kconfig
  kdePackages.kcoreaddons
  kdePackages.kcmutils
  kdePackages.knewstuff

  # =========================
  # KDE Runtime / Frameworks (Qt5) ← CRITICAL
  # =========================
  libsForQt5.kconfig
  libsForQt5.kcoreaddons
  libsForQt5.kcmutils
  libsForQt5.knewstuff

  # Fixes: QtGraphicalEffects missing
  libsForQt5.qtgraphicaleffects

  # =========================
  # Plasma / Integration
  # =========================
  kdePackages.plasma-workspace
  kdePackages.plasma-integration
  kdePackages.kdeplasma-addons

  # =========================
  # KIO (file dialogs, admin, etc.)
  # =========================
  kdePackages.kio
  kdePackages.kio-admin
  kdePackages.kio-extras
  kdePackages.kservice

  # =========================
  # Theming
  # =========================
  kdePackages.breeze
  kdePackages.breeze-gtk
  kdePackages.breeze-icons

  # =========================
  # Qt Theming Tools
  # =========================
  libsForQt5.qt5ct
  qt6Packages.qt6ct
  nwg-look

    # ---------------------------
  # Qt6 KDE (modern)
  # ---------------------------
  kdePackages.knewstuff
  kdePackages.kcmutils
  kdePackages.kconfig
  kdePackages.kcoreaddons
  kdePackages.frameworkintegration

  # ---------------------------
  # Qt5 KDE (REQUIRED for KCMs)
  # ---------------------------
  libsForQt5.knewstuff
  libsForQt5.kcmutils
  libsForQt5.kconfig
  libsForQt5.kcoreaddons

  # 🔥 THIS FIXES YOUR ERROR
  libsForQt5.qtgraphicaleffects

  # stability deps (often missing)
  libsForQt5.kiconthemes
  libsForQt5.kio
]
