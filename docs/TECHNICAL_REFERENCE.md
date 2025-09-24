# YOLOsandbox: Comprehensive Feature Documentation

**Last Updated:** August 11, 2025 | **Version:** 2.1

## TL;DR

- **One-line installation**: Complete setup in 30 seconds with `curl | bash`
- **AI agents can code autonomously but safely**: Claude Code and Gemini CLI pre-installed
- **Complete isolation from host**: Only `/workspace` accessible, everything else protected
- **Pre-configured security**: No manual setup required - capability drops, resource limits, and filesystem isolation work out of the box

## Table of Contents

1. [Purpose](#purpose)
2. [Why This Design Is Simple](#why-this-design-is-simple)
3. [Architecture Overview](#architecture-overview)
4. [Security Features - Explicitly Configured](#security-features---explicitly-configured)
   - [4.1 Linux Capability Restrictions](#41-linux-capability-restrictions)
   - [4.2 Resource Limits](#42-resource-limits)
   - [4.3 Filesystem Access Control](#43-filesystem-access-control)
   - [4.4 Environment Configuration](#44-environment-configuration)
   - [4.5 User Permissions](#45-user-permissions)
   - [4.6 Network Configuration](#46-network-configuration)
5. [Docker Default Security Features (Relied Upon)](#docker-default-security-features-relied-upon)
6. [Development Environment Features](#development-environment-features)
7. [What AI Agents Can Safely Do](#what-ai-agents-can-safely-do)
8. [What the Sandbox Prevents](#what-the-sandbox-prevents)
9. [Security Test Suite Validation](#security-test-suite-validation)
10. [Threat Mitigation Analysis](#threat-mitigation-analysis)
11. [Troubleshooting Guide](#troubleshooting-guide)
12. [Areas for Potential Enhancement](#areas-for-potential-enhancement)
13. [Conclusion](#conclusion)

<a id="purpose"></a>
## 1. Purpose

This document provides a complete, accurate analysis of every YOLOsandbox feature, with each claim directly tied to configuration files, Docker defaults, or test-verified behaviors. This serves as the authoritative reference for understanding why AI agents can safely run unsupervised in this environment.

[↑ Back to top](#table-of-contents)

<a id="why-this-design-is-simple"></a>
## 2. Why This Design Is "Simple"

### Single Rule Security Model

**The One Rule**: "AI can do anything in `/workspace`, nothing outside"

This is enforced by:
- Mount configuration (only `/workspace` accessible)
- Read-only overlays (config protection)
- Capability drops (system protection)
- Resource limits (DoS protection)

### Zero Configuration Required

```bash
# Complete installation in 30 seconds
curl -sSL https://raw.githubusercontent.com/YOLOsandbox/simple-sandbox/main/init.sh | bash
```

No need to:
- Edit security policies
- Configure user permissions
- Set up networking
- Install dependencies

### Familiar Environment

- Standard Ubuntu 24.04 LTS
- Normal bash shell
- Common development tools
- Standard filesystem layout

[↑ Back to top](#table-of-contents)

<a id="architecture-overview"></a>
## 3. Architecture Overview

### Security Layers Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     Host System (Protected)                  │
├─────────────────────────────────────────────────────────────┤
│                    Docker Engine + Seccomp                   │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐    │
│  │              YOLOsandbox Container                  │    │
│  │  ┌─────────────────────────────────────────────┐   │    │
│  │  │     Capability Restrictions (DROP ALL)      │   │    │
│  │  │     + Limited caps (CHOWN, SETUID, SETGID)  │   │    │
│  │  ├─────────────────────────────────────────────┤   │    │
│  │  │   Resource Limits (CPU: 4, RAM: 8GB)       │   │    │
│  │  ├─────────────────────────────────────────────┤   │    │
│  │  │   User: developer (non-root, limited sudo) │   │    │
│  │  ├─────────────────────────────────────────────┤   │    │
│  │  │   /workspace (your code - read/write)      │   │    │
│  │  └─────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Volume Mount Hierarchy

```
Host Filesystem                    Container Filesystem(s)
├── project-root/                  /workspace/ (read-write)
│   ├── docker/          ─────►    ├── docker/ (read-only)
│   ├── .devcontainer/   ─────►    ├── .devcontainer/ (read-only)
│   ├── claude-data/     ─────►    /home/developer/.claude/
│   └── [your code]      ─────►    └── [your code] (read-write)
└── [protected]                    [not accessible]
```

**Multiple Instance Support**: Multiple containers can safely mount the same project directory simultaneously. Each container gets a unique name (e.g., `yolosandbox_myapp_12345678_simple-sandbox_1`, `yolosandbox_myapp_12345678_simple-sandbox_2`) while sharing the same mounted directories.

[↑ Back to top](#table-of-contents)

---

<a id="security-features---explicitly-configured"></a>
## 4. Security Features - Explicitly Configured

<a id="41-linux-capability-restrictions"></a>
### 4.1 Linux Capability Restrictions

**Configuration Source**: `docker/docker-compose.yml` lines 13-20

```yaml
cap_drop:
  - ALL
cap_add:
  - CHOWN         # Change file ownership
  - SETGID        # Required for sudo to work properly
  - SETUID        # Required for sudo to work properly
```

#### Understanding the Three Allowed Capabilities

**CAP_CHOWN - File Ownership Control Within Container**:
- **What it allows**: Change file ownership within the container filesystem
- **What it does NOT allow**: 
  - Cannot change ownership of system files outside container
  - Cannot bypass read-only mounts (`/workspace/docker`, `/workspace/.devcontainer`)
  - Cannot modify ownership on host filesystem
- **Practical usage in sandbox**: Allows `chown developer:developer file.txt` within workspace

**CAP_SETUID - Required for Sudo Functionality**:
- **What it allows**: Required for sudo to temporarily switch user ID to root
- **What it does NOT allow**:
  - Cannot become arbitrary users beyond sudo configuration
  - Cannot bypass sudoers restrictions
  - Cannot escalate to full root (sudo limited to apt commands only)
- **Practical usage in sandbox**: Essential component enabling `sudo apt-get install` functionality

**CAP_SETGID - Required for Sudo Functionality**:
- **What it allows**: Required for sudo to temporarily switch group ID during execution
- **What it does NOT allow**:
  - Cannot join privileged host groups
  - Cannot bypass container group isolation
  - Cannot access host group-restricted resources
- **Practical usage in sandbox**: Works with SETUID to enable complete sudo functionality for apt commands

#### Critical Capabilities Explicitly Denied

By dropping ALL capabilities first, the sandbox explicitly denies:
- **CAP_SYS_ADMIN**: No mount operations, namespace creation, or system administration
- **CAP_NET_ADMIN**: No network interface configuration, routing changes, or firewall rules
- **CAP_NET_RAW**: No raw sockets, packet crafting, or ping operations
- **CAP_DAC_OVERRIDE**: Cannot bypass file permissions (must respect all chmod/ownership)
- **CAP_SYS_MODULE**: Cannot load/unload kernel modules
- **CAP_SYS_PTRACE**: Cannot trace or debug processes outside container
- **CAP_SYS_TIME**: Cannot change system clock
- **CAP_MKNOD**: Cannot create device nodes
- **CAP_AUDIT_WRITE**: Cannot write to kernel audit log

<a id="42-resource-limits"></a>
### 4.2 Resource Limits

**Configuration Source**: `docker/docker-compose.yml` lines 71-88

```yaml
# CPU and Memory
deploy:
  resources:
    limits:
      cpus: '4'
      memory: 8G
    reservations:
      memory: 2G

# Process and File Limits  
ulimits:
  nproc: 1000      # Max processes
  nofile:
    soft: 4096     # Soft limit open files
    hard: 8192     # Hard limit open files
  memlock:
    soft: -1       # Unlimited memory lock
    hard: -1
```

**Protection Against**:
- Fork bombs (capped at 1000 processes)
- Memory exhaustion (capped at 8GB)
- CPU monopolization (capped at 4 cores)
- File descriptor exhaustion (capped at 8192)

<a id="43-filesystem-access-control"></a>
### 4.3 Filesystem Access Control

**Configuration Source**: `docker/docker-compose.yml` lines 27-48

```yaml
volumes:
  # 1. The main read-write mount for the whole project
  - ..:/workspace

  # 2. Read-only "shields" placed on top of the sensitive subdirectories
  - type: bind
    source: ../docker
    target: /workspace/docker
    read_only: true
  - type: bind
    source: ../.devcontainer
    target: /workspace/.devcontainer
    read_only: true

  # 3. The claude-data mount for session persistence
  - ../claude-data:/home/developer/.claude

# tmpfs mounts for apt cache and lib (required for apt to work without DAC_OVERRIDE)
tmpfs:
  - /var/cache/apt
  - /var/lib/apt
```

#### Volume Mount Path Resolution

**Note**: All paths in docker-compose.yml are relative to the docker/ directory.

- `..` resolves to the project root directory
- `../docker` resolves to the project's docker configuration directory
- `../.devcontainer` resolves to the project's VS Code devcontainer configuration
- `../claude-data` resolves to the project root's claude-data directory for AI session data

**Access Matrix**:
| Path | Access | Purpose |
|------|--------|---------|
| `/workspace/*` | Read/Write | Project files |
| `/workspace/docker/` | Read-Only | Prevent config tampering |
| `/workspace/.devcontainer/` | Read-Only | Prevent VS Code config changes |
| `/home/developer/.claude/` | Read/Write | AI session persistence |
| `/var/cache/apt/` | tmpfs | In-memory filesystem for apt temp files |
| `/var/lib/apt/` | tmpfs | In-memory filesystem for apt temp files |
| Everything else | Container default | Isolated from host |

<a id="44-environment-configuration"></a>
### 4.4 Environment Configuration

**Configuration Source**: `docker/.env` (referenced in `docker/docker-compose.yml` lines 54-55)

The `docker/.env` file contains critical environment variables:

```bash
# Unique project naming to allow multiple sandbox instances
COMPOSE_PROJECT_NAME=generic_ai_devcontainer_e936da05

# User ID matching for proper file permissions
UID=1000
GID=1000
```

**Key Configuration Details**:
- **COMPOSE_PROJECT_NAME**: Provides unique container naming to enable multiple sandbox instances
- **UID/GID**: Matches host user permissions for seamless file access
- **Dynamic Container Naming**: docker-compose.yml has commented out `container_name` (line 9) to allow dynamic naming via COMPOSE_PROJECT_NAME
- **File Creation**: This file is automatically created by the init scripts during setup

<a id="45-user-permissions"></a>
### 4.5 User Permissions

**Configuration Source**: `Dockerfile` lines 19-33

```dockerfile
ARG UID=1000
ARG GID=1000

# Remove the default ubuntu user if it exists (Ubuntu 24.04 includes it)
RUN userdel -r ubuntu 2>/dev/null || true

# Create a non-root user with sudo privileges using specified UID/GID
RUN groupadd -g ${GID} developer && \
    useradd -m -s /bin/bash -u ${UID} -g ${GID} developer && \
    # Grant sudo access ONLY to the system package manager
    echo "developer ALL=(ALL) NOPASSWD: /usr/bin/apt-get, /usr/bin/apt, /usr/bin/true" >> /etc/sudoers

# Configure apt to work without CAP_FOWNER by disabling sandboxing
RUN echo 'APT::Sandbox::User "root";' > /etc/apt/apt.conf.d/99sandbox-disable
```

**User Security Configuration**:
- Default `ubuntu` user removed for security (only `developer` user exists)
- Runs as non-root user `developer` (UID 1000)
- Sudo access LIMITED to: `developer ALL=(ALL) NOPASSWD: /usr/bin/apt-get, /usr/bin/apt, /usr/bin/true`
- Cannot run arbitrary commands as root
- Cannot modify system configuration via sudo

**APT Sandbox Configuration**:
- APT configured with `APT::Sandbox::User "root"` to disable sandboxing
- Configured to work without CAP_FOWNER (file ownership override capability)
- Allows APT to function with the available CHOWN, SETUID, SETGID capabilities
- Enables package management operations within security constraints

<a id="46-network-configuration"></a>
### 4.6 Network Configuration

**Configuration Source**: `docker/docker-compose.yml` lines 50, 65

```yaml
network_mode: bridge
sysctls:
  - net.ipv4.ip_forward=1
```

**Network Capabilities**:
- ✅ HTTP/HTTPS outbound requests
- ✅ DNS resolution
- ✅ Package repository access
- ❌ Raw sockets (no CAP_NET_RAW)
- ❌ Ping/ICMP (ping binary installed but non-functional without CAP_NET_RAW capability)
- ❌ Network interface configuration (no CAP_NET_ADMIN)
- ❌ Packet sniffing (no CAP_NET_RAW)

[↑ Back to top](#table-of-contents)

---

<a id="docker-default-security-features-relied-upon"></a>
## 5. Docker Default Security Features (Relied Upon)

### 5.1 Namespace Isolation

**Source**: Docker default behavior (not explicitly configured)

Docker automatically provides:
- **PID namespace**: Container processes isolated from host
- **Network namespace**: Separate network stack
- **Mount namespace**: Independent filesystem view
- **IPC namespace**: Isolated inter-process communication
- **UTS namespace**: Separate hostname and domain

**Test Verification**: `test_process_isolation.sh` confirms:
- Host processes not visible in container
- Container PID 1 is container's init process
- Cannot signal host processes

### 5.2 Seccomp Filtering

**Source**: Docker default seccomp profile (not explicitly configured)

Docker applies a default seccomp profile that blocks:
- Kernel keyring operations
- Obsolete system calls
- Clock adjustments
- Module loading operations

### 5.3 cgroup Isolation

**Source**: Docker default (not explicitly configured)

Docker automatically:
- Creates separate cgroups for container
- Enforces resource limits via cgroups
- Isolates container from host cgroups

[↑ Back to top](#table-of-contents)

---

<a id="development-environment-features"></a>
## 6. Development Environment Features

### 6.1 Pre-installed Tools

**Configuration Source**: `Dockerfile` lines 6-15, 35-51

| Tool | Version | Install Method | Purpose |
|------|---------|----------------|---------|
| Ubuntu | 24.04 LTS | Base image | Operating system |
| Python | 3.11 | UV (`uv python install 3.11`) | Python development |
| Node.js | v22 | NVM (`nvm install 22`) | JavaScript runtime |
| UV | Latest | curl installer | Python package management |
| NVM | 0.40.3 | curl installer | Node version management |
| Git | System | apt | Version control |
| curl/wget | System | apt | File downloads |
| nano/vim | System | apt | Text editing |
| Claude Code | Latest | npm global | AI assistant CLI |
| Gemini CLI | Latest | npm global | AI assistant CLI |

### 6.2 Docker Configuration Details

**Configuration Source**: `Dockerfile` lines 57-69

**NVM Bash Completion Setup**:
```dockerfile
# Add nvm initialization to .bashrc for new shell sessions
RUN echo 'export NVM_DIR="$HOME/.nvm"' >> /home/developer/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /home/developer/.bashrc && \
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> /home/developer/.bashrc
```
- Enables tab completion for NVM commands in bash shells
- Automatically loads NVM in new shell sessions
- Improves developer experience with NVM command completion

**Shell Configuration**:
```dockerfile
SHELL ["/bin/bash", "-c"]
```
- Sets the default shell for all subsequent RUN commands to bash
- Ensures consistent shell behavior during container build process
- Required for proper execution of bash-specific syntax in Dockerfile commands

**Default Container Entry Point**:
```dockerfile
CMD ["/bin/bash"]
```
- Container starts with a bash shell by default
- Provides immediate interactive access when entering the container
- Standard behavior for development containers

### 6.3 Package Management Capabilities

**Python via UV**:
```bash
uv pip install <package>    # Install Python packages
uv run python script.py     # Run Python scripts
uv python list             # List Python versions
```

**Node.js via NPM**:
```bash
npm install <package>      # Install Node packages
npm install -g <tool>      # Install global tools
npx <tool>                # Run Node tools
```

**System via APT** (with sudo):
```bash
sudo apt-get update
sudo apt-get install <package>
```

### 6.4 Deployment and Initialization Scripts

**Configuration Source**: `/workspace/init.sh` and `/workspace/init-local.sh`

YOLOsandbox provides two initialization scripts for different deployment scenarios:

#### 6.4.1 Remote Deployment Script (`init.sh`)

**Purpose**: One-line installation from GitHub repository

**Authentication Support**:
- **Public repositories**: No authentication required
- **Private repositories**: Supports GitHub token authentication via `.env` file or environment variable
- Token usage: `GITHUB_TOKEN=your_token_here`

**Command-line Options**:
```bash
-n, --non-interactive     # Skip all prompts, use defaults
-t, --run-tests, --test   # Run test suite after initialization 
-v, --verbose             # Enable verbose test output
--stop-after-tests        # Stop container after tests complete
-h, --help                # Display help message
```

**Usage Examples**:
```bash
# One-line remote installation
curl -sSL https://raw.githubusercontent.com/YOLOsandbox/simple-sandbox/main/init.sh | bash

# Remote installation with options
curl -sSL https://raw.githubusercontent.com/YOLOsandbox/simple-sandbox/main/init.sh | bash -s -- -n -t

# Install to specific directory
curl -sSL https://raw.githubusercontent.com/YOLOsandbox/simple-sandbox/main/init.sh | bash -s -- /my/project

# Full automation: non-interactive, run tests, then stop
curl -sSL https://raw.githubusercontent.com/YOLOsandbox/simple-sandbox/main/init.sh | bash -s -- -n -t --stop-after-tests
```

**Functionality**:
- Downloads all necessary files from GitHub repository
- Creates directory structure (`docker`, `.devcontainer`, `claude-data`)
- Generates `docker/.env` with unique project configuration
- Downloads optional files (devcontainer.json, .dockerignore, documentation)
- Supports private repository access via GitHub tokens
- Integrates with VS Code Dev Containers
- Includes comprehensive error handling and validation

#### 6.4.2 Local Development Script (`init-local.sh`)

**Purpose**: Initialize sandbox from local template directory

**Command-line Options**: Same as `init.sh`

**Usage Examples**:
```bash
# Interactive mode in current directory
./init-local.sh

# Initialize in specific directory
./init-local.sh /path/to/project

# Non-interactive with custom template
./init-local.sh -n /my/project /path/to/template

# Run tests after initialization  
./init-local.sh -t

# Full automation with verbose output
./init-local.sh -n -t -v --stop-after-tests /tmp/test-sandbox
```

**Functionality**:
- Copies files from local template directory instead of downloading
- Same command-line interface as remote script
- Template validation (checks for required Docker files)
- Useful for development, testing, and offline scenarios
- Preserves all functionality of remote script but works locally

#### 6.4.3 Shared Features

**Project Configuration**:
- Generates unique `COMPOSE_PROJECT_NAME` using path-based hashing: `yolosandbox_${project-name}_${8-char-hash}`
- Path hash ensures projects with same name in different locations get unique containers
- Matches host `UID` and `GID` for proper file permissions
- Creates `.env` with project-specific settings for container identification

**Container Management**:
- Builds and starts container automatically (with `-t` flag)
- Downloads and executes comprehensive test suite
- Supports verbose test output and container lifecycle management
- Option to stop container after testing for CI/CD scenarios

**Prerequisites Checking**:
- Validates Docker installation
- Validates Docker Compose availability (supports both `docker-compose` and `docker compose`)
- Provides helpful error messages with installation links

[↑ Back to top](#table-of-contents)

### 6.5 Multiple Instance Support

**Purpose**: Enable developers to run multiple sandbox instances without conflicts

YOLOsandbox automatically prevents container naming conflicts through intelligent project identification:

#### 6.5.1 Cross-Project Instance Isolation

Each project directory gets a unique container name using path-based hashing:

**Naming Pattern**: `yolosandbox_${project-name}_${8-char-path-hash}`

**Examples**:
- `/home/alice/my-app/` → `yolosandbox_my-app_a1b2c3d4`
- `/home/bob/my-app/` → `yolosandbox_my-app_e5f6g7h8` (different path = different hash)
- `/projects/web-app/` → `yolosandbox_web-app_x9y8z7w6`

This allows developers to work on multiple projects simultaneously without Docker container conflicts.

#### 6.5.2 Same-Project Multiple Instances

VS Code Dev Containers support multiple instances from the same project:

**Use Cases**:
- Multiple VS Code windows for the same project
- Different development contexts (frontend/backend)
- Parallel development workflows

**Container Naming**: `yolosandbox_project_hash_simple-sandbox_N`
- First instance: `yolosandbox_myapp_12345678_simple-sandbox_1`
- Second instance: `yolosandbox_myapp_12345678_simple-sandbox_2`

#### 6.5.3 Developer Benefits

- **No Manual Configuration**: Unique naming happens automatically
- **Workflow Flexibility**: Work on multiple projects simultaneously  
- **VS Code Integration**: Native support for multiple dev container windows
- **Session Isolation**: Each container has independent processes and filesystem
- **Backward Compatible**: Existing single-instance workflows unchanged

[↑ Back to top](#table-of-contents)

---

<a id="what-ai-agents-can-safely-do"></a>
## 7. What AI Agents Can Safely Do

### 7.1 Code Development Operations

**Allowed by Configuration**:
```bash
# Write any code in workspace
echo "print('Hello')" > /workspace/script.py

# Execute scripts
uv run python /workspace/script.py
node /workspace/server.js

# Modify permissions
chmod +x /workspace/script.sh

# Create directories
mkdir -p /workspace/project/src
```

### 7.2 Network Operations

**Allowed by bridge networking + no blocking**:
```bash
# API calls
curl https://api.github.com/repos/user/repo

# Download files
wget https://example.com/data.zip

# Clone repositories
git clone https://github.com/project/repo.git

# Package installation
uv pip install requests
npm install express
```

### 7.3 System Administration

**Allowed within container boundaries**:
```bash
# Process management
python server.py &
jobs
kill %1

# Environment setup
export API_KEY="value"
echo "export PATH=$PATH:/workspace/bin" >> ~/.bashrc

# Package management (via sudo)
sudo apt-get update
sudo apt-get install postgresql-client
```

### 7.4 Common AI Agent Workflows and Integration Examples

#### 7.4.1 AI-Assisted Development Workflows

**Claude Code Integration Examples**:
```bash
# Start Claude Code session in sandbox
code /workspace  # Opens VS Code with Dev Container support
claude --help  # Pre-installed CLI for AI assistance

# Typical AI development workflow
1. AI analyzes existing codebase
2. AI creates/modifies files in /workspace
3. AI runs tests and validates changes
4. AI commits changes via git
```

**Gemini CLI Usage Patterns**:
```bash
# Use Gemini for code analysis
gemini --help  # Pre-installed alternative AI CLI

# Example workflow
gemini "Analyze this Python code for optimization opportunities"
gemini "Generate unit tests for the user_manager.py module"
gemini "Refactor this function to use async/await pattern"
```

**Autonomous Code Generation and Testing**:
```bash
# AI can safely perform complete development cycles
mkdir -p /workspace/new-project/tests
echo "# AI-generated application" > /workspace/new-project/README.md

# Install dependencies
uv pip install pytest flask
npm install express jest

# Run tests automatically
pytest /workspace/new-project/tests/
npm test
```

**Multi-file Refactoring Workflows**:
```bash
# AI can safely perform large-scale refactoring
grep -r "old_function_name" /workspace/src/
sed -i 's/old_function_name/new_function_name/g' /workspace/src/*.py

# Update imports across multiple files
find /workspace -name "*.py" -exec sed -i 's/from old_module/from new_module/g' {} +

# Validate changes with tests
python -m pytest /workspace/tests/
```

#### 7.4.2 VS Code/Cursor Integration

**Dev Container Benefits**:
```json
// .devcontainer/devcontainer.json automatically configures:
{
  "name": "YOLOsandbox - ${localWorkspaceFolderBasename}",
  "dockerComposeFile": "../docker/docker-compose.yml",
  "service": "simple-sandbox",
  "workspaceFolder": "/workspace",
  "containerEnv": {
    "INSTANCE_ID": "${localEnv:VSCODE_PID:-${localEnv:RANDOM}}"
  },
  "customizations": {
    "vscode": {
      "settings": {
        "terminal.integrated.defaultProfile.linux": "bash"
      }
    }
  },
  "remoteUser": "developer",
  "updateRemoteUserUID": true,
  "shutdownAction": "none"
}
```

**Containerized AI Development Benefits**:
- **Isolation**: AI experiments don't affect host system
- **Reproducibility**: Same environment across different machines
- **Safety**: AI can install packages without system pollution
- **Consistency**: Standard toolchain (Python 3.11, Node v22) guaranteed

**Multiple Dev Container Instances**:
```bash
# Developer can open multiple VS Code windows from same project
# Each gets its own container instance automatically
code .  # First window → container instance 1
code .  # Second window → container instance 2
```

**Benefits**:
- Independent terminal sessions and processes
- Separate development contexts within same project
- No manual container management required

**Persistent Session Data**:
```bash
# AI session data persists across container restarts
ls /home/developer/.claude/  # Claude Code session data
echo "export MY_CONFIG=value" >> ~/.bashrc  # Shell customizations persist

# Project files persist automatically
/workspace/  # All work persists on host filesystem
```

#### 7.4.3 CI/CD Integration

**Running Tests in Sandbox**:
```bash
# Initialize sandbox for CI/CD
curl -sSL https://raw.githubusercontent.com/YOLOsandbox/simple-sandbox/main/init.sh | bash -s -- -n -t --stop-after-tests

# Example CI pipeline step
- name: Run tests in sandbox
  run: |
    docker-compose -f docker/docker-compose.yml up -d
    docker-compose -f docker/docker-compose.yml exec simple-sandbox pytest /workspace/tests/
    docker-compose -f docker/docker-compose.yml down
```

**Automated Code Review Workflows**:
```bash
# AI can safely analyze pull requests
git clone $PR_REPO /workspace/review-target
cd /workspace/review-target

# Run security analysis
bandit -r /workspace/review-target/
semgrep --config=auto /workspace/review-target/

# Performance analysis
py-spy top --pid $(pgrep python) --duration 30
```

**Safe Execution of Untrusted Code**:
```bash
# Sandbox isolates untrusted code execution
git clone https://github.com/untrusted/repo.git /workspace/untrusted
cd /workspace/untrusted

# Install dependencies safely
uv pip install -r requirements.txt  # Isolated to container
npm install  # No impact on host npm global packages

# Execute untrusted code safely
python suspicious_script.py  # Cannot escape container
```

#### 7.4.4 Data Science Workflows

**Jupyter Notebook Support via UV**:
```bash
# Install Jupyter in isolated environment
uv pip install jupyter pandas numpy matplotlib scikit-learn

# Start Jupyter server
jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser --allow-root

# Access from host browser at localhost:8888
# Notebooks saved to /workspace persist automatically
```

**Package Experimentation Without System Pollution**:
```bash
# Try experimental packages safely
uv pip install tensorflow-nightly
uv pip install torch-geometric-nightly

# Different Python environments
uv python install 3.9
uv python install 3.12
uv venv --python=3.9 /workspace/env-39
```

**Model Training in Isolation**:
```bash
# Resource-limited model training
# Automatically limited to 4 CPU cores and 8GB RAM
python train_model.py  # Cannot consume unlimited resources

# GPU passthrough (if host has GPU)
# Add to docker-compose.yml:
# deploy:
#   resources:
#     reservations:
#       devices:
#         - driver: nvidia
#           count: 1
#           capabilities: [gpu]
```

[↑ Back to top](#table-of-contents)

---

<a id="what-the-sandbox-prevents"></a>
## 8. What the Sandbox Prevents

### 8.1 Operations Blocked by Capability Drops

| Attempted Operation | Error | Missing Capability |
|-------------------|-------|-------------------|
| `ping google.com` | Operation not permitted | CAP_NET_RAW (binary installed but non-functional) |
| `mount /dev/sdb1 /mnt` | Permission denied | CAP_SYS_ADMIN |
| `tcpdump -i eth0` | Permission denied | CAP_NET_RAW |
| `insmod module.ko` | Permission denied | CAP_SYS_MODULE |
| `ip link set eth0 down` | Permission denied | CAP_NET_ADMIN |
| `iptables -A INPUT -j DROP` | Permission denied | CAP_NET_ADMIN |
| `strace -p 1` | Permission denied | CAP_SYS_PTRACE |

### 8.2 Operations Blocked by Resource Limits

| Attempted Operation | Result | Limit Hit |
|-------------------|---------|-----------|
| Fork bomb `:(){ :|:& };:` | Stops at 1000 processes | ulimit nproc: 1000 |
| Allocate 10GB RAM | OOM killer activates at 8GB | memory: 8G |
| Open 10000 files | Fails after 8192 | ulimit nofile: 8192 |
| Use 8 CPU cores | Limited to 4 cores | cpus: '4' |
| Crypto mining at full capacity | Throttled to 4 cores | cpus: '4' |

### 8.3 Operations Blocked by Filesystem Configuration

| Attempted Operation | Result | Reason |
|-------------------|---------|---------|
| `rm /workspace/docker/Dockerfile` | Read-only filesystem | read_only: true mount |
| `rm -rf /workspace/.devcontainer` | Read-only filesystem | read_only: true mount |
| `echo "hack" > /etc/passwd` | Changes only container copy | Mount namespace isolation |
| `cat /home/hostuser/.ssh/id_rsa` | No such file or directory | Not mounted in container |
| `dd if=/dev/sda of=disk.img` | No such file or directory | Block devices not mounted |
| `ln -s /host/etc/passwd /workspace/pw` | Cannot create symlink | Host filesystem not accessible |

### 8.4 Operations Blocked by Sudo Restrictions

| Attempted Operation | Result | Reason |
|-------------------|---------|---------|
| `sudo bash` | Sorry, not allowed | Not in sudoers |
| `sudo systemctl restart` | Sorry, not allowed | Not in sudoers |
| `sudo chmod 777 /etc` | Sorry, not allowed | Not in sudoers |
| `sudo visudo` | Sorry, not allowed | Not in sudoers |
| `sudo usermod -aG docker developer` | Sorry, not allowed | Not in sudoers |
| `sudo apt-get install vim` | Success | Explicitly allowed in sudoers |

[↑ Back to top](#table-of-contents)

---

<a id="security-test-suite-validation"></a>
## 9. Security Test Suite Validation

### Test Coverage

| Test File | Validates | Key Checks |
|-----------|-----------|------------|
| `test_environment.sh` | Development tools | Python/UV, Node/NPM, AI CLI tools, workspace access, network, package management |
| `test_security.sh` | Security features | Linux capabilities, filesystem isolation, sudo restrictions, container isolation, resource limits |
| `test_persistence.sh` | Data persistence | Claude data directory, session persistence, ownership verification |

### Test Commands for Manual Verification

To verify each security feature yourself, run these commands:

**Capability Verification**:
```bash
# Run the container to verify capabilities are properly restricted
docker-compose -f docker/docker-compose.yml exec simple-sandbox bash -c "
  echo 'Testing capability restrictions...'

  # This should fail (no CAP_NET_RAW)
  ping -c 1 google.com 2>&1 | grep -q 'Operation not permitted' && echo 'PASS: ping blocked' || echo 'FAIL: ping not blocked'

  # Mount should fail (no CAP_SYS_ADMIN)
  mount -t tmpfs tmpfs /mnt 2>&1 | grep -q 'Operation not permitted' && echo 'PASS: mount blocked' || echo 'FAIL: mount allowed'
"
```

**Filesystem Isolation Verification**:
```bash
# Run filesystem isolation test
docker-compose -f docker/docker-compose.yml exec simple-sandbox bash -c "
  echo 'Testing filesystem isolation...'
  
  # Should fail - read-only mount
  touch /workspace/docker/test.txt 2>&1 | grep -q 'Read-only file system' && echo 'PASS: docker dir read-only' || echo 'FAIL: docker dir writable'
  
  # Should fail - read-only mount  
  touch /workspace/.devcontainer/test.txt 2>&1 | grep -q 'Read-only file system' && echo 'PASS: devcontainer dir read-only' || echo 'FAIL: devcontainer dir writable'
  
  # Should work - read-write access
  touch /workspace/test.txt && rm /workspace/test.txt && echo 'PASS: workspace writable' || echo 'FAIL: workspace not writable'
"
```

**Resource Limits Verification**:
```bash
# Check resource limits are applied
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep simple-sandbox

# Verify process limits inside container
docker-compose -f docker/docker-compose.yml exec simple-sandbox bash -c "
  echo 'Process limit:' && ulimit -u
  echo 'File descriptor limit:' && ulimit -n
  echo 'Memory available:' && free -h | grep Mem
"
```

**Network Security Verification**:
```bash
# Run network connectivity test
docker-compose -f docker/docker-compose.yml exec simple-sandbox bash -c "
  echo 'Testing network security...'
  
  # Should work - HTTP/HTTPS allowed
  curl -s -I https://google.com | head -1 | grep -q '200 OK' && echo 'PASS: HTTPS works' || echo 'FAIL: HTTPS blocked'
  
  # Should work - DNS resolution
  nslookup google.com >/dev/null 2>&1 && echo 'PASS: DNS works' || echo 'FAIL: DNS blocked'
  
  # Should fail - ping blocked (no CAP_NET_RAW)
  ping -c 1 google.com 2>&1 | grep -q 'Operation not permitted' && echo 'PASS: ping blocked' || echo 'FAIL: ping not blocked'
"
```

**Development Tools Verification**:
```bash
# Verify all development tools are available
docker-compose -f docker/docker-compose.yml exec simple-sandbox bash -c "
  echo 'Python/UV:' && uv --version
  echo 'Node.js:' && node --version  
  echo 'NPM:' && npm --version
  echo 'Git:' && git --version
  echo 'Claude Code:' && claude --version 2>/dev/null || echo 'claude available'
  echo 'Gemini CLI:' && gemini --version 2>/dev/null || echo 'gemini available'
  
  # Test sudo restrictions
  sudo apt-get --version >/dev/null && echo 'PASS: sudo apt works' || echo 'FAIL: sudo apt blocked'
  sudo bash 2>&1 | grep -q 'not allowed' && echo 'PASS: sudo bash blocked' || echo 'FAIL: sudo bash allowed'
"
```

### Security Validation Results

**From test execution**:
- ✅ 100% host process isolation verified
- ✅ No access to host block devices confirmed
- ✅ Ping blocked (CAP_NET_RAW restriction working)
- ✅ HTTP/HTTPS connectivity functional
- ✅ Sudo restrictions properly enforced
- ✅ Resource limits enforced

[↑ Back to top](#table-of-contents)

---

<a id="threat-mitigation-analysis"></a>
## 10. Threat Mitigation Analysis

### 10.1 Accidental Damage Prevention

| Accident Type | Prevention Mechanism | Configuration Source |
|--------------|---------------------|---------------------|
| Delete system files | Only `/workspace` mounted | docker/docker-compose.yml:30 |
| Exhaust host memory | 8GB limit | docker/docker-compose.yml:76 |
| Fork bomb | 1000 process limit | docker/docker-compose.yml:82 |
| Corrupt host network | Network namespace isolation | Docker default |
| Kill host processes | PID namespace isolation | Docker default |

### 10.2 Malicious Attack Prevention

| Attack Vector | Prevention | Configuration Source |
|--------------|------------|---------------------|
| Container escape via Docker socket | Socket not mounted | Not in volumes config |
| Kernel exploitation | No CAP_SYS_ADMIN | docker/docker-compose.yml:14 |
| Network sniffing | No CAP_NET_RAW | docker/docker-compose.yml:14 |
| Privilege escalation | Limited sudo | Dockerfile:30 |
| Host filesystem access | Mount namespace | Docker default |
| Resource DoS | Hard resource limits | docker/docker-compose.yml:72-88 |

[↑ Back to top](#table-of-contents)

---

<a id="troubleshooting-guide"></a>
## 11. Troubleshooting Guide

### 11.1 Common Issues and Solutions

#### Container Won't Start

**Issue**: `docker-compose -f docker/docker-compose.yml up -d` fails with various errors

**Check Docker Daemon**:
```bash
# Verify Docker is running
docker info
sudo systemctl status docker  # On systemd systems

# Start Docker if not running
sudo systemctl start docker
```

**Check Disk Space**:
```bash
# Check available disk space
df -h

# Clean Docker system if needed
docker system prune -f
docker image prune -a
```

**Check Port Conflicts**:
```bash
# If using port mappings, check for conflicts
netstat -tlnp | grep :8080  # Check if port is in use
lsof -i :8080  # Alternative port check
```

#### Permission Denied Errors

**Issue**: Files created in container have wrong ownership

**Verify UID/GID Match**:
```bash
# Check host user ID
id

# Check container configuration
cat docker/.env

# Fix if needed
echo "UID=$(id -u)" > docker/.env
echo "GID=$(id -g)" >> docker/.env
docker-compose -f docker/docker-compose.yml down && docker-compose -f docker/docker-compose.yml up -d --build
```

**Fix Existing File Permissions**:
```bash
# Fix ownership of workspace files
sudo chown -R $(id -u):$(id -g) /path/to/your/workspace

# Fix claude-data permissions
sudo chown -R $(id -u):$(id -g) claude-data/
```

#### Package Installation Fails

**Issue**: `sudo apt-get install` or `uv pip install` fails

**Check Network Connectivity**:
```bash
# Test from within container
docker-compose -f docker/docker-compose.yml exec simple-sandbox curl -I https://google.com
docker-compose -f docker/docker-compose.yml exec simple-sandbox nslookup google.com
```

**Update Package Lists**:
```bash
# Refresh apt cache
docker-compose -f docker/docker-compose.yml exec simple-sandbox sudo apt-get update

# Clear UV cache if needed
docker-compose -f docker/docker-compose.yml exec simple-sandbox uv cache clean
```

**Corporate Firewall Issues**:
```bash
# Configure proxy if needed (add to Dockerfile)
ENV http_proxy=http://proxy.company.com:8080
ENV https_proxy=http://proxy.company.com:8080
```

#### VS Code Won't Connect

**Issue**: "Cannot connect to container" or Dev Container extension fails

**Ensure Docker Extension Installed**:
1. Install "Docker" extension in VS Code
2. Install "Dev Containers" extension in VS Code
3. Restart VS Code after installation

**Check Container Status**:
```bash
# Verify container is running
docker ps | grep simple-sandbox

# Check container logs
docker-compose -f docker/docker-compose.yml logs simple-sandbox
```

**Rebuild Dev Container**:
```bash
# In VS Code Command Palette (Ctrl+Shift+P):
# > Dev Containers: Rebuild Container

# Or manually rebuild
docker-compose -f docker/docker-compose.yml down
docker-compose -f docker/docker-compose.yml up -d --build
```

### 11.2 Verification Commands

#### Container Health Checks

```bash
# Check container is running
docker ps | grep simple-sandbox

# Verify resource limits are applied
docker stats simple-sandbox

# Check container configuration
docker inspect $(docker-compose -f docker/docker-compose.yml ps -q simple-sandbox)
```

#### Security Verification

```bash
# Verify capability restrictions work by testing blocked operations
docker-compose -f docker/docker-compose.yml exec simple-sandbox ping -c 1 google.com
# Should fail with "Operation not permitted"

docker-compose -f docker/docker-compose.yml exec simple-sandbox mount -t tmpfs tmpfs /mnt
# Should fail with "Operation not permitted"

# Test capability restrictions work
docker-compose -f docker/docker-compose.yml exec simple-sandbox ping -c 1 google.com
# Should fail with "Operation not permitted"
```

#### Network Connectivity Tests

```bash
# Test outbound HTTP/HTTPS
docker-compose -f docker/docker-compose.yml exec simple-sandbox curl -I https://google.com

# Test DNS resolution
docker-compose -f docker/docker-compose.yml exec simple-sandbox nslookup github.com

# Test package repository access
docker-compose -f docker/docker-compose.yml exec simple-sandbox sudo apt-get update
```

#### Tool Availability Verification

```bash
# Verify Python/UV installation
docker-compose -f docker/docker-compose.yml exec simple-sandbox uv --version
docker-compose -f docker/docker-compose.yml exec simple-sandbox uv python list

# Verify Node.js/NPM installation
docker-compose -f docker/docker-compose.yml exec simple-sandbox node --version
docker-compose -f docker/docker-compose.yml exec simple-sandbox npm --version

# Verify AI CLI tools
docker-compose -f docker/docker-compose.yml exec simple-sandbox claude --version
docker-compose -f docker/docker-compose.yml exec simple-sandbox gemini --version
```

### 11.3 Performance Tuning

#### Adjusting Resource Limits

**For High-Memory Workloads**:
```yaml
# Edit docker/docker-compose.yml
deploy:
  resources:
    limits:
      cpus: '8'      # Increase CPU limit
      memory: 16G    # Increase memory limit
    reservations:
      memory: 4G     # Increase memory reservation
```

**For CPU-Intensive Tasks**:
```yaml
# Allow more CPU cores
limits:
  cpus: '8'  # Or whatever your system can spare
```

#### Optimizing for AI Model Execution

**GPU Support** (if available):
```yaml
# Add to docker-compose.yml under simple-sandbox service
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: 1
          capabilities: [gpu]
```

**Shared Memory for Large Models**:
```yaml
# Add to docker-compose.yml
shm_size: 2gb  # Increase shared memory
```

#### Managing Disk Usage

**Monitor claude-data Growth**:
```bash
# Check claude-data directory size
du -sh claude-data/

# Clean old session data if needed
find claude-data/ -type f -mtime +30 -delete
```

**Container Image Cleanup**:
```bash
# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune
```

### 11.4 Debug Commands

#### Container Inspection

```bash
# View container logs
docker-compose -f docker/docker-compose.yml logs -f simple-sandbox

# Get shell access for debugging
docker-compose -f docker/docker-compose.yml exec simple-sandbox /bin/bash

# Inspect running processes in container
docker-compose -f docker/docker-compose.yml exec simple-sandbox ps aux

# Check environment variables
docker-compose -f docker/docker-compose.yml exec simple-sandbox env | sort
```

#### Mount Point Verification

```bash
# Verify all mounts are correct
docker-compose -f docker/docker-compose.yml exec simple-sandbox mount | grep workspace

# Check read-only mounts are working
docker-compose -f docker/docker-compose.yml exec simple-sandbox ls -la /workspace/docker/
docker-compose -f docker/docker-compose.yml exec simple-sandbox touch /workspace/docker/test.txt  # Should fail
```

#### Resource Usage Monitoring

```bash
# Monitor container resource usage
docker stats simple-sandbox

# Check process limits inside container
docker-compose -f docker/docker-compose.yml exec simple-sandbox ulimit -a

# Monitor disk I/O
docker-compose -f docker/docker-compose.yml exec simple-sandbox iostat 1

# Check memory usage
docker-compose -f docker/docker-compose.yml exec simple-sandbox free -h
```

#### Network Debugging

```bash
# Check container network configuration
docker-compose -f docker/docker-compose.yml exec simple-sandbox ip addr show

# Test specific endpoints
docker-compose -f docker/docker-compose.yml exec simple-sandbox telnet pypi.org 443
docker-compose -f docker/docker-compose.yml exec simple-sandbox wget -O /dev/null https://registry.npmjs.org/

# Check DNS configuration
docker-compose -f docker/docker-compose.yml exec simple-sandbox cat /etc/resolv.conf
```

[↑ Back to top](#table-of-contents)

---

<a id="areas-for-potential-enhancement"></a>
## 12. Areas for Potential Enhancement

### 12.1 Additional Security Measures (Not Currently Implemented)

1. **Network Egress Filtering**
   - Current: All outbound allowed
   - Potential: Domain allowlist

2. **Audit Logging**
   - Current: No command logging
   - Potential: Log all executed commands

3. **Read-only Package Directories**
   - Current: Packages writable
   - Potential: Immutable after install

4. **Time-based Limits**
   - Current: No time limits
   - Potential: Auto-terminate after X hours

### 12.2 Questions for Specific Use Cases

**For Regulated Industries (HIPAA/PCI)**:
- Need encryption at rest?
- Require audit trails?
- Need data loss prevention?

**For Multi-tenant Scenarios**:
- Need per-tenant resource accounting?
- Require separate containers per session?
- Need network isolation between tenants?

**For Production Deployment**:
- Need Kubernetes orchestration?
- Require monitoring integration?
- Need high availability?

[↑ Back to top](#table-of-contents)

---

<a id="conclusion"></a>
## 13. Conclusion

YOLOsandbox achieves its security goals through:

1. **Explicit configuration** of capabilities, resources, and mounts
2. **Docker defaults** for namespace and cgroup isolation
3. **Kernel enforcement** rather than application-level restrictions
4. **Simplicity** in both setup and mental model

The sandbox is production-ready for its intended use case: allowing AI agents to write, test, and execute code autonomously while protecting the host system from both accidental and malicious damage.

Every security claim in this document is traceable to:
- Specific configuration lines (with file and line numbers)
- Docker default behaviors (clearly marked)
- Test suite verification (with test file references)

---

