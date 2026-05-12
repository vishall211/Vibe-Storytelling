# VibeStory 🎙️✨

> **Speak about the world around you. Get a Ghibli-style illustrated story.**

VibeStory is an AI-powered mobile app where users point their camera at objects, record their voice, and receive a fully illustrated, narrated story — rendered in Studio Ghibli art style with ambient audio.

---

## 🏗️ Architecture

```
vibestory/
├── backend/          ← FastAPI server (Python)
│   ├── app.py        ← main server, all API routes
│   ├── train.py      ← YOLO fine-tuner
│   └── requirements.txt
│
└── frontend/
    └── vibestory/    ← Flutter mobile app
        ├── lib/
        │   └── main.dart
        └── pubspec.yaml
```

| Layer | Technology |
|---|---|
| Mobile App | Flutter (Android & iOS) |
| Backend API | FastAPI + Uvicorn |
| Database | MongoDB |
| Speech-to-Text | OpenAI Whisper (local) |
| Image Generation | Ghibli-Diffusion (local) |
| Text-to-Speech | Kokoro ONNX (local) |
| Object Detection | YOLOv11 (fine-tuned) |

---

## ⚙️ Backend Setup

### 1. Prerequisites
- Python 3.10 or 3.12
- MongoDB running locally (`mongodb://localhost:27017`) or MongoDB Atlas URL
- NVIDIA GPU strongly recommended for image generation (CPU works but is slow)

### 2. Install dependencies

```bash
cd backend
pip install -r requirements.txt
```

### 3. Install Kokoro TTS manually

Kokoro is not on pip — download the model files from Hugging Face:

```
https://huggingface.co/hexgrad/Kokoro-82M
```

Download these two files and place them in the `backend/` folder:
- `kokoro-v1.0.onnx`
- `voices.bin`

Then install the Python wrapper:
```bash
pip install kokoro-onnx soundfile
```

### 4. YOLO model (`best.pt`)

The fine-tuned `best.pt` is **not committed to GitHub** (too large).

- Get it from the team Google Drive
- Place it in `backend/`
- If missing, app automatically falls back to `yolov8n.pt`

### 5. Create your `.env` file

```bash
cp .env.example .env
```

Edit `.env`:
```
MONGO_URL=mongodb://localhost:27017
DB_NAME=vibestory
JWT_SECRET=replace_this_with_a_long_random_string
WHISPER_MODEL=small
YOLO_MODEL=best.pt
```

> ⚠️ Never commit `.env` to GitHub. The JWT_SECRET signs all login tokens — keep it private.

### 6. Run the server

```bash
uvicorn app:app --host 0.0.0.0 --port 8000
```

Server starts at `http://localhost:8000`. Check health at `http://localhost:8000/api/health`.

---

## 📱 Flutter Setup

### 1. Prerequisites
- Flutter SDK 3.x — [flutter.dev](https://flutter.dev)
- Android Studio or VS Code with Flutter extension
- Android device or emulator

### 2. Install packages

```bash
cd frontend/vibestory
flutter pub get
```

### 3. Add the app icon

Place your icon at:
```
frontend/vibestory/assets/icon.png
```

### 4. Run the app

```bash
# Replace with your machine's local IP (run `ipconfig` on Windows to find it)
flutter run --dart-define=BASE_URL=http://192.168.x.x:8000
```

Or edit `kBaseUrl` directly in `lib/main.dart` for quick local testing.

---

## 🧠 Training the YOLO Model

Users label objects in the app → labels are saved to `yolo_dataset/` automatically.

```bash
cd backend

# Check your dataset is healthy before training
python train.py --check

# Train (fine-tunes from best.pt or yolo11l.pt)
python train.py

# Override hyperparameters
EPOCHS=50 BATCH=4 python train.py
```

After training, `best.pt` is written next to `train.py`. Share it via Google Drive with the team.

---

## 📦 What is NOT in this repo

These files are too large or machine-specific for GitHub:

| File/Folder | Why excluded | Where to get it |
|---|---|---|
| `best.pt` | 300MB+ model weight | Team Google Drive |
| `kokoro-v1.0.onnx` | 300MB TTS model | Hugging Face (link above) |
| `voices.bin` | TTS voice data | Hugging Face (link above) |
| `hf_cache/` | Whisper + Ghibli models auto-download | Auto on first run |
| `yolo_dataset/` | User-generated training data | Export via `/api/learn/export-dataset` |
| `.env` | Secrets | Copy from `.env.example` |

---

## 🌐 API Endpoints

| Method | Route | Description |
|---|---|---|
| POST | `/api/auth/register` | Create account |
| POST | `/api/auth/login` | Login, get JWT token |
| POST | `/api/story/create` | Start story pipeline |
| GET | `/api/story/{id}/status` | Poll story progress |
| GET | `/api/profile` | User stats + story history |
| POST | `/api/learn/detect` | YOLO object detection |
| POST | `/api/learn/submit-labels` | Submit labelled image |
| GET | `/api/learn/export-dataset` | Download full YOLO dataset ZIP |
| GET | `/api/health` | Server + model status |

---

## 🚀 Fresh Machine Setup (quick reference)

```bash
# 1. Clone
git clone https://github.com/yourname/vibestory
cd vibestory

# 2. Backend
cd backend
pip uninstall bson -y          # fix common conflict
pip install -r requirements.txt
pip install kokoro-onnx soundfile
cp .env.example .env           # fill in your values
# → copy best.pt, kokoro-v1.0.onnx, voices.bin from Google Drive
uvicorn app:app --host 0.0.0.0 --port 8000

# 3. Flutter (new terminal)
cd frontend/vibestory
flutter pub get
flutter run --dart-define=BASE_URL=http://YOUR_IP:8000
```

---

## 👥 Team

| Role | Responsibility |
|---|---|
| Backend | `app.py`, `train.py`, MongoDB, model hosting |
| Frontend | `main.dart`, Flutter build, APK distribution |

---

## 📝 Notes

- Whisper and Ghibli-Diffusion download automatically on first use (~4GB total). Keep internet on for first run.
- Image generation is slow on CPU (~2–5 min per image). Use GPU if possible.
- The YOLO dataset grows every time a user labels objects. Export and back it up regularly.
