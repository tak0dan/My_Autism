# ZaneyOS Command Line Utility (zcli) - Version 1.0.1

zcli is a handy tool for performing common maintenance tasks on your ZaneyOS
system with a single command. Below is a detailed guide to its usage and
commands.

## Usage

Run the utility with a specific command:

`zcli`

If no command is provided, it displays this help message.

## Available Commands

Here’s a quick reference table for all commands, followed by detailed
descriptions:

| Command     | Icon | Description                                                                                                                                           | Example Usage                           |
| ----------- | ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------- |
| cleanup     | 🧹   | Removes old system generations, either all or by specifying a number to keep, helping free up space.                                                  | `zcli cleanup` (prompted for all or #)  |
| diag        | 🛠️   | Generates a system diagnostic report and saves it to `diag.txt` in your home directory.                                                               | `zcli diag`                             |
| list-gens   | 📋   | Lists user and system generations, showing active and existing ones.                                                                                  | `zcli list-gens`                        |
| rebuild     | 🔨   | Rebuilds the NixOS system configuration by checking for files that might prevent Home Manager from rebuilding.                                        | `zcli rebuild`                          |
| trim        | ✂️   | Trims filesystems to improve SSD performance and optimize storage.                                                                                    | `zcli trim`                             |
| update      | 🔄   | Updates the flake, checks for potential conflicts that might prevent Home Manager from rebuilding, and then rebuilds the system.                      | `zcli update`                           |
| update-host | 🏠   | Automatically sets the host and profile in your `flake.nix` file based on the current system. It detects the GPU type or prompts for input if needed. | `zcli update-host [hostname] [profile]` |

## Detailed Command Descriptions

- **🧹 cleanup**: This command helps manage system storage by removing old
  generations. You can remove all generations or specify a number to retain
  (e.g., `zcli cleanup` free's up space and removes the entries from boot menu.

- **🛠️ diag**: Creates a comprehensive diagnostic report by running
  `inxi --full` and saving the output to `diag.txt` in your home directory. This
  is ideal for troubleshooting or sharing system details when reporting issues.

- **📋 list-gens**: Displays a clear list of your current user and system
  generations, including active ones. This allows you to review what's installed
  and plan cleanups.

- **🔨 rebuild**: Performs a system rebuild for NixOS by first checking for any
  files that could block Home Manager from completing the process. It's similar
  to standard rebuild functions but with added safeguards.

- **✂️ trim**: Optimizes your filesystems, particularly for SSDs, to improve
  performance and reduce wear. Run this regularly as part of your maintenance
  routine.

- **🔄 update**: Streamlines updates by checking for potential issues with Home
  Manager, then updating the flake and rebuilding the system. This combines
  flake updates and rebuilds into one efficient step.

- **🏠 update-host**: Simplifies managing multiple hosts by automatically
  updating the `hostname` and `profile` in your `~/zaneyos/flake.nix` file. It
  attempts to detect your GPU type; if it fails, you'll be prompted to enter the
  details manually.

## Additional Notes

- **Why use zcli?** This utility saves time on routine tasks, reducing the need
  for multiple commands or manual edits.
- **Version and Compatibility:** Ensure you're using the latest version (1.0.1
  as per the source). For any issues, generate a diagnostic report with
  `zcli diag` and consult your system logs.
