# Use Ubuntu as the base image
FROM ubuntu:22.04

# Set the working directory inside the container
WORKDIR /workspace

# Install dependencies
RUN apt update && apt install -y \
    make \
    nasm \
    dosfstools \
    mtools

# Add RISC-V toolchain to PATH
ENV PATH="/usr/bin:$PATH"

# Default command: start a bash shell
CMD ["/bin/bash"]