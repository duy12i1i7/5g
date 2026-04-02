FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    bash \
    bison \
    build-essential \
    ca-certificates \
    clang \
    curl \
    default-jre \
    doxygen \
    flex \
    gdb \
    git \
    graphviz \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libwebkit2gtk-4.1-dev \
    libxml2-dev \
    openssh-client \
    perl \
    pkg-config \
    python3 \
    python3-pip \
    python3-venv \
    qt5-qmake \
    qtbase5-dev \
    qtbase5-dev-tools \
    qtchooser \
    sumo \
    sumo-tools \
    wget \
    xauth \
    xvfb \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash vscode \
    && mkdir -p /workspace \
    && chown -R vscode:vscode /workspace /home/vscode

USER vscode
WORKDIR /workspace

RUN python3 -m pip install --no-cache-dir --user matplotlib

CMD ["/bin/bash"]
