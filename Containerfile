# --- Stage 1: Builder ---
# This stage installs all necessary tools and builds llama.cpp

FROM debian:bookworm AS builder

# Prevent interactive prompts during apt operations
ENV DEBIAN_FRONTEND=noninteractive

# Install basic tools and build dependencies (excluding CUDA for now)
RUN apt update && \
    apt install -y --no-install-recommends \
    curl \
    ca-certificates \
    jq \
    unzip \
    python3 \
    python3-pip \
    gcc \
    make \
    cmake \
    git \
    libcurl4-openssl-dev \
    ccache && \
    rm -rf /var/lib/apt/lists/*

# Add NVIDIA CUDA repository, install CUDA toolkit
# We install the full toolkit here because it includes compilation tools and runtime libs
RUN curl -sLO https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb && \
    dpkg -i cuda-keyring_1.1-1_all.deb && \
    rm cuda-keyring_1.1-1_all.deb && \
    apt update && \
    apt install -y --no-install-recommends cuda-toolkit-12 && \
    rm -rf /var/lib/apt/lists/*

# Define the Go version as an environment variable for easy updates
ENV GO_VERSION 1.24.2

# Set GOROOT and update the system-wide PATH to include Go's bin directory
ENV PATH ${GOROOT}/bin:${PATH}

# Download and extract the Go SDK into the GOROOT directory
RUN curl -sL https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz | tar xzf - -C /usr/local/

# Switch to the build user context for building
RUN useradd -ms /bin/bash build
USER build
WORKDIR /home/build/src

# Clone llama.cpp and llama-swap
RUN git clone https://github.com/ggerganov/llama.cpp
RUN git clone https://github.com/mostlygeek/llama-swap

# Build llama.cpp
# FIXME - could do with a more up-to-date GCC, but no backport offered. 
ENV GOROOT /usr/local/go
ENV PATH="/usr/local/cuda/bin:$GOROOT/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"
WORKDIR /home/build/src/llama.cpp
# Configure with CUDA support
RUN cmake -B build -DGGML_CUDA=ON  -DGGML_CUDA_USE_GRAPHS=ON -DGGML_CUDA_FA_ALL_QUANTS=ON
# Build - set the environment variable for the build command
RUN cmake --build build --config Release -j $(nproc) 
# Build a tarball of just the essential libraries
RUN ldd build/bin/llama-server | cut -f 3 -d ' ' | sort -u | grep 'usr.*\.so' | xargs -I '{}' bash -c 'printf "{}\n"; [ -h {} ] && printf "%s\n" $(realpath {})' | tar chf ~/libs.tar -T -
# Build llama-swap
WORKDIR /home/build/src/llama-swap
RUN make clean linux

# --- Stage 2: Runtime ---
# This stage creates the final image, copying only the necessary artifacts

FROM gcr.io/distroless/base-debian12:latest

WORKDIR /
# We need a working GNU tar to deal with the library tarball
# We also need rm to clean up, and may as well get mkdir while we're here to save a layer.
COPY --from=builder /lib/x86_64-linux-gnu/libacl.so.1 /lib/x86_64-linux-gnu/libselinux.so.1 /lib/x86_64-linux-gnu/libpcre2-8.so.0  /lib/x86_64-linux-gnu/
COPY --from=builder /usr/bin/tar /usr/bin/rm /usr/bin/mkdir /usr/bin/
# Then we need the libary tarball itself
COPY --from=builder /home/build/libs.tar /
RUN ["/usr/bin/tar","xvf","libs.tar","--skip-old-files"]
# Create directories for local binaries, libraries, and models
RUN ["/usr/bin/mkdir","-p","/var/lib/models","/etc/llama-swap"]
# Cleanup
RUN ["/usr/bin/rm","-f","libs.tar","/lib/x86_64-linux-gnu/libacl.so.1","/lib/x86_64-linux-gnu/libselinux.so.1","/lib/x86_64-linux-gnu/libpcre2-8.so.0","/usr/bin/tar","/usr/bin/mkdir","/usr/bin/rm"]

# Copy the built llama.cpp binaries from the builder stage
COPY --from=builder /home/build/src/llama.cpp/build/bin/llama-server /usr/bin/
# Copy the built llama.cpp shared libraries from the builder stage
COPY --from=builder /home/build/src/llama.cpp/build/bin/*.so /usr/lib/
# Copy llama-swap from the builder stage
COPY --from=builder /home/build/src/llama-swap/build/llama-swap-linux-amd64 /usr/bin/llama-swap

# Set persistent environment variables for the build user
ENV PATH="/usr/local/cuda/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"

# Expose the port used by llama-swap
EXPOSE 9000
# Swap to a non-root user
USER nonroot
# Set the default command to run when the container starts
ENV GGML_CUDA_ENABLE_UNIFIED_MEMORY=1
ENTRYPOINT [ "/usr/bin/llama-swap" ]
CMD ["-config","/etc/llama-swap/config.yaml","-listen","0.0.0.0:9000"]
