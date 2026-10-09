# Milestone 2: Multimodal Story & Visual Art Generation

## 1. Objective
Our goal for Milestone 2 was to take the transcribed story text and transform it into a complete, illustrated digital storybook with matching voice narration and synchronized playback.

---

## 2. Why We Did This (Research Context)
Reading pure text is often boring for young audiences. We wanted to see:
- *Can we automatically divide an unstructured story into sequential visual scenes?*
- *Can we generate consistent, warm Studio Ghibli–style illustrations for each scene?*
- *Can we synthesize high-quality human-sounding narration and synchronize it with the pictures so the slides turn automatically as the voice reads?*

---

## 3. What We Implemented

### A. Story Chunking Algorithm
- In `backend/app.py`:
  - Created `chunk_story(text, num_chunks)`:
    - Splits the story based on full stops (sentences).
    - If there are enough sentences, it groups them evenly into parts.
    - If sentences are short or few, it splits by words so every scene has unique context.
  - Users can choose how many scenes they want (from 1 to 15 scenes) using a slider in the Flutter app.

### B. Studio Ghibli Diffusion Pipeline
- We integrated the `nitrosocke/Ghibli-Diffusion` model using HuggingFace Diffusers.
- In `build_prompt(sentence)`:
  - We remove noisy filler words (like *the, a, and, was*).
  - We append prompt engineering keywords:
    `"Ghibli style, <sentence>, hand-drawn anime illustration, soft colors, beautiful detailed background, whimsical atmosphere, children's book art, highly detailed, masterpiece"`
  - We added negative prompts to avoid distortions: `"ugly, blurry, bad anatomy, watermark, text, scary, violent"`.
  - Output images are created at a clean landscape size (800 by 400 pixels) with 30 diffusion steps.

### C. Neural Voice Narration (Kokoro TTS)
- We integrated Kokoro ONNX (`kokoro-v1.0.onnx` and `voices.bin`) using a natural storytelling voice (`af_heart`) at a calm, comfortable pace.
- Narration audio is generated directly as a sound file in `static/audio/{story_id}.wav`.
- We added an automatic fallback to `pyttsx3` in case Kokoro is not installed on a target machine.

### D. Background Queue & Progress Polling
- Generating multiple AI images takes between 20 to 40 seconds.
- We used FastAPI background tasks so the server does not freeze.
- The Flutter mobile app checks the server every 2 seconds to see progress.
- As each picture finishes, it pops up on the phone screen in real time.

### E. Synchronized Audio-Visual Story Player
- In `StoryPlayScreen` (`frontend/vibestory/lib/main.dart`):
  - Streams the story narration audio.
  - Tracks playback progress continuously.
  - As the narrator speaks, the app calculates how far along the story is. For example, when the audio is halfway through, the screen automatically turns to the middle illustration.
  - Smooth visual fade transitions connect the scenes.
  - Includes manual previous and next buttons and an audio timeline slider for scrubbing.

---

## 4. Key Challenges & How We Solved Them
1. **Long waiting times for image generation:** AI image models take time to paint pictures. We solved user impatience by building a live progress screen showing clear status messages ("Drawing image 1 of 5...", "Generating narration...") and showing completed images as they finish.
2. **Synchronizing audio with pictures easily:** Instead of needing complicated speech-alignment models, we divided the audio timeline evenly across the story parts. This allows the pages to turn naturally as the audio plays without any lagging.

---

## 5. Milestone Outcome
- A full multimodal generator that turns simple text into an illustrated book with voice narration.
- High-quality Ghibli-themed artistic style across all scenes.
- An interactive storybook player in Flutter where pictures change automatically as the voice reads aloud.
