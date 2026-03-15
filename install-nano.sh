#!/bin/bash

# 1. Define Paths
CUDA_PATH="/usr/local/cuda"
BUILD_DIR="llama.cpp/build"
INSTALL_TARGET="llama.cpp"

# 2. Ensure CUDA is in the PATH for this session
export PATH=$CUDA_PATH/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_PATH/lib64:$LD_LIBRARY_PATH

echo "--- Starting llama.cpp build for NVIDIA Jetson ---"

# 3. Check if nvcc exists
if ! command -v nvcc &> /dev/null; then
    echo "Error: nvcc (CUDA Compiler) not found at $CUDA_PATH/bin/nvcc"
    echo "Please verify CUDA is installed: sudo apt install nvidia-cuda"
    exit 1
fi

# 4. Configure the build
# We explicitly point to the CUDA compiler to bypass PATH issues
echo "--- Configuring Build ---"
cmake llama.cpp -B "$BUILD_DIR" \
    -DBUILD_SHARED_LIBS=OFF \
    -DGGML_CUDA=ON \
    -DCMAKE_CUDA_COMPILER="$CUDA_PATH/bin/nvcc" \
    -DCMAKE_BUILD_TYPE=Release

# Check if configuration was successful
if [ $? -ne 0 ]; then
    echo "Configuration failed. Check the error logs above."
    exit 1
fi

# 5. Compile the binaries
# Using -j$(nproc) usually uses all cores, but on 6GB RAM, 
# we limit it to 4 to prevent 'Out of Memory' crashes.
echo "--- Compiling (this may take a while) ---"
cmake --build "$BUILD_DIR" --config Release -j 4 --clean-first \
    --target llama-cli llama-mtmd-cli llama-server llama-gguf-split

# Check if build was successful
if [ $? -ne 0 ]; then
    echo "Build failed. If it crashed, try reducing -j 4 to -j 2 in the script."
    exit 1
fi

# 6. Move binaries to the main folder
echo "--- Deploying Binaries ---"
cp "$BUILD_DIR"/bin/llama-* "$INSTALL_TARGET/"

echo "--- Setup Complete! ---"
echo "You can now run llama-server or llama-cli from the $INSTALL_TARGET directory."
