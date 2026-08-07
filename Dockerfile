FROM python:3.10-slim

# -- System dependencies ----------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    git \
    ffmpeg \
    libgl1 \
    libglib2.0-0 \
    wget \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# -- Render engine config ---------------------------------------------
# Build arg lets build.sh pick the engine; ENV bakes it into the image.
ARG RENDER_ENGINE=sadtalker
ENV RENDER_ENGINE=${RENDER_ENGINE}

# -- SadTalker (default engine) ----------------------------------------
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

# -- SadTalker checkpoints (from HuggingFace mirrors) ------------------
# The original GitHub release download URLs are broken, so we pull
# individual model files from HuggingFace repos that mirror them.
#
# vinthony/SadTalker       ? base checkpoints + BFM_Fitting + hub + landmarks
# vinthony/SadTalker-V002rc ? packaged safetensors (256 + 512 render models)
# camenduru/SadTalker       ? GFPGAN enhancement weights
#
# HuggingFace file URLs follow the pattern:
#   https://huggingface.co/{repo}/resolve/main/{path}

RUN mkdir -p /app/SadTalker/checkpoints \
    /app/SadTalker/checkpoints/hub/checkpoints \
    /app/SadTalker/checkpoints/BFM_Fitting \
    /app/SadTalker/gfpgan/weights

WORKDIR /app/SadTalker/checkpoints

# Base model files from vinthony/SadTalker
RUN wget -q --show-progress "https://huggingface.co/vinthony/SadTalker/resolve/main/auido2exp_00300-model.pth" -O auido2exp_00300-model.pth && \
    wget -q --show-progress "https://huggingface.co/vinthony/SadTalker/resolve/main/auido2pose_00140-model.pth" -O auido2pose_00140-model.pth && \
    wget -q --show-progress "https://huggingface.co/vinthony/SadTalker/resolve/main/epoch_20.pth" -O epoch_20.pth && \
    wget -q --show-progress "https://huggingface.co/vinthony/SadTalker/resolve/main/facevid2vid_00189-model.pth.tar" -O facevid2vid_00189-model.pth.tar && \
    wget -q --show-progress "https://huggingface.co/vinthony/SadTalker/resolve/main/mapping_00109-model.pth.tar" -O mapping_00109-model.pth.tar && \
    wget -q --show-progress "https://huggingface.co/vinthony/SadTalker/resolve/main/mapping_00229-model.pth.tar" -O mapping_00229-model.pth.tar && \
    wget -q --show-progress "https://huggingface.co/vinthony/SadTalker/resolve/main/shape_predictor_68_face_landmarks.dat" -O shape_predictor_68_face_landmarks.dat && \
    wget -q --show-progress "https://huggingface.co/vinthony/SadTalker/resolve/main/wav2lip.pth" -O wav2lip.pth

# Hub/face-detection models
RUN wget -q --show-progress "https://huggingface.co/vinthony/SadTalker/resolve/main/hub/checkpoints/2DFAN4-cd938726ad.zip" -O hub/checkpoints/2DFAN4-cd938726ad.zip && \
    wget -q --show-progress "https://huggingface.co/vinthony/SadTalker/resolve/main/hub/checkpoints/s3fd-619a316812.pth" -O hub/checkpoints/s3fd-619a316812.pth

# BFM_Fitting files
RUN wget -q --show-progress "https://huggingface.co/vinthony/SadTalker/resolve/main/BFM_Fitting/01_MorphableModel.mat" -O BFM_Fitting/01_MorphableModel.mat && \
    wget -q --show-progress "https://huggingface.co/vinthony/SadTalker/resolve/main/BFM_Fitting/BFM09_model_info.mat" -O BFM_Fitting/BFM09_model_info.mat && \
    wget -q --show-progress "https://huggingface.co/vinthony/SadTalker/resolve/main/BFM_Fitting/BFM_exp_idx.mat" -O BFM_Fitting/BFM_exp_idx.mat && \
    wget -q --show-progress "https://huggingface.co/vinthony/SadTalker/resolve/main/BFM_Fitting/BFM_front_idx.mat" -O BFM_Fitting/BFM_front_idx.mat && \
    wget -q --show-progress "https://huggingface.co/vinthony/SadTalker/resolve/main/BFM_Fitting/Exp_Pca.bin" -O BFM_Fitting/Exp_Pca.bin && \
    wget -q --show-progress "https://huggingface.co/vinthony/SadTalker/resolve/main/BFM_Fitting/facemodel_info.mat" -O BFM_Fitting/facemodel_info.mat && \
    wget -q --show-progress "https://huggingface.co/vinthony/SadTalker/resolve/main/BFM_Fitting/select_vertex_id.mat" -O BFM_Fitting/select_vertex_id.mat && \
    wget -q --show-progress "https://huggingface.co/vinthony/SadTalker/resolve/main/BFM_Fitting/similarity_Lm3D_all.mat" -O BFM_Fitting/similarity_Lm3D_all.mat && \
    wget -q --show-progress "https://huggingface.co/vinthony/SadTalker/resolve/main/BFM_Fitting/std_exp.txt" -O BFM_Fitting/std_exp.txt

# Packaged safetensors (256 + 512 render models) from vinthony/SadTalker-V002rc
RUN wget -q --show-progress "https://huggingface.co/vinthony/SadTalker-V002rc/resolve/main/SadTalker_V0.0.2_256.safetensors" -O SadTalker_V0.0.2_256.safetensors && \
    wget -q --show-progress "https://huggingface.co/vinthony/SadTalker-V002rc/resolve/main/SadTalker_V0.0.2_512.safetensors" -O SadTalker_V0.0.2_512.safetensors

# GFPGAN enhancement weights from camenduru/SadTalker
RUN wget -q --show-progress "https://huggingface.co/camenduru/SadTalker/resolve/main/new/gfpgan/weights/GFPGANv1.4.pth" -O /app/SadTalker/gfpgan/weights/GFPGANv1.4.pth && \
    wget -q --show-progress "https://huggingface.co/camenduru/SadTalker/resolve/main/new/gfpgan/weights/alignment_WFLW_4HG.pth" -O /app/SadTalker/gfpgan/weights/alignment_WFLW_4HG.pth && \
    wget -q --show-progress "https://huggingface.co/camenduru/SadTalker/resolve/main/new/gfpgan/weights/detection_Resnet50_Final.pth" -O /app/SadTalker/gfpgan/weights/detection_Resnet50_Final.pth && \
    wget -q --show-progress "https://huggingface.co/camenduru/SadTalker/resolve/main/new/gfpgan/weights/parsing_parsenet.pth" -O /app/SadTalker/gfpgan/weights/parsing_parsenet.pth

# -- LivePortrait (optional engine) ------------------------------------
# Installed when RENDER_ENGINE=liveportrait build arg is passed.
RUN if [ "$RENDER_ENGINE" = "liveportrait" ]; then \
      git clone https://github.com/KwaiVGI/LivePortrait.git /app/LivePortrait \
      && cd /app/LivePortrait \
      && pip install --no-cache-dir -r requirements.txt \
      && python scripts/download_weights.py --models all \
      && pip install --no-cache-dir insightface onnxruntime-gpu; \
    fi

# -- RunPod serverless -------------------------------------------------
RUN pip install --no-cache-dir runpod==1.6.2

# Copy engine modules and handler
WORKDIR /app
COPY src/ /app/src/

RUN mkdir -p /app/inputs /app/outputs

CMD ["python", "-u", "src/rp_handler.py"]
