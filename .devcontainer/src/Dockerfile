# syntax=docker/dockerfile:1.4

ARG VARIANT="ubuntu"

FROM mcr.microsoft.com/devcontainers/base:${VARIANT}

ARG devcontainercli

COPY first-run-notice.txt /tmp/scripts/

RUN \
    if [ -z "$devcontainercli" ] ; then \
        printf "\nERROR: This Dockerfile needs to be built with Visual Studio Code or using the devcontainer-cli !" && exit 1; \
    else \
        printf "devcontainer-cli is detected: $devcontainercli"; \
    fi \
    # Upgrade OS
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get -y upgrade --no-install-recommends \
    # Install common admin command line tools
    && apt-get install -y --no-install-recommends \
        # Networking tools
        dnsutils \
        iputils-arping \
        iputils-ping \
        netcat-openbsd \
        openssh-client \
        # Terminal tools
        screen \
        tmux \
    # Clean up
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* \
    # Move first run notice to right spot
    && mkdir -p "/usr/local/etc/vscode-dev-containers/" \
    && mv -f /tmp/scripts/first-run-notice.txt /usr/local/etc/vscode-dev-containers/ \
    && rm -rf /tmp/scripts

# Fire SSH init script if needed
ENTRYPOINT [ "/usr/local/share/ssh-init.sh" ]
CMD [ "sleep", "infinity" ]
