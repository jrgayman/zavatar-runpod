#!/bin/bash
#
# Build and push the Z-Avatar Docker image to a container registry.
# RunPod serverless pulls this image to run face animation on GPU.
#
# Usage:
#   ./build.sh                        # builds SadTalker (default), pushes to Docker Hub
#   ./build.sh --build-only            # builds locally without pushing
#   ./build.sh --engine liveportrait   # builds with LivePortrait support
#   ./build.sh --registry ghcr         # pushes to GitHub Container Registry
#
# Environment variables:
#   DOCKER_USERNAME  Docker Hub username (default: your-dockerhub-username)
#   GITHUB_ACTOR     GitHub username for ghcr.io (used with --registry ghcr)
#

set -euo pipefail

IMAGE_NAME="zavatar"
TAG="latest"
REGISTRY="docker.io"
DOCKER_USER="${DOCKER_USERNAME:-your-dockerhub-username}"
BUILD_ONLY=false
ENGINE="sadtalker"

for arg in "$@"; do
  case $arg in
    --build-only)
      BUILD_ONLY=true
      ;;
    --engine=*)
      ENGINE="${arg#*=}"
      ;;
    --registry=ghcr)
      REGISTRY="ghcr.io"
      DOCKER_USER="${GITHUB_ACTOR:-your-github-username}"
      ;;
  esac
done

if [ "$ENGINE" != "sadtalker" ] && [ "$ENGINE" != "liveportrait" ]; then
  echo "ERROR: Unknown engine '$ENGINE'. Use 'sadtalker' or 'liveportrait'."
  exit 1
fi

FULL_IMAGE="${REGISTRY}/${DOCKER_USER}/${IMAGE_NAME}:${ENGINE}-${TAG}"

echo "=========================================="
echo " Z-Avatar Docker Image Builder"
echo "=========================================="
echo ""
echo " Engine:  ${ENGINE}"
echo " Image:   ${FULL_IMAGE}"
echo " Push:    $([ "$BUILD_ONLY" = true ] && echo 'no' || echo 'yes')"
echo ""

if ! command -v docker &> /dev/null; then
  echo "ERROR: Docker is not installed or not in PATH."
  echo "Install Docker: https://docs.docker.com/get-docker/"
  exit 1
fi

# ── Build ────────────────────────────────────────────────────────────
echo "[1/3] Building Docker image (${ENGINE} engine)..."

if [ "$ENGINE" = "liveportrait" ]; then
  # Build with LivePortrait support by uncommenting the LivePortrait section
  # via a build arg that the Dockerfile can consume
  docker build \
    --build-arg RENDER_ENGINE=liveportrait \
    -t "${FULL_IMAGE}" \
    -f Dockerfile .
else
  docker build \
    -t "${FULL_IMAGE}" \
    -f Dockerfile .
fi

echo ""
echo "  Build complete."

if [ "$BUILD_ONLY" = true ]; then
  echo ""
  echo "[2/3] Skipped push (--build-only)"
  echo ""
  echo "Image built locally: ${FULL_IMAGE}"
  echo "To push later: docker push ${FULL_IMAGE}"
  exit 0
fi

# ── Push ──────────────────────────────────────────────────────────────
echo ""
echo "[2/3] Pushing to ${REGISTRY}..."
docker push "${FULL_IMAGE}"

# ── Done ──────────────────────────────────────────────────────────────
echo ""
echo "[3/3] Done!"
echo ""
echo "=========================================="
echo " Next steps:"
echo "=========================================="
echo ""
echo " 1. Go to RunPod: https://www.runpod.io/console/serverless"
echo " 2. Create a New Template -> Custom Template"
echo " 3. Set Docker image: ${FULL_IMAGE}"
if [ "$ENGINE" = "liveportrait" ]; then
  echo " 4. Set Env Var: RENDER_ENGINE=liveportrait"
else
  echo " 4. Env Var RENDER_ENGINE defaults to 'sadtalker' (no change needed)"
fi
echo " 5. Set GPU type: RTX 3090 or A40 (16GB+ VRAM)"
echo " 6. Set container disk: 20 GB"
echo " 7. Create a Serverless Endpoint using this template"
echo " 8. Copy the Endpoint URL (https://api.runpod.ai/v2/xxxxxx)"
echo " 9. Go to Zimple Super Admin -> Z-Avatar -> Runtime tab"
echo "10. Paste the Endpoint URL and your RunPod API key, save"
echo ""
