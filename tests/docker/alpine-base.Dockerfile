FROM alpine:3.18

# Install essential tools (Alpine is clean and minimal)
RUN apk add --no-cache \
    curl \
    git \
    bash \
    sudo \
    ca-certificates \
    inotify-tools

# Install chezmoi
RUN sh -c "$(curl -fsLS get.chezmoi.io)"

# Create test user (never test as root)
RUN adduser -D -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to test user
USER testuser
WORKDIR /home/testuser

# Set up git configuration for testing
RUN git config --global user.name "Test User" && \
    git config --global user.email "test@example.com"

# Create isolated test directories
RUN mkdir -p /home/testuser/{.local/share/chezmoi,.config,scripts,test-dotfiles}

# Set environment variables for testing
ENV HOME=/home/testuser
ENV TEST_MODE=true
ENV CHEZMOI_SOURCE_DIR=/home/testuser/.local/share/chezmoi

# Copy test scripts (will be mounted at runtime)
VOLUME ["/home/testuser/test-scripts"]
VOLUME ["/home/testuser/test-fixtures"]

CMD ["/bin/bash"]