# llama-swap-distroless container
A minimal container image, build from Google Distroless Debian, for running multiple local LLM models from a single endpoint on NVidia GPUs.

This is a minimal alternative to [ghcr.io/mostlygeek/llama-swap:cuda](https://github.com/mostlygeek/llama-swap/pkgs/container/llama-swap) (which is much more general-purpose and better supported than this).

Builds [llama.cpp](https://github.com/ggml-org/llama.cpp) and [llama-swap](https://github.com/mostlygeek/llama-swap) from source against the latest NVidia CUDA 12 libraries. Assumes x86-64 architecture.

## To build:
`podman build --tag llama-swap-distroless -f Containerfile --device nvidia.com/gpu=all --security-opt=label=disable .`

### Notes
1. Ensure [NVidia drivers](https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/index.html) are installed on the host and [CDI is configured](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/cdi-support.html).  
2. This may need a more recent version of podman/buildah than is included on the host OS to work with CDI for the build phase (e.g. for Debian Bookworm). See https://github.com/AndrewMobbs/container-tools-builder for a solution.

## To use:
`podman pull ghcr.io/andrewmobbs/llama-swap-distroless:latest`

The container assumes that the [llama-swap config](https://github.com/mostlygeek/llama-swap?tab=readme-ov-file#configyaml) is in `/etc/llama-swap/config.yaml`. This can either be copied into the container image before use or mapped in as volumes.
There is directory created intended for model storage at `/var/lib/models`. Again, this can be mapped as a volume.
The default port is 9000

### Example execution:
`podman run -d --device nvidia.com/gpu=all --security-opt=label=disable -v ~/LLM/models:/var/lib/models -v ~/LLM/config/llama-swap.config.yaml:/etc/llama-swap/config.yaml -p 9000:9000 ghcr.io/andrewmobbs/llama-swap-distroless`
