FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set default timezone (can be overridden at runtime)
ENV TZ=UTC

# Install minimal system dependencies
RUN apt-get update && apt-get install -y \
    iputils-ping \
    dnsutils \
    curl \
    wget \
    sudo \
    git \
    nano \
    vim \
    tzdata



# Accept UID and GID as build arguments with defaults
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

# Install UV for Python management as developer user
USER developer
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/home/developer/.local/bin:${PATH}"

# Initialize UV and install Python
RUN /home/developer/.local/bin/uv python install 3.11

# Install nvm, Node.js, and install global AI tools in a single RUN command
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash && \
    export NVM_DIR="$HOME/.nvm" && \
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && \
    nvm install 22 && \
    nvm alias default 22 && \
    nvm use default && \
    npm install -g @anthropic-ai/claude-code && \
    npm install -g @google/gemini-cli

# Update PATH to include nvm and node binaries
ENV NVM_DIR="/home/developer/.nvm"
ENV PATH="${NVM_DIR}/versions/node/v22.*/bin:${PATH}"

# Add nvm initialization to .bashrc for new shell sessions
RUN echo 'export NVM_DIR="$HOME/.nvm"' >> /home/developer/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /home/developer/.bashrc && \
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> /home/developer/.bashrc

# Add aliases to run Claude Code and Gemini CLI in YOLO mode
RUN echo 'alias yolo-claude="claude --dangerously-skip-permissions"' >> /home/developer/.bashrc && \
    echo 'alias yolo-gemini="gemini --yolo"' >> /home/developer/.bashrc

# Set up working directory
WORKDIR /workspace

# Set the shell to bash
SHELL ["/bin/bash", "-c"]

# Default command
CMD ["/bin/bash"]