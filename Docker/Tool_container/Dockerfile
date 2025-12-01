FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# -----------------------------
# בסיס + כלים כלליים
# -----------------------------
RUN apt-get update && apt-get install -y \
    curl wget git unzip vim jq ca-certificates gnupg software-properties-common lsb-release \
    python3 python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------
# kubectl
# -----------------------------
RUN curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl


# -----------------------------
# Helm (Latest)
# -----------------------------
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# -----------------------------
# כלים לפייתון: flake8, bandit, pytest ועוד
# -----------------------------
RUN pip install --upgrade pip && \
    pip install \
        flake8 \
        bandit \
        pytest \
        pytest-cov

# -----------------------------
# כלי Node (אם יש בדיקות JS בהמשך)
# -----------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get update && apt-get install -y nodejs

# -----------------------------
# Go (לא חובה, אבל אם יש מיקרו-סרוויס Go בפייפליין)
# -----------------------------
RUN wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz && \
    rm go1.22.0.linux-amd64.tar.gz

ENV PATH="/usr/local/go/bin:${PATH}"


CMD ["bash"]
