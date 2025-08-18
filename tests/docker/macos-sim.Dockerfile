FROM alpine:3.18

# Install minimal tools for macOS simulation
RUN apk add --no-cache \
    curl \
    git \
    bash \
    sudo \
    ca-certificates \
    inotify-tools \
    bc

# Install chezmoi
RUN sh -c "$(curl -fsLS get.chezmoi.io)"

# Create test user
RUN adduser -D -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER testuser
WORKDIR /home/testuser

# Mock fswatch for macOS simulation (using inotify-tools)
RUN echo '#!/bin/bash\ninotifywait "$@"' > /home/testuser/scripts/fswatch && \
    chmod +x /home/testuser/scripts/fswatch

# Set up git configuration
RUN git config --global user.name "Test User" && \
    git config --global user.email "test@example.com"

# Create macOS-like directory structure
RUN mkdir -p /home/testuser/{.local/share/chezmoi,Library/LaunchAgents,Library/Logs/chezmoi,scripts,test-dotfiles}

# Mock macOS hostname command
RUN echo '#!/bin/bash\necho "mac-mini"' > /home/testuser/scripts/hostname && \
    chmod +x /home/testuser/scripts/hostname

# Set environment variables for macOS simulation
ENV HOME=/home/testuser
ENV TEST_MODE=true
ENV MACOS_SIM=true
ENV CHEZMOI_SOURCE_DIR=/home/testuser/.local/share/chezmoi
ENV PATH="/home/testuser/scripts:$PATH"

VOLUME ["/home/testuser/test-scripts"]
VOLUME ["/home/testuser/test-fixtures"]

CMD ["/bin/bash"]