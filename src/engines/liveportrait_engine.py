"""
LivePortrait engine - higher-quality portrait animation via video-driven rendering.

LivePortrait (KwaiVGI) produces smoother, more realistic facial animation than
SadTalker, but it is video-driven, not audio-driven. It animates a portrait by
copying motion from a driving video, not from an audio file.

To use LivePortrait for talking-head generation from audio, we use a two-stage
pipeline:
  1. SadTalker pass: audio + portrait -> rough talking-head video (provides
     lip-sync and head motion driven by the audio signal).
  2. LivePortrait pass: original portrait + SadTalker video as driving input ->
     high-quality re-rendered talking-head video.

The SadTalker video does not need to look good - it just needs the right motion.
LivePortrait extracts motion from it and re-renders onto the source portrait.
"""

import os
import glob
import subprocess
import shutil

from engines.base_engine import BaseEngine

SADTALKER_DIR = "/app/SadTalker"
LIVEPORTRAIT_DIR = "/app/LivePortrait"


class LivePortraitEngine(BaseEngine):
    name = "liveportrait"

    def generate(self, audio_path, portrait_path, output_dir, quality="720p"):
        if not os.path.isdir(LIVEPORTRAIT_DIR):
            raise RuntimeError(
                "LivePortrait is not installed in this Docker image. "
                "Build with RENDER_ENGINE=liveportrait."
            )
        if not os.path.isdir(SADTALKER_DIR):
            raise RuntimeError(
                "SadTalker is required as the audio-to-motion bridge but is "
                "not installed in this Docker image."
            )

        # Stage 1: SadTalker produces a rough talking-head video from audio.
        driving_video = self._sadtalker_pass(audio_path, portrait_path, output_dir, quality)

        # Stage 2: LivePortrait re-renders with higher quality.
        final_video = self._liveportrait_pass(portrait_path, driving_video, output_dir, quality)

        return final_video

    def _sadtalker_pass(self, audio_path, portrait_path, output_dir, quality):
        """Run SadTalker to produce a driving video with audio-synced motion."""
        sadtalker_out = os.path.join(output_dir, "sadtalker_pass")
        os.makedirs(sadtalker_out, exist_ok=True)

        cmd = [
            "python", "inference.py",
            "--driven_audio", audio_path,
            "--source_image", portrait_path,
            "--result_dir", sadtalker_out,
            "--enhancer", "gfpgan",
            "--expression_scale", "1.0",
            "--still",
            "--preprocess", "full",
        ]

        if quality in ("720p", "1080p"):
            cmd.extend(["--size", "512"])
        else:
            cmd.extend(["--size", "256"])

        print(f"[liveportrait] Stage 1 - SadTalker driving video: {' '.join(cmd)}")
        result = subprocess.run(
            cmd, cwd=SADTALKER_DIR, capture_output=True, text=True, timeout=300
        )
        if result.returncode != 0:
            raise RuntimeError(f"SadTalker pass failed: {result.stderr[-500:]}")

        video_files = (
            glob.glob(os.path.join(sadtalker_out, "*.mp4"))
            + glob.glob(os.path.join(sadtalker_out, "*.webm"))
            + glob.glob(os.path.join(sadtalker_out, "**", "*.mp4"), recursive=True)
            + glob.glob(os.path.join(sadtalker_out, "**", "*.webm"), recursive=True)
        )
        if not video_files:
            raise RuntimeError("SadTalker pass produced no video")
        video_files.sort(key=os.path.getmtime, reverse=True)
        print(f"[liveportrait] Driving video: {video_files[0]}")
        return video_files[0]

    def _liveportrait_pass(self, portrait_path, driving_video, output_dir, quality):
        """Run LivePortrait with the source portrait and SadTalker driving video."""
        lp_out = os.path.join(output_dir, "liveportrait_pass")
        os.makedirs(lp_out, exist_ok=True)

        cmd = [
            "python", "inference.py",
            "-s", portrait_path,
            "-d", driving_video,
            "-o", lp_out,
            "--flag_force_half_precision",
        ]

        print(f"[liveportrait] Stage 2 - LivePortrait inference: {' '.join(cmd)}")
        result = subprocess.run(
            cmd, cwd=LIVEPORTRAIT_DIR, capture_output=True, text=True, timeout=300
        )
        if result.returncode != 0:
            raise RuntimeError(f"LivePortrait inference failed: {result.stderr[-500:]}")

        video_files = (
            glob.glob(os.path.join(lp_out, "*.mp4"))
            + glob.glob(os.path.join(lp_out, "*.webm"))
            + glob.glob(os.path.join(lp_out, "**", "*.mp4"), recursive=True)
            + glob.glob(os.path.join(lp_out, "**", "*.webm"), recursive=True)
        )
        if not video_files:
            raise RuntimeError("LivePortrait pass produced no video")
        video_files.sort(key=os.path.getmtime, reverse=True)

        # Clean up the intermediate SadTalker video to save disk.
        sadtalker_out = os.path.join(output_dir, "sadtalker_pass")
        shutil.rmtree(sadtalker_out, ignore_errors=True)

        print(f"[liveportrait] Final video: {video_files[0]}")
        return video_files[0]
