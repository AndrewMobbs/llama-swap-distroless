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
The llama-cpp server binary is `/usr/bin/llama-server`.
There is directory created intended for model storage at `/var/lib/models`. Again, this can be mapped as a volume.
`llama-server` will listen on port 9000

### Example execution:
`podman run -d --device nvidia.com/gpu=all --security-opt=label=disable -v ~/LLM/models:/var/lib/models -v ~/LLM/config/llama-swap.config.yaml:/etc/llama-swap/config.yaml -p 9000:9000 ghcr.io/andrewmobbs/llama-swap-distroless`

### Example llama-swap.config.yaml
```yaml
models:
  "Phi4-reasoning":
    proxy: "http://127.0.0.1:9001"
    ttl: 600
    cmd: >
      /usr/bin/llama-server
      --model /var/lib/models/microsoft_Phi-4-reasoning-plus-Q6_K_L.gguf
      --ctx-size 16384
      --flash-attn
      --n-gpu-layers 99
      --host 127.0.0.1
      --port 9001
      --n-gpu-layers 27
  "Qwen3-14B":
    proxy: "http://127.0.0.1:9003"
    ttl: 600
    cmd: >
      /usr/bin/llama-server
      --model /var/lib/models/Qwen_Qwen3-14B-Q6_K_L.gguf
      --ctx-size 16384
      --flash-attn
      --n-gpu-layers 99
      --host 127.0.0.1
      --port 9003
  "Qwen2.5-Coder-14B-Instruct":
    proxy: "http://127.0.0.1:9006"
    ttl: 600
    cmd: >
      /usr/bin/llama-server
      --model /var/lib/models/Qwen2.5-Coder-14B-Instruct-Q6_K_L.gguf
      --flash-attn
      --ctx-size 12288
      --n-gpu-layers 99
      --prio 2
      --temp 0.2
      --repeat-penalty 0.1
      --dry-multiplier 0.5
      --min-p 0.01
      --top-k 20
      --top-p 0.9
      --host 127.0.0.1
      --port 9006
      --samplers "top_k;top_p;min_p;temperature;dry;typ_p;xtc"
```
