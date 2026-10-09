# Milestone 1: Voice Input & Multilingual Speech Processing

## 1. Objective
Our goal for this first milestone was to remove the keyboard typing barrier so that users (especially kids or non-technical people) can create stories simply by speaking into their phones. We also wanted to support regional languages like Hindi and Punjabi so users are not forced to speak only in English.

---

## 2. Why We Did This (Research Context)
Typing long stories on small mobile screens is slow and frustrating. Most storytelling apps only accept typed English prompts. In our research, we wanted to answer:
- *Can we capture natural spoken audio on a mobile phone and convert it into accurate English story prompts, even when the user speaks in Hindi or Punjabi?*

---

## 3. What We Implemented

### A. Mobile Audio Capture (Flutter)
- In `frontend/vibestory/lib/main.dart` inside `_HomeScreenState`:
  - We used the `record` package to record speech directly from the device's microphone.
  - We handled runtime microphone permissions with `permission_handler`.
  - We added a pulsing red recording indicator (`_PulseCircle`) so users know the app is listening.
  - We saved audio into temporary local files (`.m4a`) and added a file picker using `file_picker` for users who already have audio files.

### B. Speech Transcription & Translation Server (FastAPI)
- In `backend/app.py`:
  - Created the endpoint `POST /api/input/transcribe`.
  - Integrated OpenAI's **Whisper** model (`WHISPER_MODEL = "small"`).
  - Used `_sync_transcribe(audio_path)` with thread offloading so the server stays fast and doesn't freeze.
  - When speech is processed:
    1. Whisper first detects the language.
    2. If it is already English, it returns the text.
    3. If it detects a non-English language (like Hindi or Punjabi), it automatically runs `model.transcribe(..., task="translate")` to produce an accurate English translation.

### C. Frontend Feedback
- In the mobile UI:
  - If a translation happened, the app displays a teal pill badge: *"Translated from hi"* or *"Translated from pa"*.
  - The transcribed English text automatically fills the story prompt box so the user can review and edit it before generating the story.

---

## 4. Key Challenges & How We Solved Them
1. **Audio format differences across devices:** Some phones send `.m4a`, others `.webm` or `.wav`. We solved this by using temporary file suffixes and passing the file path directly to Whisper, which uses FFmpeg under the hood.
2. **GPU memory spike during model loading:** Whisper models can take memory on startup. We used lazy loading (`_load_whisper()`) so the model only loads when an audio file actually arrives.

---

## 5. Milestone Outcome
- Users can talk naturally into their phone in English, Hindi, or Punjabi.
- The audio is accurately transcribed and translated into English within a few seconds.
- We have clean text ready for the story generation stage.
