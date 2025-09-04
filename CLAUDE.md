# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository contains Google Cloud Engine (GCE) startup scripts for automated instance provisioning with a complete development environment. The main workflow is creating Ubuntu-based GCE instances with pre-installed development tools, R, Python, Docker, and personal dotfiles.

## Architecture

The repository consists of two main shell scripts that work together:

- **`create.sh`** - Instance provisioning script that uses gcloud CLI to create GCE instances with specified configuration
- **`startupscript.sh`** - Startup script that runs on the instance after creation to install software and configure the environment

### Key Components

1. **Instance Creation Flow** (`create.sh:30-44`):
   - Downloads startup script from GitHub 
   - Retrieves service account information
   - Creates Ubuntu 24.04 LTS instance with specified machine type
   - Configures DNS zone metadata and HTTP server tags

2. **Environment Setup** (`startupscript.sh:30-112`):
   - Installs development tools (git, neovim, tmux, docker, etc.)
   - Sets up R environment with CRAN repository
   - Installs Python development packages and Poetry
   - Clones and deploys personal dotfiles from GitHub
   - Installs Rust tools via cargo

3. **DNS Management** (`startupscript.sh:122-158`):
   - Updates Cloud DNS records with current public/private IP addresses
   - Uses Google Cloud DNS API to maintain hostname-to-IP mappings
   - Supports both external (.e.) and internal (.i.) subdomain records

## Common Commands

### Creating a new GCE instance:
```bash
sh create.sh instance-name machine-type
```
Example: `sh create.sh hello e2-small`

### Configuration Variables

Key settings in `create.sh` that may need modification:
- `PROJECT_NAME` (line 4): GCP project ID
- `DNS_ZONE_NAME` (line 5): Cloud DNS zone name  
- `STARTUP_SCRIPT_URL` (line 6): GitHub raw URL for startup script

Key settings in `startupscript.sh`:
- `USERNAME` (line 3): Target user for dotfiles installation
- `DNS_ZONE_NAME` (line 4): Must match create.sh setting
- `ZONE` (line 5): DNS zone domain

## Prerequisites

Before running scripts:
- Configure HTTP port 80 access in GCE console for RStudio
- Set up SSH keys in GCE console
- Ensure gcloud CLI is configured with appropriate permissions
- Use Google Cloud Shell for execution

## Logging

Startup script execution logs can be found at:
- Ubuntu: `/var/log/syslog`
- Debian: `/var/log/daemon.log` 
- CentOS/RHEL: `/var/log/messages`
- SLES: `/var/log/messages`