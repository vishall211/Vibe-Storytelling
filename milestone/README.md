# VibeStory Research Project Milestones

Welcome to the project milestones for **VibeStory**. 

This research project is divided into **four main milestones**. Each milestone represents a core phase of our system, moving from speech processing to multimodal generation, interactive human-in-the-loop annotation, and finally dataset building with model fine-tuning.

---

## 📋 Overview of Milestones

| Milestone | Title | Focus Area | Key Technologies |
|---|---|---|---|
| **[Milestone 1](milestone_1_voice_and_multilingual_input.md)** | Voice Input & Multilingual Speech Processing | Audio recording, speech-to-text, and Hindi/Punjabi to English translation | Flutter `record`, OpenAI Whisper |
| **[Milestone 2](milestone_2_story_and_art_generation.md)** | Multimodal Story & Visual Art Generation | Story segmentation, Ghibli illustration synthesis, and voice narration | Stable Diffusion (Ghibli), Kokoro TTS, `audioplayers` |
| **[Milestone 3](milestone_3_interactive_object_detection.md)** | Interactive Object Detection & Human-in-the-Loop Labeling | On-image object detection, touch-based box drawing, label correction, and gamification | YOLOv8/11, Flutter Gesture Canvas, MongoDB |
| **[Milestone 4](milestone_4_dataset_and_model_training.md)** | Dataset Pipeline, Data Augmentation & Model Fine-Tuning | Normalized dataset generation, Albumentations image augmentation, and continuous learning | YOLO dataset format, Albumentations, Ultralytics YOLO |

---

## 🔄 Research Workflow

```
[User Voice Input (Hindi / Punjabi / English)]
                     │
                     ▼
       ┌───────────────────────────┐
       │        Milestone 1        │  Whisper Audio Transcription & Translation
       └─────────────┬─────────────┘
                     ▼
       ┌───────────────────────────┐
       │        Milestone 2        │  Ghibli Image Synthesis + Kokoro Narration
       └─────────────┬─────────────┘
                     ▼
       ┌───────────────────────────┐
       │        Milestone 3        │  Interactive Object Detection & BBox Drawing
       └─────────────┬─────────────┘
                     ▼
       ┌───────────────────────────┐
       │        Milestone 4        │  YOLO Dataset Creation & Model Fine-Tuning
       └───────────────────────────┘
```

---

## 📂 Detailed Documentation

Click each milestone file to read the complete breakdown, implementation details, and findings:

1. [Milestone 1: Voice Input & Multilingual Speech Processing](milestone_1_voice_and_multilingual_input.md)
2. [Milestone 2: Multimodal Story & Visual Art Generation](milestone_2_story_and_art_generation.md)
3. [Milestone 3: Interactive Object Detection & Human-in-the-Loop Labeling](milestone_3_interactive_object_detection.md)
4. [Milestone 4: Dataset Pipeline, Data Augmentation & Model Fine-Tuning](milestone_4_dataset_and_model_training.md)
