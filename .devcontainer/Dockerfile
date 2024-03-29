ARG VARIANT=3
ARG CONTAINER=mcr.microsoft.com/devcontainers/python
FROM ${CONTAINER}:${VARIANT}
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

WORKDIR /config

#Get Docker CLI
#For latest version see: https://pkgs.org/download/docker-ce-cli
#ARG DOCKER_CLI_VERSION=5:20.10.21~3-0~ubuntu-focal
#For latest version see: https://pkgs.org/download/containerd.io
#ARG CONTAINERD_VERSION=1.6.10-1

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    jammy stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt update \
    #&& apt-cache policy docker-ce-cli containerd.io \
    && apt-get install -y docker-ce-cli containerd.io \
    && apt-get -q -y clean \
    && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/* rm -rf /tmp/*;

# Get pre-commit
ARG PRECOMMIT_VERSION=3.5.0
RUN pip install --disable-pip-version-check --no-cache-dir pre-commit==${PRECOMMIT_VERSION}

# Get Ansible
ARG ANSIBLE_VERSION=9.4.0
ARG ANSIBLE_LINT_VERSION=24.2.1
RUN pip install --disable-pip-version-check --no-cache-dir ansible==${ANSIBLE_VERSION} ansible-lint==${ANSIBLE_LINT_VERSION}

# Get Powershell
ARG POWERSHELL_VERSION=7.4.0-1.deb

RUN curl -sSL https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb -o packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && rm packages-microsoft-prod.deb \
    && apt update \
    && apt-get install -y powershell=${POWERSHELL_VERSION} \
    && apt-get -q -y clean \
    && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/* rm -rf /tmp/*;

# Get shfmt
ARG SHFMT_VERSION=3.8.0
RUN curl -sSL https://github.com/mvdan/sh/releases/download/v${SHFMT_VERSION}/shfmt_v${SHFMT_VERSION}_linux_amd64 -o /usr/bin/shfmt \
    && chmod +x /usr/bin/shfmt

# Get shellcheck
ARG SHELLCHECK_VERSION=0.9.0
RUN curl -sSL https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.xz -o shellcheck.tar.xz \
    && tar xf shellcheck.tar.xz \
    && mv shellcheck-v${SHELLCHECK_VERSION}/shellcheck /usr/bin/ \
    && chmod +x /usr/bin/shellcheck \
    && rm * -rf

# Get hadolint
ARG HADOLINT_VERSION=2.12.0
RUN curl -sSL https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-x86_64 -o /usr/bin/hadolint \
    && chmod +x /usr/bin/hadolint

