# Use the specific inbound-agent image from your Helm chart values as the base
FROM jenkins/inbound-agent:3301.v4363ddcca_4e7-3

# Switch to root temporarily to install packages
USER root

# Install Node.js (version 23.x), Podman, procps, and shadow for subuid/subgid
RUN apt-get update && apt-get install -y \
    podman \
    curl \
    gnupg \
    && curl -fsSL https://deb.nodesource.com/setup_23.x | bash - \
    && apt-get install -y nodejs \
    --no-install-recommends && rm -rf /var/lib/apt/lists/*

# Configure subuid and subgid for the jenkins user
RUN echo "jenkins:100000:65536" >> /etc/subuid \
    && echo "jenkins:100000:65536" >> /etc/subgid

# Verify Node.js and npm installation
RUN node --version && npm --version

# Configure storage for rootless Podman
RUN mkdir -p /home/jenkins/.config/containers /home/jenkins/.local/share/containers \
    && chown -R jenkins:jenkins /home/jenkins/.config /home/jenkins/.local
ENV CONTAINERS_REGISTRIES_CONF="/home/jenkins/.config/containers/registries.conf"

# Switch back to the default 'jenkins' user
USER jenkins