
#!/usr/bin/env bash
set -euo pipefail

INSTALL_STARTED=0

cleanup_vm() {
  if [[ "$INSTALL_STARTED" -eq 0 ]]; then
    echo "Cleaning up incomplete VM $VMID..."
    qm destroy "$VMID" --purge >/dev/null 2>&1 || true
  else
    echo
    echo "Installation failed, but VM has been kept for debugging."
    echo "You can access it with:"
    echo "  qm terminal $VMID"
    echo "  or SSH if networking is up"
  fi
}

trap cleanup_vm ERR

log_step() {
  echo
  echo "--------------------------------------------------"
  echo "$1"
  echo "--------------------------------------------------"
}

select_timezone() {
  echo
  echo "Select your region:"

  REGIONS=($(ls /usr/share/zoneinfo | grep -E '^[A-Z]' | grep -v '^Factory$' | sort))

  select REGION in "${REGIONS[@]}" "Manual entry"; do
    if [[ -z "$REGION" ]]; then
      echo "Invalid selection."
      continue
    fi

    if [[ "$REGION" == "Manual entry" ]]; then
      read -rp "Enter timezone (e.g. America/Vancouver): " TZ
      echo "$TZ"
      return
    fi

    break
  done

  echo
  echo "Select your city:"

  CITIES=($(ls "/usr/share/zoneinfo/$REGION"))

  select CITY in "${CITIES[@]}"; do
    if [[ -z "$CITY" ]]; then
      echo "Invalid selection."
      continue
    fi

    TZ="$REGION/$CITY"
    echo "$TZ"
    return
  done
}

echo "StrixNote Proxmox VM Helper"
echo
echo "Press Enter to accept the prepopulated default values."
echo "Some steps take a while so be paitent"
echo

if ! command -v qm >/dev/null 2>&1; then
  echo "ERROR: qm command not found. Run this on a Proxmox host."
  exit 1
fi

echo "Checking required packages..."

apt update
apt install -y curl git wget python3 libguestfs-tools

# --- Required input ---
read -rp "VM ID: " VMID
if [[ -z "${VMID}" ]]; then
  echo "ERROR: VM ID is required."
  exit 1
fi

if qm status "$VMID" >/dev/null 2>&1; then
  echo "ERROR: VM ID $VMID already exists."
  exit 1
fi

# --- Defaults with pre-filled input ---
NAME="StrixNote"

echo
echo "One moment I am looking for available VM disk storages:"

mapfile -t STORAGE_OPTIONS < <(
  awk '
    BEGIN {
      name = ""
      content = ""
      disabled = 0
    }

    /^[A-Za-z0-9_-]+:[[:space:]]+[A-Za-z0-9_.-]+/ {
      if (name != "" && content ~ /(^|,)[[:space:]]*images([[:space:]]*,|$)/ && disabled == 0) {
        print name
      }
      name = $2
      content = ""
      disabled = 0
      next
    }

    /^[[:space:]]*content[[:space:]]+/ {
      sub(/^[[:space:]]*content[[:space:]]+/, "")
      content = $0
      next
    }

    /^[[:space:]]*disable[[:space:]]+1/ {
      disabled = 1
      next
    }

    END {
      if (name != "" && content ~ /(^|,)[[:space:]]*images([[:space:]]*,|$)/ && disabled == 0) {
        print name
      }
    }
  ' /etc/pve/storage.cfg | while read -r s; do
    if pvesm status 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$s"; then
      echo "$s"
    fi
  done
)

if [[ "${#STORAGE_OPTIONS[@]}" -eq 0 ]]; then
  echo "ERROR: No online storages found that support VM disk images."
  exit 1
fi

for i in "${!STORAGE_OPTIONS[@]}"; do
  printf "%d) %s\n" "$((i + 1))" "${STORAGE_OPTIONS[$i]}"
done

echo
read -e -i "1" -p "Choose storage number: " STORAGE_CHOICE

if ! [[ "$STORAGE_CHOICE" =~ ^[0-9]+$ ]]; then
  echo "ERROR: Storage choice must be a number."
  exit 1
fi

if (( STORAGE_CHOICE < 1 || STORAGE_CHOICE > ${#STORAGE_OPTIONS[@]} )); then
  echo "ERROR: Invalid storage choice."
  exit 1
fi

STORAGE="${STORAGE_OPTIONS[$((STORAGE_CHOICE - 1))]}"

if ! pvesm status 2>/dev/null | awk '{print $1}' | grep -qx "$STORAGE"; then
  echo "ERROR: Storage '$STORAGE' was not found."
  echo "Available storages:"
  pvesm status
  exit 1
fi

echo
echo "Available network bridges:"

mapfile -t BRIDGE_OPTIONS < <(
  ip -o link show | awk -F': ' '{print $2}' | grep '^vmbr'
)

if [[ "${#BRIDGE_OPTIONS[@]}" -eq 0 ]]; then
  echo "ERROR: No Proxmox bridges were found."
  exit 1
fi

if [[ "${#BRIDGE_OPTIONS[@]}" -eq 1 ]]; then
  BRIDGE="${BRIDGE_OPTIONS[0]}"
  echo "Using bridge: $BRIDGE"
else
  for i in "${!BRIDGE_OPTIONS[@]}"; do
    printf "%d) %s\n" "$((i + 1))" "${BRIDGE_OPTIONS[$i]}"
  done

  echo
  read -e -i "1" -p "Choose bridge number: " BRIDGE_CHOICE

  if ! [[ "$BRIDGE_CHOICE" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Bridge choice must be a number."
    exit 1
  fi

  if (( BRIDGE_CHOICE < 1 || BRIDGE_CHOICE > ${#BRIDGE_OPTIONS[@]} )); then
    echo "ERROR: Invalid bridge choice."
    exit 1
  fi

  BRIDGE="${BRIDGE_OPTIONS[$((BRIDGE_CHOICE - 1))]}"
fi

read -e -i "4" -p "CPU cores: " CORES
read -e -i "8192" -p "Memory in MB: " MEMORY
read -e -i "40" -p "Disk size in GB: " DISK_GB
read -e -i "8080" -p "Web UI port: " WEB_PORT

# --- Password prompts ---

# User password
while true; do
  read -s -p "User password: " USER_PASSWORD
  echo
  read -s -p "Confirm user password: " USER_PASSWORD_CONFIRM
  echo

  if [[ -z "$USER_PASSWORD" ]]; then
    echo "ERROR: Password cannot be empty."
    continue
  fi

  if [[ "$USER_PASSWORD" == "$USER_PASSWORD_CONFIRM" ]]; then
    break
  else
    echo "ERROR: Passwords do not match. Please try again."
  fi
done

# --- Timezone selection ---
echo
echo "Timezone (press Enter for default: America/Vancouver)"
read -rp "Use default timezone? [Y/n]: " USE_DEFAULT_TZ

if [[ "$USE_DEFAULT_TZ" =~ ^[Nn]$ ]]; then
  TIMEZONE="$(select_timezone)"
else
  TIMEZONE="America/Vancouver"
fi

echo "Selected timezone: $TIMEZONE"

echo
echo "Configuration:"
echo "  VM ID:    $VMID"
echo "  Name:     $NAME"
echo "  Storage:  $STORAGE"
echo "  Bridge:   $BRIDGE"
echo "  Cores:    $CORES"
echo "  Memory:   ${MEMORY} MB"
echo "  Disk:     ${DISK_GB} GB"
echo

read -rp "Create VM with these settings? [y/N]: " CONFIRM
case "${CONFIRM}" in
  y|Y|yes|YES) ;;
  *)
    echo "Cancelled."
    exit 0
    ;;
esac

# --- Test mode (skip VM creation) ---
if [[ "${TEST_MODE:-0}" == "1" ]]; then
  echo
  echo "TEST MODE: Skipping VM creation."
  echo "Collected settings are valid."
  exit 0
fi

# --- Stop after validation/selection (for fast testing) ---
if [[ "${STOP_AFTER_SELECTION:-0}" == "1" ]]; then
  echo
  echo "STOP_AFTER_SELECTION enabled."
  echo "Selections and validation completed successfully."
  exit 0
fi

log_step "Stage 1/8 - Creating VM shell"

qm create "$VMID" \
  --name "$NAME" \
  --machine q35 \
  --bios ovmf \
  --ostype l26 \
  --scsihw virtio-scsi-single \
  --agent 1 \
  --cpu host \
  --cores "$CORES" \
  --memory "$MEMORY" \
  --sockets 1 \
  --net0 virtio,bridge="$BRIDGE" \
  --serial0 socket \
  --vga serial0

log_step "Stage 2/8 - Adding EFI disk"
qm set "$VMID" --efidisk0 "${STORAGE}:1,efitype=4m,pre-enrolled-keys=1"

log_step "Stage 3/8 - Preparing Debian 12 cloud image"
echo "This step may take a few minutes the first time."
BASE_CLOUD_IMG="/var/lib/vz/template/iso/debian-12-genericcloud-amd64.qcow2"
VM_CLOUD_IMG="/tmp/debian-12-strixnote-${VMID}.qcow2"

if [[ ! -f "$BASE_CLOUD_IMG" ]]; then
  wget -O "$BASE_CLOUD_IMG" https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2
fi

echo "Creating VM-specific cloud image copy..."
cp "$BASE_CLOUD_IMG" "$VM_CLOUD_IMG"

echo "Customizing cloud image (installing guest agent and timezone)..."
echo "This may take a few minutes."
virt-customize -a "$VM_CLOUD_IMG" \
  --install qemu-guest-agent \
  --timezone "$TIMEZONE" \
  --run-command 'systemctl enable qemu-guest-agent' \
  --run-command 'systemctl start qemu-guest-agent || true'

log_step "Stage 4/8 - Importing VM disk into Proxmox storage"
echo "This may take a few minutes depending on storage speed."
qm importdisk "$VMID" "$VM_CLOUD_IMG" "$STORAGE"
rm -f "$VM_CLOUD_IMG"

log_step "Stage 5/8 - Attaching VM disk and cloud-init drive"
echo "Attaching main disk..."
qm set "$VMID" --scsi0 "${STORAGE}:vm-${VMID}-disk-1"

echo "Setting boot disk..."
qm set "$VMID" --boot order='scsi0'

echo "Adding cloud-init drive..."
qm set "$VMID" --scsi1 "${STORAGE}:cloudinit"

echo "Configuring cloud-init..."

SSH_KEY_FILE="/root/.ssh/id_ed25519.pub"

if [[ ! -f "$SSH_KEY_FILE" ]]; then
  echo "No SSH key found. Generating one..."
  mkdir -p /root/.ssh
  ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -q
fi

qm set "$VMID" \
  --ciuser user \
  --cipassword "$USER_PASSWORD" \
  --sshkeys "$SSH_KEY_FILE" \
  --ipconfig0 ip=dhcp \
  --nameserver 8.8.8.8 \
  --ciupgrade 1

log_step "Stage 6/8 - Finalizing VM disk size"
echo "Resizing VM disk..."
qm resize "$VMID" scsi0 "${DISK_GB}G"

log_step "Stage 7/8 - Booting VM"
echo "Starting VM..."
qm start "$VMID"

log_step "Stage 8/8 - Waiting for VM network and automated setup"
echo "Waiting for VM to obtain IP via guest agent..."
echo "This can take a minute or two on first boot."

VM_IP=""
for i in {1..60}; do
  VM_IP="$(qm guest cmd "$VMID" network-get-interfaces 2>/dev/null | \
    python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    for iface in data:
        for addr in iface.get("ip-addresses", []):
            ip = addr.get("ip-address")
            if addr.get("ip-address-type") == "ipv4" and ip != "127.0.0.1":
                print(ip)
                raise SystemExit
except Exception:
    pass
' || true)"

  if [[ -n "$VM_IP" ]]; then
    break
  fi

  sleep 2
done

if [[ -z "$VM_IP" ]]; then
  echo "ERROR: Could not determine VM IP via guest agent."
  exit 1
fi

echo "VM IP detected: $VM_IP"
echo "Waiting for SSH to become available..."

for i in {1..60}; do
  if ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null user@"$VM_IP" "echo ok" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo "Running automated guest setup..."
echo "This may take several minutes while packages install."
INSTALL_STARTED=1

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null user@"$VM_IP" <<EOF
sudo apt update
sudo apt install -y docker.io docker-compose git
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG sudo user
sudo usermod -aG docker user

if [ ! -d /home/user/strixnote ]; then
  git clone https://github.com/shaneaune/strixnote.git /home/user/strixnote
fi

echo "STRIXNOTE_WEB_PORT=$WEB_PORT" > /home/user/strixnote/.env
chown user:user /home/user/strixnote/.env

cd /home/user/strixnote
echo "Starting StrixNote installer inside the VM..."
sg docker -c "./install.sh"
EOF

echo "+--------------------------------------------------------------------------+"
echo "Your StrixNote installation is now complete"
echo "+--------------------------------------------------------------------------+"
echo
echo "Virtual Machine  Details:"
echo "  VM ID:   $VMID"
echo "  Name:    $NAME"
echo "  Memory:  ${MEMORY} MB"
echo "  Cores:   $CORES"
echo "  Disk:    ${DISK_GB} GB"
echo
echo "Automated VM provisioning and StrixNote installation completed successfully."
echo
echo "Access StrixNote at: http://$VM_IP:$WEB_PORT"
echo
