``` id="2v18cf"
+--------------------------------------------------------------------------------+
|      /\___/\        ____  _        _      _   _       _                        |
|     /  o o  \      / ___|| |_ _ __(_)_  _| \ | | ___ | |_ ___                  |
|    |   \^/   |     \___ \| __| '__| \ \/ /  \| |/ _ \| __/ _ \                 |
|    |  (___)  |      ___) | |_| |  | |>  <| |\  | (_) | ||  __/                 |
|    |  /   \  |     |____/ \__|_|  |_/_/\_\_| \_|\___/ \__\___|                 |
|    |_/|_|_|\_|                                                                 |
+--------------------------------------------------------------------------------+
```
# StrixNote Proxmox Helper

The StrixNote Proxmox Helper automates the creation of a Debian 12 virtual machine and installs StrixNote with optional NVIDIA GPU acceleration.

## Features

- Creates a new Debian 12 virtual machine
- Downloads and configures a Debian 12 cloud image
- Automatically detects available storage and network bridges
- Optional NVIDIA GPU passthrough
- Optional NVIDIA driver installation
- Automatic reboot and installation resume during GPU installations
- Installs all required software and StrixNote
- Minimal user interaction

## Requirements

- Proxmox VE host
- Internet connection

### GPU Install Requirements

For NVIDIA GPU installations:

- IOMMU enabled on the Proxmox host
- NVIDIA GPU with CUDA support
- The GPU must not already be assigned to another virtual machine

The helper script automatically configures GPU passthrough for the new virtual machine.

## Usage

Run the latest version directly:

```bash
bash <(curl -s https://raw.githubusercontent.com/shaneaune/strixnote-proxmox-helper/feature/gpu-acceleration/proxmox-create-strixnote-vm.sh)
```

Follow the on-screen prompts.

## What the Helper Does

Depending on the options selected, the helper script will:

- Create a new Debian 12 virtual machine
- Configure CPU, memory, storage, and networking
- Configure GPU passthrough (optional)
- Clone the appropriate StrixNote branch
- Launch the StrixNote installer
- Monitor the installation process
- Automatically reconnect after required reboots
- Resume the installation until it completes

## Notes

- The first installation may take 15–30 minutes depending on your hardware and internet connection.
- During GPU installations the virtual machine will automatically reboot once. This is expected.
- If the console appears blank while the helper is running, press **Enter** to refresh the display.