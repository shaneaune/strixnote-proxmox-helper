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
# StrixNote Proxmox VM Helper

Automated script to deploy StrixNote on Proxmox using a Debian 12 cloud image.

## Features

- Fully automated VM creation
- Debian 12 cloud image
- Automatic storage and bridge selection
- Installs Docker, Git, and StrixNote
- Minimal user input

## Requirements

- Proxmox VE host
- Internet connection

## Usage

Run directly on the Proxmox host:

```bash
git clone https://github.com/shaneaune/strixnote-proxmox-helper.git
cd strixnote-proxmox-helper
chmod +x proxmox-create-strixnote-vm.sh
./proxmox-create-strixnote-vm.sh
```

Or you can run the one line version

```bash
bash <(curl -s https://raw.githubusercontent.com/shaneaune/strixnote-proxmox-helper/main/proxmox-create-strixnote-vm.sh)
```

Follow the prompts.

## Notes
Some steps take several minutes (image download, package install)
If the console appears blank, press Enter
