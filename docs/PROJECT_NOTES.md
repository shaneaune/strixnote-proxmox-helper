# Project Notes

## Purpose

This document contains internal development notes for the StrixNote Proxmox Helper project.

Unlike the README or installation documentation, this file records design decisions, implementation details, known limitations, future ideas, and lessons learned during development.

---

# Project Goals

The primary goal is to provide a single script that installs StrixNote on Proxmox with minimal user interaction.

Supported installation modes:

- CPU
- NVIDIA GPU

The installer should produce a fully working system without requiring manual post-install configuration.

---

# Design Philosophy

The installer should:

- Require as little Linux knowledge as possible.
- Validate all user input.
- Explain what it is doing.
- Fail with useful error messages.
- Be safe to rerun when practical.
- Avoid hidden configuration.

---

# GPU Support

GPU mode should automatically reproduce the reference GPU installation.

The installer should:

- Detect available NVIDIA GPUs.
- Allow the user to select one.
- Configure PCI passthrough.
- Install NVIDIA drivers.
- Install NVIDIA Container Toolkit.
- Configure Docker.
- Configure StrixNote for CUDA.

GPU-specific implementation details are documented in `GPU_INSTALL.md`.

---

# Current Features

- CPU installation
- GPU installation
- Automatic VM creation
- Storage selection
- Bridge selection
- Branch selection
- Secure Boot detection
- GPU selection
- GPU audio device passthrough
- Input validation
- Automatic Docker installation

---

# Known Limitations

## NVIDIA Only

AMD ROCm and Intel GPU acceleration are not currently supported.

---

## Single GPU

Only one GPU may be selected during installation.

---

## Whisper Configuration

The installer currently uses known-good Whisper settings.

These may not be optimal for every GPU.

Future versions may expose these as user-configurable options.

---

# Future Improvements

## Installation

- Automatic updates
- Backup existing installations
- Uninstall option
- Repair option
- Upgrade option

---

## GPU

- Multiple GPU support
- Automatic compute type selection
- CUDA capability detection
- GPU benchmark
- GPU stress test

---

## User Interface

- Progress bars
- Better color output
- Improved summaries
- More detailed validation messages

---

# Lessons Learned

## Always Validate User Input

Invalid storage names, bridge names, VM IDs, memory values, and ports should be caught before any changes are made.

---

## Prefer Automatic Detection

Whenever possible, detect configuration automatically instead of asking the user.

Examples include:

- Storage
- Network bridges
- Available GPUs
- Secure Boot
- Existing VM IDs

---

## Keep CPU and GPU Logic Together

The installer should remain a single script.

GPU mode should extend CPU mode rather than creating a separate installer.

This minimizes duplicated code and simplifies maintenance.

---

# Coding Standards

- Keep functions small.
- Prefer descriptive variable names.
- Validate before modifying.
- Exit immediately on fatal errors.
- Display clear status messages.
- Avoid duplicated code.

---

# Testing Checklist

Before every release:

- CPU installation
- GPU installation
- Existing VM detection
- Invalid input handling
- Docker startup
- StrixNote startup
- Web interface accessibility
- Whisper transcription
- GPU detection (GPU mode)
- README updated
- Documentation updated

---

# Release Checklist

Before publishing a release:

- Update version number.
- Test both installation modes.
- Verify documentation.
- Push all commits.
- Create GitHub release.
- Update screenshots if necessary.