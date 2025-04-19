# Use the specific inbound-agent image from your Helm chart values as the base
FROM jenkins/inbound-agent:3301.v4363ddcca_4e7-3

# Switch to root temporarily to install packages
USER root

# Install Node.js (version 23.x), Podman, and required tools
RUN apt-get update && apt-get install -y \
    podman \
    curl \
    gnupg \
    && curl -fsSL https://deb.nodesource.com/setup_23.x | bash - \
    && apt-get install -y nodejs \
    --no-install-recommends && rm -rf /var/lib/apt/lists/*

# Verify Node.js and npm installation
RUN node --version && npm --version

# Optional: Configure storage for rootless Podman
RUN mkdir -p /home/jenkins/.config/containers /home/jenkins/.local/share/containers \
    && chown -R jenkins:jenkins /home/jenkins/.config /home/jenkins/.local
ENV CONTAINERS_REGISTRIES_CONF="/home/jenkins/.config/containers/registries.conf"

# Switch back to the default 'jenkins' user
USER jenkins

# The ENTRYPOINT and CMD from the base image should be suitable for starting the agent