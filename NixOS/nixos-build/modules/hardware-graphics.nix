# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#
# HARDWARE-GRAPHICS.NIX — Base Mesa / VA-API acceleration
# ========================================================
# Enables hardware-accelerated rendering and 32-bit graphics libs
# (required for Steam and most games).
# GPU-specific driver config lives in modules/gpu.nix and its sub-modules.

{ ... }:
{
  hardware.graphics.enable      = true;
  hardware.graphics.enable32Bit = true;
}
