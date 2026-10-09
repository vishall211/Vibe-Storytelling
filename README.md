# 📖 VibeStory: Voice-to-Illustrated Storytelling Mobile App

> **An AI-powered multimodal mobile application that turns spoken or written ideas into illustrated Studio Ghibli–style storybooks with synchronized voice narration and interactive object detection.**

---

## 🌟 What is VibeStory?

**VibeStory** is an end-to-end research project and mobile application combining Generative AI, Speech Recognition, and Computer Vision:
1. **Speak or Type:** Speak your story in English, Hindi, or Punjabi, or type it out manually.
2. **AI Multimodal Generation:** The app segments the story into scenes, generates custom anime-style illustrations using **Ghibli-Diffusion**, and creates natural narration with **Kokoro TTS**.
3. **Synchronized Playback:** Read and listen as the app turns pages automatically in sync with the narrator's voice.
4. **Interactive Active Learning:** Explore objects in the pictures, verify AI-detected bounding boxes, draw your own boxes on-screen, and earn explorer points. The system saves your annotations into a YOLO dataset to fine-tune future object detection models.

---

## 🏛️ System Architecture

```
[User Voice (Hindi / Punjabi / English)]
                │
                ▼ (Microphone Capture)
    ┌───────────────────────────┐
    │     1. Whisper AI STT     │ ──► Transcribes & translates speech to English text
    └─────────────┬─────────────┘
                  ▼
    ┌───────────────────────────┐
    │     2. Story Chunking     │ ──► Splits text into sequential scenes
    └─────────────┬─────────────┘
                  ▼
    ┌───────────────────────────┐
    │  3. Multimodal Synthesis  │ ──► Stable Diffusion (Ghibli art) + Kokoro TTS (.wav)
    └─────────────┬─────────────┘
                  ▼
    ┌───────────────────────────┐
    │  4. Synchronized Player   │ ──► Plays audio & auto-advances scene illustrations
    └─────────────┬─────────────┘
                  ▼
    ┌───────────────────────────┐
    │   5. Interactive Canvas   │ ──► YOLO inference + touch bounding box labeling
    └─────────────┬─────────────┘
                  ▼
    ┌───────────────────────────┐
    │  6. Continuous Training   │ ──► Auto-generates YOLO dataset + Albumentations fine-tuning
    └───────────────────────────┘
```

---

## 🎯 Research Milestones

This project was developed across four core research milestones. Detailed, student-friendly documentation for each milestone is located in the [`milestone/`](milestone/README.md) directory:

| Milestone | Focus Area | What Was Accomplished |
|---|---|---|
| **[Milestone 1](milestone/milestone_1_voice_and_multilingual_input.md)** | Voice & Multilingual Input | Mobile audio recording, Whisper transcription, and Hindi/Punjabi to English translation. |
| **[Milestone 2](milestone/milestone_2_story_and_art_generation.md)** | Multimodal Generation | Story segmentation, Studio Ghibli art diffusion, Kokoro TTS narration, and time-synced playback. |
| **[Milestone 3](milestone/milestone_3_interactive_object_detection.md)** | Interactive CV & Labeling | YOLO detection on illustrations, touch bounding box drawing canvas, and gamified explorer points. |
| **[Milestone 4](milestone/milestone_4_dataset_and_model_training.md)** | Dataset Pipeline & Training | Auto-creating YOLO datasets, Albumentations image augmentation, and continuous model fine-tuning. |

---

## 📁 Project Folder Structure

```text
Vibe storytelling/
├── requirements.txt            # 📦 Python backend dependencies (root copy)
├── PROJECT_REPORT.md           # 📄 Comprehensive technical project report
├── README.md                   # 📖 This documentation file
├── STORY.txt                   # 📚 Sample benchmark story prompts
├── backend/
│   ├── app.py                  # 🚀 Main FastAPI server (APIs, AI models, dataset engine)
│   ├── train.py                # 🧠 YOLO fine-tuning & Albumentations augmentation
│   ├── ngrok_tunnel.py         # 🌐 Remote tunnel for physical phone testing
│   ├── requirements.txt        # 📦 Python backend dependencies
│   ├── kokoro-v1.0.onnx        # 🎙️ Kokoro TTS speech model
│   ├── voices.bin              # 🔊 Kokoro voice weights
│   ├── yolov8n.pt              # 🔍 Base YOLO object detection model
│   ├── static/                 # 🖼️ Generated story images & audio files
│   └── yolo_dataset/           # 🗃️ Auto-generated dataset from user labels
│       ├── images/ (train, val)
│       ├── labels/ (train, val)
│       ├── classes.txt
│       └── dataset.yaml
├── frontend/
│   └── vibestory/              # 📱 Flutter mobile application
│       ├── lib/
│       │   └── main.dart       # Complete UI (Auth, Home, Player, Learn, Profile)
│       ├── pubspec.yaml        # Flutter packages and assets setup
│       └── assets/icon.png
└── milestone/                  # 🎓 Research milestone documentation
    ├── README.md               # Milestones overview and workflow
    ├── milestone_1_voice_and_multilingual_input.md
    ├── milestone_2_story_and_art_generation.md
    ├── milestone_3_interactive_object_detection.md
    └── milestone_4_dataset_and_model_training.md
```

---

## 🛠️ Tech Stack & Requirements

| Layer | Technology | Purpose |
|---|---|---|
| **Mobile App** | Flutter (Dart) | Cross-platform mobile UI (iOS, Android, macOS) |
| **Backend API** | FastAPI + Uvicorn | Async REST API and background task executor |
| **Database** | MongoDB | Storing user accounts, scores, and story history |
| **Speech-to-Text** | OpenAI Whisper | Audio transcription & multilingual translation |
| **Image Generation** | Diffusers (Ghibli-Diffusion) | Studio Ghibli anime art generation |
| **Text-to-Speech** | Kokoro ONNX | Natural, lightweight neural voice narration |
| **Object Detection** | Ultralytics YOLO (v8 / 11) | Detecting objects in generated artwork |
| **Data Augmentation** | Albumentations | Geometric & photometric dataset expansion |

---

## 📦 What is in `requirements.txt`?

The project relies on `requirements.txt` to install all backend machine learning and web server packages:

- **Web Server:** `fastapi`, `uvicorn`, `python-multipart`, `pydantic`
- **Database & Auth:** `motor`, `pymongo`, `passlib[bcrypt]`, `pyjwt`, `python-jose`
- **Speech AI:** `openai-whisper`, `kokoro-onnx`, `soundfile`
- **Image AI:** `diffusers==0.21.4`, `transformers==4.38.2`, `torch==2.4.1`, `torchvision`, `accelerate`
- **Computer Vision:** `ultralytics`, `albumentations`, `opencv-python`, `pillow`
- **Utilities:** `numpy`, `pyyaml`, `python-dotenv`

---

## 🚀 Quick Start Guide

### Step 1: Clone & Setup Backend

Make sure **Python 3.10+** and **MongoDB** are installed and running.

```bash
# 1. Navigate to the backend folder (or project root)
cd backend

# 2. Create and activate a Python virtual environment
python3 -m venv .venv
source .venv/bin/activate

# 3. Upgrade pip and install all dependencies
pip install --upgrade pip
pip install -r requirements.txt
```

### Step 2: Configure Environment Variables

Create a `.env` file inside `backend/`:

```env
MONGO_URL=mongodb://localhost:27017
DB_NAME=vibestory
JWT_SECRET=vibestory_secret_key_change_in_production
WHISPER_MODEL=small
YOLO_MODEL=best.pt
IMAGE_STEPS=30
IMAGE_CFG=5.0
IMAGE_W=800
IMAGE_H=400
KOKORO_VOICE=af_heart
DEFAULT_NUM_IMGS=5
DATASET_DIR=yolo_dataset
```

### Step 3: Model Weights Verification

Ensure the following model weight files exist in `backend/`:
- `kokoro-v1.0.onnx` (TTS neural model)
- `voices.bin` (TTS voice embeddings)
- `yolov8n.pt` or `best.pt` (Object detection model)

*(Note: Whisper and Ghibli-Diffusion will automatically download to cache on their very first run).*

### Step 4: Run the Backend Server

```bash
# Start the FastAPI server
uvicorn app:app --host 0.0.0.0 --port 8000
```

Verify it is running by opening: **`http://localhost:8000/api/health`**

---

### Step 5: Setup & Run the Mobile App (Flutter)

In a separate terminal:

```bash
cd frontend/vibestory

# Install Flutter dependencies
flutter pub get

# Run on simulator / local computer:
flutter run --dart-define=BASE_URL=http://localhost:8000
```

#### Running on a Physical Phone:
Find your computer's local Wi-Fi IP address:
```bash
ipconfig getifaddr en0
```
Then launch Flutter pointing to your computer's IP:
```bash
flutter run --dart-define=BASE_URL=http://YOUR_LOCAL_IP:8000
```

*(Alternatively, run `python ngrok_tunnel.py` to create a public HTTPS URL and pass that as `BASE_URL`).*

---

## 🧠 Active Learning & YOLO Fine-Tuning

Every time you or a user draws boxes in the app's **"Learn"** screen, the images and labels are automatically saved into `backend/yolo_dataset/`.

### 1. Check Dataset Health
Inspect the number of labeled images and class distributions:
```bash
cd backend
source .venv/bin/activate
python train.py --check
```

### 2. Fine-Tune the YOLO Model
Run the data augmentation pipeline and train the model:
```bash
python train.py
```
This script:
1. Applies 5 Albumentations transformations (flips, rotations, contrast, blur) per image.
2. Trains the YOLO model with early stopping.
3. Automatically outputs an updated `best.pt` weights file.
4. The backend server immediately loads the newly trained `best.pt` for all future detections!

### 3. Export Dataset
Download the entire dataset as a `.zip` file from the app or via:
`GET http://localhost:8000/api/learn/export-dataset`

---

## 📡 API Reference Summary

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/auth/signup` | Register a new user account |
| `POST` | `/api/auth/login` | Authenticate user and receive JWT token |
| `GET` | `/api/auth/me` | Retrieve profile and current score |
| `POST` | `/api/input/transcribe` | Transcribe and translate voice audio |
| `POST` | `/api/story/generate` | Start async story generation pipeline |
| `GET` | `/api/story/{id}/status` | Poll progress of images and narration |
| `GET` | `/api/profile` | Retrieve user stats, badges, and past stories |
| `POST` | `/api/learn/detect` | Run YOLO object detection on story image |
| `POST` | `/api/learn/submit-labels` | Submit user annotations, earn +10 points |
| `GET` | `/api/learn/dataset-stats` | Inspect current size of training dataset |
| `GET` | `/api/learn/export-dataset` | Download zipped YOLO dataset |
| `GET` | `/api/health` | Check GPU status and model readiness |

---

## 👥 Contributors & Academic Context

This project was built as a research exploration into multimodal AI, accessible voice interfaces, and human-in-the-loop computer vision workflows. 

For full technical specifications and experimental methodology, refer to [PROJECT_REPORT.md](PROJECT_REPORT.md) and the [milestone/](milestone/README.md) folder.
