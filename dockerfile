# Use Ubuntu as the base image
FROM ubuntu:22.04

# Set the working directory inside the container
WORKDIR /alykernel

# Install dependencies
RUN apt update && apt install -y \
    make \
    nasm \
    dosfstools \
    mtools \
    gcc \
    curl \
    git

# Copy the locally installed Open Watcom compiler into the image
COPY ./usr/bin/watcom /usr/bin/watcom

# Set environment variables for Open Watcom
ENV WATCOM=/usr/bin/watcom
ENV PATH="$WATCOM:$PATH"
ENV INCLUDE=$WATCOM/h
ENV LIB=$WATCOM/lib386

# Add RISC-V toolchain to PATH
ENV PATH="/usr/bin:$PATH"

# Default command: start a bash shell
CMD ["/bin/bash"]

RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)"