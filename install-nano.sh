#!/bin/bash

# --- Configuration ---
CUDA_PATH="/usr/local/cuda"
BUILD_DIR="llama.cpp/build"
INSTALL_TARGET="llama.cpp"
SWAP_FILE="/swapfile_build"
SWAP_SIZE_GB=8

echo "--- Starting llama.cpp build for NVIDIA Jetson ---"

# 1. Swap File Management
# Check if swap is less than 2GB, if so, create a temporary one
TOTAL_SWAP=$(free -g | awk '/^Swap:/ {print $2}')

if [ "$TOTAL_SWAP" -lt 4 ]; then
    echo "--- Insufficient swap detected (${TOTAL_SWAP}GB). Creating a ${SWAP_SIZE_GB}GB build-swap ---"
    sudo swapoff -a 2>/dev/null
    sudo fallocate -l ${SWAP_SIZE_GB}G $SWAP_FILE
    sudo chmod 600 $SWAP_FILE
    sudo mkswap $SWAP_FILE
    sudo swapon $SWAP_FILE
    echo "--- Build-swap active ---"
else
    echo "--- Sufficient swap detected (${TOTAL_SWAP}GB) ---"
fi

# 2. Setup Environment
export PATH=$CUDA_PATH/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_PATH/lib64:$LD_LIBRARY_PATH

# 3. Check for CUDA Compiler
if ! command -v nvcc &> /dev/null; then
    echo "Error: nvcc not found. Trying to install nvidia-cuda-toolkit..."
    sudo apt update && sudo apt install -y nvidia-cuda
fi

# 4. Configure Build
echo "--- Configuring Build ---"
cmake llama.cpp -B "$BUILD_DIR" \
    -DBUILD_SHARED_LIBS=OFF \
    -DGGML_CUDA=ON \
    -DCMAKE_CUDA_COMPILER="$CUDA_PATH/bin/nvcc" \
    -DCMAKE_BUILD_TYPE=Release

if [ $? -ne 0 ]; then
    echo "Configuration failed."
    exit 1
fi

# 5. Compile
# We use 4 cores (-j 4) to balance speed and stability
echo "--- Compiling ---"
cmake --build "$BUILD_DIR" --config Release -j 4 --clean-first \
    --target llama-cli llama-mtmd-cli llama-server llama-gguf-split

if [ $? -ne 0 ]; then
    echo "Build failed."
    exit 1
fi

# 6. Deploy
echo "--- Deploying Binaries ---"
cp "$BUILD_DIR"/bin/llama-* "$INSTALL_TARGET/"

# 7. Cleanup Swap (Optional)
# Uncomment the lines below if you want to remove the swap file after building
# echo "--- Cleaning up temporary swap ---"
# sudo swapoff $SWAP_FILE
# sudo rm $SWAP_FILE

echo "--- Setup Complete! ---"
