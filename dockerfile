# Use Ubuntu as the base image
FROM ubuntu:22.04

# Set the working directory inside the container
WORKDIR /workspace

# Install dependencies
RUN apt update && apt install -y \
    gcc-riscv64-unknown-elf \
    binutils-riscv64-unknown-elf \
    qemu-system-misc \
    build-essential \
    git \
    wget \
    python3 \
    cmake \
    ninja-build \
    && rm -rf /var/lib/apt/lists/*

# Add RISC-V toolchain to PATH
ENV PATH="/usr/bin:$PATH"

# Default command: start a bash shell
CMD ["/bin/bash"]