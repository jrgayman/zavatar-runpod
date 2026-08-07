"""
Base interface for portrait animation engines.

Every engine implements generate() which takes an audio file and a portrait
image, produces a talking-head video, and returns the local path to the video.

The edge function never changes — it always sends audio_url + portrait_url
and receives video_url back. Swapping engines is a Docker config change only.
"""

from abc import ABC, abstractmethod


class BaseEngine(ABC):
    name = "base"

    @abstractmethod
    def generate(self, audio_path, portrait_path, output_dir, quality="720p"):
        """
        Generate a talking-head video from audio + portrait.

        Args:
            audio_path:   Local path to audio file (mp3/wav)
            portrait_path: Local path to portrait image (png/jpg)
            output_dir:   Directory to write the output video
            quality:      "480p", "720p", or "1080p"

        Returns:
            Local path to the generated video file.
        """
        raise NotImplementedError
