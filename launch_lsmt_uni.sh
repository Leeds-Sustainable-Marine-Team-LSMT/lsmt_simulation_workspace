#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect Apptainer or Singularity runtime (no root access required)
if command -v apptainer &> /dev/null; then
    CONTAINER_CMD="apptainer"
elif command -v singularity &> /dev/null; then
    CONTAINER_CMD="singularity"
else
    echo "Error: Neither apptainer nor singularity was found in PATH."
    exit 1
fi

# Resolve .sif image path from argument, LSMT_SIF env var, or default ./lsmt.sif
SIF_IMAGE="${1:-${LSMT_SIF:-$SCRIPT_DIR/lsmt.sif}}"
if [ ! -f "$SIF_IMAGE" ]; then
    echo "Error: Container image not found at '$SIF_IMAGE'."
    echo "Build or pull the .sif image first (e.g. $CONTAINER_CMD pull lsmt.sif docker://... or $CONTAINER_CMD build lsmt.sif docker-archive://lsmt.tar),"
    echo "or pass a shared .sif path directly: ./launch_lsmt_uni.sh /path/to/lsmt.sif"
    exit 1
fi

# Create local writable directories for bind-mounting into the read-only .sif image
mkdir -p "$SCRIPT_DIR/src" "$SCRIPT_DIR/build" "$SCRIPT_DIR/install" "$SCRIPT_DIR/log"

# Detect NVIDIA GPU and pass --nv flag if available
GPU_FLAG=""
if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
    echo "NVIDIA GPU detected. Launching $CONTAINER_CMD with --nv hardware acceleration..."
    GPU_FLAG="--nv"
else
    echo "No NVIDIA GPU detected. Launching standard $CONTAINER_CMD environment..."
fi

"$CONTAINER_CMD" exec \
    $GPU_FLAG \
    --pwd /ros2_ws \
    --env GZ_VERSION=garden \
    --bind "$SCRIPT_DIR/src:/ros2_ws/src" \
    --bind "$SCRIPT_DIR/build:/ros2_ws/build" \
    --bind "$SCRIPT_DIR/install:/ros2_ws/install" \
    --bind "$SCRIPT_DIR/log:/ros2_ws/log" \
    "$SIF_IMAGE" \
    bash -c 'source /opt/ros/humble/setup.bash && if [ -f /ros2_ws/install/setup.bash ]; then source /ros2_ws/install/setup.bash; fi && exec bash --norc'
