FROM python:3.10-slim

# ── System dependencies ──────────────────────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    git \
    ffmpeg \
    libgl1 \
    libglib2.0-0 \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ── Render engine config ─────────────────────────────────────────────
# Build arg lets build.sh pick the engine; ENV bakes it into the image.
ARG RENDER_ENGINE=sadtalker
ENV RENDER_ENGINE=${RENDER_ENGINE}

# ── SadTalker (default engine) ────────────────────────────────────────
RUN git clone https://github.com/OpenTalker/SadTalker.git /app/SadTalker

WORKDIR /app/SadTalker

RUN pip install --no-cache-dir torch==2.1.2 torchvision==0.16.2 \
    --index-url https://download.pytorch.org/whl/cu121
RUN pip install --no-cache-dir \
    numpy==1.23.5 \
    opencv-python==4.8.1.78 \
    face_alignment==1.3.4 \
    imageio==2.33.1 \
    imageio-ffmpeg==0.4.9 \
    librosa==0.9.2 \
    numba==0.58.1 \
    scikit-image==0.21.0 \
    gfpgan==1.3.8 \
    gradio==3.50.2 \
    pydub==0.25.1 \
    torchaudio==2.1.2 \
    --extra-index-url https://download.pytorch.org/whl/cu121

# SadTalker checkpoints
RUN mkdir -p /app/SadTalker/checkpoints
WORKDIR /app/SadTalker/checkpoints

RUN wget -q https://github.com/OpenTalker/SadTalker/releases/download/v0.0.2-rc/auxiliary.zip -O auxiliary.zip \
    && unzip -q auxiliary.zip -d . \
    && rm auxiliary.zip

RUN wget -q https://github.com/OpenTalker/SadTalker/releases/download/v0.0.2-rc/SadTalker_V0.0.2_256.zip -O SadTalker_256.zip \
    && unzip -q SadTalker_256.zip -d . \
    && rm SadTalker_256.zip

RUN wget -q https://github.com/OpenTalker/SadTalker/releases/download/v0.0.2-rc/SadTalker_V0.0.2_512.zip -O SadTalker_512.zip \
    && unzip -q SadTalker_512.zip -d . \
    && rm SadTalker_512.zip

RUN wget -q https://github.com/TencentARC/GFPGAN/releases/download/v1.3.4/GFPGANv1.4.pth \
    -O /app/SadTalker/gfpgan/weights/GFPGANv1.4.pth \
    || (mkdir -p /app/SadTalker/gfpgan/weights \
        && wget -q https://github.com/TencentARC/GFPGAN/releases/download/v1.3.4/GFPGANv1.4.pth \
        -O /app/SadTalker/gfpgan/weights/GFPGANv1.4.pth)

# ── LivePortrait (optional engine) ────────────────────────────────────
# Installed when RENDER_ENGINE=liveportrait build arg is passed.
# This clones LivePortrait, installs its dependencies, and downloads
# the model weights so the image is self-contained.
RUN if [ "$RENDER_ENGINE" = "liveportrait" ]; then \
      git clone https://github.com/KwaiVGI/LivePortrait.git /app/LivePortrait \
      && cd /app/LivePortrait \
      && pip install --no-cache-dir -r requirements.txt \
      && python scripts/download_weights.py --models all \
      && pip install --no-cache-dir insightface onnxruntime-gpu; \
    fi

# ── RunPod serverless ─────────────────────────────────────────────────
RUN pip install --no-cache-dir runpod==1.6.2

# Copy engine modules and handler
WORKDIR /app
COPY src/ /app/src/

RUN mkdir -p /app/inputs /app/outputs

CMD ["python", "-u", "src/rp_handler.py"]
