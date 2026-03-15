I've integrated those specific download and serving steps into the guide. I also adjusted the flags (like `-b 1` and `-ub 1`) to ensure that even with the much larger **16,384** context size you're now requesting, the Jetson's memory allocator doesn't choke on fragmentation.

Here is the updated guide.

---

# NVIDIA Jetson Orin Nano: llama-server Setup Guide

This guide covers building, downloading, and serving `llama.cpp` on an NVIDIA Jetson Orin Nano (8GB), optimized for the Qwen 3.5 "Thinking" model.

## 1. System Preparation

Before building, ensure your system is in Max Performance mode and has a swap file to handle the memory-intensive compilation.

```bash
# Set Max Performance
sudo nvpmodel -m 0
sudo jetson_clocks

# Create 8GB Swap
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

```

## 2. Build Instructions

We explicitly point to the CUDA compiler and build the server binary.

```bash
# Clone and build
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp

cmake -B build \
    -DBUILD_SHARED_LIBS=OFF \
    -DGGML_CUDA=ON \
    -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc

cmake --build build --config Release -j 4 --target llama-server
cd ..

```

## 3. Model Download

Using the `huggingface-cli` to pull the specific 4B GGUF weights.

```bash
# Ensure huggingface-cli is installed (pip install huggingface_hub)
huggingface-cli download unsloth/Qwen3.5-4B-GGUF \
    --local-dir unsloth/Qwen3.5-4B-GGUF \
    --include "*UD-Q4_K_XL*"

```

## 4. Serving the Model

The following command includes the **Critical Memory Fixes** for the Orin Nano: `-b 1`, `-ub 1`, and `--no-mmap`. These prevent the `Error 12` CUDA allocation failure.

```bash
# Set Cache Directory
export LLAMA_CACHE="unsloth/Qwen3.5-4B-GGUF"

# Start the Server
./llama.cpp/build/bin/llama-server \
    -hf unsloth/Qwen3.5-4B-GGUF:UD-Q4_K_XL \
    --ctx-size 16384 \
    --parallel 1 \
    -b 1 \
    -ub 1 \
    -ngl 99 \
    --no-mmap \
    --flash-attn on \
    --temp 0.6 \
    --top-p 0.95 \
    --top-k 20 \
    --min-p 0.00 \
    --alias "unsloth/Qwen3.5-4B-GGUF" \
    --port 8001 \
    --host 0.0.0.0 \
    --chat-template-kwargs '{"enable_thinking":true}'

```

### Important Notes for Orin Nano (8GB):

* **Context Size:** You are requesting **16,384** tokens. This will use significantly more VRAM than the previous 2,048 test. If you see an "Out of Memory" error, you may need to reduce this to `8192`.
* **Batch Sizes:** Keeping `-b 1` and `-ub 1` is essential when using a large context on the Jetson; it ensures the "Compute Buffer" stays tiny and fits into fragmented memory handles.
* **Thinking Mode:** The `enable_thinking: true` flag works best with Qwen 3.5 models to allow for chain-of-thought reasoning output.

---

Would you like me to help you write a simple **Python test script** that sends a prompt to this specific port (8001) and prints out the "thinking" process and the final answer?
