"""
Engine-agnostic RunPod Serverless Handler for Z-Avatar video generation.

The rendering engine is selected by the RENDER_ENGINE environment variable:
  - "sadtalker"  (default) — audio-driven, works out of the box
  - "liveportrait"        — higher quality, requires audio-to-motion bridge

The edge function pipeline never changes — it always sends audio_url + portrait_url
and receives video_url back. Swapping engines is a Docker config change only.
"""

import sys
print("[zavatar] Python process started", flush=True)
print(f"[zavatar] Python: {sys.version}", flush=True)
print(f"[zavatar] sys.path: {sys.path}", flush=True)

import os
import time
import base64
import urllib.request
import urllib.error
import shutil

print("[zavatar] Core imports OK", flush=True)

import runpod

print(f"[zavatar] runpod {runpod.__version__ if hasattr(runpod, '__version__') else '?'} imported OK", flush=True)

OUTPUT_DIR = "/app/outputs"
INPUT_DIR = "/app/inputs"


def ensure_dirs():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    os.makedirs(INPUT_DIR, exist_ok=True)


def download_file(url, dest_path):
    req = urllib.request.Request(url)
    req.add_header("User-Agent", "ZimpleZAvatar/1.0")
    with urllib.request.urlopen(req, timeout=120) as resp:
        with open(dest_path, "wb") as f:
            while True:
                chunk = resp.read(8192)
                if not chunk:
                    break
                f.write(chunk)


def upload_to_storage(local_path, job_id, fmt):
    supabase_url = os.environ.get("SUPABASE_URL", "")
    service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")

    if not supabase_url or not service_key:
        return None

    ext = "webm" if fmt == "webm" else "mp4"
    storage_path = f"avatars/{job_id}.{ext}"
    content_type = "video/webm" if fmt == "webm" else "video/mp4"

    with open(local_path, "rb") as f:
        file_data = f.read()

    upload_url = f"{supabase_url}/storage/v1/object/zavatar-videos/{storage_path}"

    req = urllib.request.Request(upload_url, data=file_data, method="POST")
    req.add_header("Authorization", f"Bearer {service_key}")
    req.add_header("Content-Type", content_type)
    req.add_header("x-upsert", "true")

    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            resp.read()
    except urllib.error.HTTPError as e:
        print(f"Upload failed: {e.code} {e.reason}")
        body = e.read().decode("utf-8", errors="replace")
        print(f"Response: {body}")
        return None

    return f"{supabase_url}/storage/v1/object/public/zavatar-videos/{storage_path}"


def get_engine(job_input):
    engine_name = os.environ.get("RENDER_ENGINE", "sadtalker").lower()
    print(f"[zavatar] Loading engine: {engine_name}", flush=True)

    if engine_name == "sadtalker":
        from engines.sadtalker_engine import SadTalkerEngine
        return SadTalkerEngine()
    elif engine_name == "liveportrait":
        from engines.liveportrait_engine import LivePortraitEngine
        return LivePortraitEngine()
    else:
        raise RuntimeError(
            f"Unknown RENDER_ENGINE '{engine_name}'. Use 'sadtalker' or 'liveportrait'."
        )


def handler(job):
    ensure_dirs()

    job_input = job.get("input", {})
    audio_url = job_input.get("audio_url", "")
    portrait_url = job_input.get("portrait_url", "")
    quality = job_input.get("quality", "720p")
    fmt = job_input.get("format", "mp4")
    job_id = job_input.get("job_id", f"job-{int(time.time())}")

    supabase_url = job_input.get("supabase_url", "")
    supabase_key = job_input.get("supabase_key", "")
    if supabase_url:
        os.environ["SUPABASE_URL"] = supabase_url
    if supabase_key:
        os.environ["SUPABASE_SERVICE_ROLE_KEY"] = supabase_key

    if not audio_url:
        return {"error": "audio_url is required"}
    if not portrait_url:
        return {"error": "portrait_url is required"}

    engine = get_engine(job_input)
    engine_name = engine.name
    print(f"[{engine_name}] Starting video generation for job {job_id}")
    print(f"[{engine_name}] Audio: {audio_url}")
    print(f"[{engine_name}] Portrait: {portrait_url}")
    print(f"[{engine_name}] Quality: {quality}, Format: {fmt}")

    audio_path = os.path.join(INPUT_DIR, f"{job_id}_audio.mp3")
    portrait_path = os.path.join(INPUT_DIR, f"{job_id}_portrait.png")

    try:
        print(f"[{engine_name}] Downloading audio...")
        download_file(audio_url, audio_path)
        print(f"[{engine_name}] Downloading portrait...")
        download_file(portrait_url, portrait_path)
    except Exception as e:
        return {"error": f"Download failed: {str(e)}"}

    job_output_dir = os.path.join(OUTPUT_DIR, job_id)
    os.makedirs(job_output_dir, exist_ok=True)

    try:
        video_path = engine.generate(audio_path, portrait_path, job_output_dir, quality)
        print(f"[{engine_name}] Video generated: {video_path}")
    except Exception as e:
        return {"error": f"{engine_name} inference failed: {str(e)}"}

    video_url = upload_to_storage(video_path, job_id, fmt)

    if not video_url:
        print(f"[{engine_name}] Upload to Supabase failed, trying base64 fallback")
        video_size = os.path.getsize(video_path)
        if video_size < 50 * 1024 * 1024:
            with open(video_path, "rb") as f:
                video_b64 = base64.b64encode(f.read()).decode("utf-8")
            return {
                "video_base64": video_b64,
                "video_format": fmt,
                "video_size_bytes": video_size,
            }
        return {"error": "Failed to upload video and file too large for base64"}

    try:
        os.remove(audio_path)
        os.remove(portrait_path)
        shutil.rmtree(job_output_dir, ignore_errors=True)
    except Exception:
        pass

    print(f"[{engine_name}] Video generation complete: {video_url}")
    return {"video_url": video_url}


print("[zavatar] All imports OK, starting RunPod serverless loop...", flush=True)
runpod.serverless.start({"handler": handler})
