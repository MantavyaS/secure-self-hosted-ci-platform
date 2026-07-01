FROM ghcr.io/actions/actions-runner:latest

ARG KUBECTL_VERSION=v1.34.1
# ARG RUNNER_VERSION=2.335.1

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y curl unzip git jq ca-certificates python3 python3-pip sudo gnupg software-properties-common wget lsb-release && rm -rf /var/lib/apt/lists/*

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip -q awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip

# Install Docker CLI
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update \
    && apt-get install -y terraform \
    && rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# Install Helm
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    && chmod 700 get_helm.sh \
    && ./get_helm.sh \
    && rm get_helm.sh

# Create runner user
# RUN useradd -m runner \
#     && usermod -aG sudo,docker runner \
#     && echo 'runner ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER runner
WORKDIR /home/runner

# Download GitHub Actions runner
# RUN mkdir actions-runner \
#     && cd actions-runner \
#     && curl -O -L "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
#     && tar xzf "actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
#     && rm "actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

# COPY --chown=runner:runner start.sh /home/runner/start.sh
# RUN chmod +x /home/runner/start.sh

# ENTRYPOINT ["/home/runner/start.sh"]