# Use the specific inbound-agent image from your Helm chart values as the base
FROM jenkins/inbound-agent:3301.v4363ddcca_4e7-3

# Switch to root temporarily to install packages
USER root

# Install Podman and AWS CLI using apt-get (common for Debian/Ubuntu-based images)
# Add any other tools your pipeline needs (e.g., jq, kubectl)
RUN apt-get update && apt-get install -y \
    podman
    # awscli \
    # jq \
    # kubectl \
    # --no-install-recommends && rm -rf /var/lib/apt/lists/*

# Optional: Configure storage for rootless Podman (if you plan to run Podman rootless)
# You'll need to ensure the 'jenkins' user has necessary permissions.
# RUN mkdir -p /home/jenkins/.config/containers /home/jenkins/.local/share/containers \
#     && chown -R jenkins:jenkins /home/jenkins/.config /home/jenkins/.local
# ENV CONTAINERS_REGISTRIES_CONF="/home/jenkins/.config/containers/registries.conf"

# Switch back to the default 'jenkins' user that the agent runs as
USER jenkins

# The ENTRYPOINT and CMD from the base image should be suitable for starting the agent