# Z-Avatar RunPod Serverless

AI-powered talking-head video generation for the Zimple platform. This Docker image runs on RunPod serverless GPUs.

## Engines

- **SadTalker** (default) - audio-driven portrait animation, works out of the box
- **LivePortrait** - higher quality motion, requires more GPU memory

## Building

GitHub Actions automatically builds and pushes images to GitHub Container Registry (GHCR):

- Push to main triggers a SadTalker build
- Manual trigger via GitHub Actions UI lets you pick the engine

## Usage in RunPod

1. Create a Serverless Template in RunPod
2. Set Docker image to ghcr.io/jrgayman/zavatar-runpod:sadtalker-latest
3. Set GPU type: RTX 3090 or A40 (16GB+ VRAM)
4. Set container disk: 20 GB
5. Set env var RENDER_ENGINE=sadtalker (or liveportrait)
6. Create a Serverless Endpoint using this template

## API

The handler accepts JSON with audio_url, portrait_url, quality, format, job_id, supabase_url, supabase_key.
Returns JSON with video_url.
