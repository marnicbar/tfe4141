FROM ghdl/ghdl:5.1.1-gcc-ubuntu-24.04

# Install packages
RUN apt-get update && apt-get install -y \
    git \
    make \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Change to the unprivileged user
USER ubuntu
