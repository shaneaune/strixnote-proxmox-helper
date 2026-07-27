# GPU Installation Guide

## Overview

StrixNote supports optional NVIDIA GPU acceleration for significantly faster transcription using the CUDA version of Faster Whisper.

This document describes the complete installation procedure used to create the reference GPU-enabled StrixNote VM. It also serves as the design reference for the GPU installation mode implemented in the Proxmox deployment script.

---

# Reference System

The reference installation was built using the following hardware and software.

## Host

- Proxmox VE 9
- PCIe GPU passthrough enabled
- IOMMU enabled
- VFIO configured

## Guest VM

- Debian 12 (Bookworm)
- UEFI Boot
- VirtIO SCSI
- Q35 Machine Type

## GPU

NVIDIA Quadro P2000

The installer is intended to support most NVIDIA Pascal or newer GPUs capable of CUDA acceleration.

---

# Installation Overview

The GPU installation differs from the CPU installation in only a few areas.

CPU Mode

- Standard Docker installation
- Whisper runs on CPU
- No NVIDIA software installed

GPU Mode

- NVIDIA driver installed
- NVIDIA Container Toolkit installed
- Docker configured for GPU runtime
- Worker container built from CUDA image
- Whisper configured to use CUDA

---

# Required Packages

The following packages are installed inside the VM.

```bash
apt install -y \
    docker.io \
    docker-compose \
    git \
    linux-headers-cloud-amd64 \
    firmware-misc-nonfree \
    nvidia-driver \
    dkms \
    ca-certificates \
    curl \
    gnupg2
```

---

# NVIDIA Container Toolkit

After installing the NVIDIA driver, install the NVIDIA Container Toolkit repository.

Repository:

https://nvidia.github.io/libnvidia-container/stable/deb/

Install the toolkit.

```bash
apt install -y nvidia-container-toolkit
```

Configure Docker.

```bash
nvidia-ctk runtime configure --runtime=docker
```

Restart Docker.

```bash
systemctl restart docker
```

---

# Docker Runtime

The Docker daemon should report the NVIDIA runtime.

```bash
docker info
```

Expected runtime:

```
Runtimes:
    io.containerd.runc.v2
    nvidia
    runc
```

---

# Worker Container

The transcription worker uses a CUDA runtime image instead of the CPU image.

Reference image:

```Dockerfile
FROM nvidia/cuda:12.2.2-cudnn8-runtime-ubuntu22.04
```

This image already contains the required CUDA runtime libraries.

No CUDA Toolkit is installed inside the VM.

Running:

```bash
nvcc --version
```

should return:

```
command not found
```

This is expected.

---

# Docker Compose

The worker container requires the NVIDIA runtime.

Example:

```yaml
runtime: nvidia
```

No additional runtime configuration is required.

---

# Whisper Configuration

The following environment variables were verified to work correctly on the reference system.

```
WHISPER_MODEL=medium.en
WHISPER_DEVICE=cuda
WHISPER_COMPUTE=int8
```

## Important

These values were determined experimentally for the reference hardware.

Specifically:

- NVIDIA Quadro P2000
- CUDA runtime
- Faster Whisper

Other GPUs may perform better with different compute types.

Future versions of the installer may expose these settings as configurable options.

---

# Verification

Verify the NVIDIA driver.

```bash
nvidia-smi
```

Expected result:

- GPU detected
- Driver loaded
- CUDA version displayed

---

Verify Docker.

```bash
docker run --rm --runtime=nvidia nvidia/cuda:12.2.2-cudnn8-runtime-ubuntu22.04 nvidia-smi
```

The GPU should be visible inside the container.

---

Verify StrixNote.

Upload a short audio file.

Confirm:

- Worker starts normally
- Transcription completes successfully
- GPU utilization increases while transcription is running

GPU utilization can be monitored with:

```bash
watch -n1 nvidia-smi
```

---

# Troubleshooting

## nvidia-smi reports "No devices found"

Possible causes:

- PCI passthrough not configured
- Incorrect VM hardware configuration
- Driver not installed
- IOMMU disabled

---

## Docker cannot access GPU

Verify:

```bash
docker info
```

The NVIDIA runtime should appear.

Restart Docker if necessary.

```bash
systemctl restart docker
```

---

## Worker falls back to CPU

Verify:

```
WHISPER_DEVICE=cuda
```

Also verify that the worker container was built from the CUDA base image.

---

# Installer Implementation

The Proxmox helper script should perform the following when GPU mode is selected.

- Configure PCI passthrough
- Install NVIDIA driver
- Install NVIDIA Container Toolkit
- Configure Docker runtime
- Build CUDA worker image
- Configure Docker Compose for NVIDIA runtime
- Configure Whisper to use CUDA
- Verify GPU functionality before completing installation

CPU installations should skip all GPU-specific steps.

---

# Future Improvements

Potential future enhancements include:

- Automatic CUDA capability detection
- Automatic compute type selection
- Multiple GPU selection
- AMD ROCm support
- Intel GPU support
- GPU benchmarking after installation
- Optional GPU stress test