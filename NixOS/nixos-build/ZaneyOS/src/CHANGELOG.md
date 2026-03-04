### 🗒️ Changelog

## ZaneyOS v2.3.3 -- Release Notes

** Updated: August 18th, 2025 **

- Fixed: Two issues in `install-zaneyos.sh` script prevented updating of
  `flake.nix`

- NeoVIM Enhancements:
  - Enhanced DirtytalkUpdate automation with smart detection to skip if wordlist
    exists
  - Added Nix LSP auto-eval-inputs support for better flake evaluation
  - Improved home.activation script with better error handling and DAG ordering
  - Programming wordlist is now automatically downloaded only when needed

- Added `rebuild-boot` command to `zcli`
  - New command rebuilds system and sets as boot default
  - Changes activate on next restart instead of immediately
  - Useful for testing configurations safely

- Added new waybars -`waybar-dwm.nix` -`waybar-dwm2.nix`
  - Inspired by Matt @TheLinuxCast
- `VirtualBox`
  - After user requests I added VirtualBox
  - It's in `~/zaneyos/modules/core/virtualisation.nix`
  - It is disabled by default
- `General Updates`
  - Updated flake
  - Update to `neovim` and `nvf` causes a prompt to download a dictionary
    - Enter `yes` then run `:DirtytalkUpdate` (case sensitive) to resolve it
      - No, I did not make up that command (nerd alert)
      - ** Update: ** Added a home.activation to run command to resolve it
  - Changed from `nvim-cmp` to `blink-cmp` for code completion
    - works better but has reputation for breaking time will tell
  - Changed version to ZaneyOS v2.3.3 in fastfetch
  - Added `tealdeer.nix` (TLDR)
  - Added `fzf.nix` to customize fzf util
  - Added preview to `fzf.nix` Enter to edit
  - Added `onefetch` to show current build info for zaneyos
  - Fixed 'hm-find' script was not being built
  - Added `lazygit.nix` to theme, customize lazygit util
  - Disabled the `df` command in the disk module. Doesn't work w/zaneyos
- `ZCLI Updates:`
  - Updated `zcli.nix` to v1.0 code cleanup, logging
  - Created `zcli` command `modules/home/scripts/zcli`
  - `zcli` will update flake, rebuild, run diags, garbage collect and fstrim
  - `zcli <COMMAND>` `rebuild` `update` `cleanup` `diags` `trim`
- `Yazi Updates:`
  - Added `BASH/ZSH/FISH` integration to `yazi`
  - Set `shellWrapperName = "yy";`
  - `yy` will start `yazi` and on exit leave you in current directory
  - This resolves issue where running `yazi` from rofi uses xterm
  - Merged yazi fix for errors after rebuilds. Thank you Daniel
  - Current `yazi` chg'd `manager` to `mgr` in `theme.toml` and `keymap.toml`
- `VSCODE Updates:`
  - Added `vscode.nix` with configured plugins
  - Thanks to `delciak` for the NIX code for `vscode.nix`
- `NeoVIM Updates:`
  - Enabled `neovim` and set it as `defaultEditor`
  - Restored relative line numbering to nvim `lineNumberMode = "relNumber";`
  - Fixed `css` formatting thanks to `mister_simon` for the fix
  - NVIM `languages.enableLSP` changed to `vim.settings.lsp.enable`
  - Removed extraneous LUA code for diags w/debug messages from `nvf.nix`
  - Re-enabled `language formater` `css` was disabled b/c rebuilds failed
  - Restored diagnostic messages inline as errors are detected
  - When you save a file the LSP will show any applicable hints
  - Updated `nvf.nix`to use a clipboard provider as "useSystemClipobard" is no
- `GIT Updates:`
  - Added options and aliases to `git.nix`
  - Added three more `git`aliases `com` commit a, `gs` stash, and `gp` pull
  - Run `gs com`, `git gs` and `git gp` to use them
- `EZA Updates:`
  - Moved aliases for `eza` to `eza.nix`
  - Now regardless of shell aliases will be same
  - Added `eza.nx` to configure basic eza settings
  - Added default features to `eza` in `eza.nix`
  - Allowing default behavior to be set on all shells
  - Added Shell integration for `eza` to `bash`, `zsh` and `fish`

- Modified zsh config

  ```nix
   syntaxHighlighting = {
        enable = true;
        highlighters = ["main" "brackets" "pattern" "regexp" "root" "line"];
      };
      historySubstringSearch.enable = true;

      history = {
        ignoreDups = true;
        save = 10000;
        size = 10000;
      };
  ```

- `Hyprland Updates:`
  - Disabled AQ_DRM_DEVICES env variable Retuned to default auto
  - Set `Virtual-1` monitior default to `1920x1080@60,auto,1`
  - Added `waybar-ddubs-2.nix` Modified version of Jerry's waybar
  - Adjusted some colors in Jerry's waybar
  - Added examples for monitor setup in `variables.nix`
  - Added Jerry's waybar as option. `Jerry-waybar.nix`
  - Added option to enable blur on waybar on `hyprland.nix` Thx SchotjeChrisman
  - Added new Window animation option `animation-moving`from ML4W repo
  - Fixed regression in `windowrules.nix`
  - Stylix was set to unstable - now 25.05 to stop mismatched version warning
  - Hyprland ENV variables were set in two files, now in `env.nix`
  - Hyprland animation files had `inherit`statements that weren't used
  - Pyprland drop down termina size changed from 75% to 70%
  - Disabled hyprland donation messages
  - Set `Application Not Responding (ANR)` dialog threshold to 20 (def 1)
  - Set `TERMINAL` and `XDG_TERMINAL_EMULATOR` to kitty in `env.nix`

- `GA Release Notes:`

  - With this release there are improvements to Neovim
  - The entire file structure has been improved.
  - Switched from nixvim to nvf for neovim configuration.
  - Improved bat config and includes extras now.
  - Added profiles for what kind of system you have based of GPU / VM.
  - Reduced the host specific files and made the entire flake more modular.
  - Fixed git getting set to wrong user settings.
  - Fixed hyprlock conflicting with stylix.
  - Setup`nh`in a better fashion.
  - Added support for `qmk` out of the box.
  - Added usbutils for lsusb functionality.
  - Massive improvement to Hyprland window rules.
  - Removed broken support for Apple Silicon (this may return).
  - Install script improved.
  - Fixed `nix flake check` not working.
  - Added nvidia prime PCI ID variables to host `variables.nix`.
  - Added vim keybindings zsh `(alt+hjkl)`.
  - Added `(ctrl+hjkl)` keybinds for vim movement while in insert mode in
    neovim.
  - Supports adb out of the box.
  - `Ddubs/dwilliam62` helped with the addition of pyprland and scratchpad
    support. He is now also a maintainer.
  - Can now summon a drop-down terminal with `SUPER, T`.
  - Added image used by Stylix into the host variables file.
  - Made printing and NFS variables so they can be easily toggled between hosts.
  - Added waybar styling choice.
  - Kitty, Wezterm, Neovim/nvf, and even Flatpaks all properly themed with
    Stylix.
  - Moved to hyprpolkitagent and fixed qt theming.
  - Stylix options that I wanted forced us back on the unstable branch.
  - Made Thunar an optional thing, enabled by default. _But for me Yazi is
    enough._

  </div>

  </details>

<br>
<details>
<summary><strong>**ZaneyOS v2.2**</strong> </summary>

<div style="margin-left: 20px;">

- This release has a big theming change
- Move back to rofi. It is a massive improvement in many ways.
- Revert the switch from rofi to wofi. Rofi is just better.
- Switch from Nix Colors to Stylix. It can build colorschemes from a wallpaper.
- Simplified the notification center.
- Improved emoji selection menu and options.
- Adding fine-cmdline plugin for Neovim.
- Removed theme changing scripts as the theme is generated by the image set with
  stylix.image in the config.nix file.
- Starship is now setup in the config.nix file.
- Switched from SDDM to tuigreet and greetd.
- Added Plymouth for better looking booting.
- Improve the fonts being installed and properly separate them from regular
  packages.
- Separated Neovim configuration for readability.
- Updated flake and added fix for popups going to wrkspc 1 in Hyprland.
- Removed a few of the packages that aren't necessary and smartd by default.
- Removed unnecessary Hyprland input in flake as home manager doesn't use it.
- Turned off nfs by default.
- Hyprland plugins are now disabled in the config by default.
- Fastfetch is now replacing neofetch.
- Btop is back baby!
- Switching to Brave as the default to protect user privacy.
- Replaced lsd with eza for a better looking experience.

</div>

</details>
<br>

<details>

<summary><strong>**ZaneyOS v2.1**</strong></summary>

<div style="margin-left: 20px;">

Simple bug fixes.

- Fixed Waybar icons to make them look a bit better.
- Centered the Wofi window always.
- Should have fixed some Steam issues, but I have had some crashes due to Steam
  so be aware of that.
- The flake got an update, so all the packages are fresh.

</div>

</details>

<br>

<details>

<summary><strong>**ZaneyOS v2.0** </strong></summary>

<div style="margin-left: 20px;">

With this new update of ZaneyOS it is a big rewrite of how things are being
done. This update fixes many issues that you guys were facing. As well as makes
things a little easier to understand. You now have a lot being stored inside the
specific host directory, making use of modules, condensing seperate files down,
etc. My hope is that with this update your ability to grasp the flake and expand
it to what you need is much improved. I want to thank everyone for being so
supportive!

- Most configuration put into specific hosts directories for the best
  portability.
- Using modules to condense configuration complexity.
- Simplified options and the complexity around understanding their
  implementation.
- Rewrote the documentation for improved readability.

</div>

</details>
