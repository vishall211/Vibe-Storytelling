# VibeStory

VibeStory is a mobile app that turns voice input into an illustrated and narrated story.

The project has two parts:

- `backend/` - FastAPI server written in Python
- `frontend/vibestory/` - Flutter mobile app

## Features

- User signup and login
- Voice input transcription
- AI story scene generation
- Image generation for each story part
- Narration audio using Kokoro TTS
- Object detection and label collection for YOLO training

## Tech Stack

| Part | Technology |
|---|---|
| Mobile app | Flutter |
| Backend | FastAPI |
| Database | MongoDB |
| Speech-to-text | Whisper |
| Image generation | Diffusers |
| Text-to-speech | Kokoro ONNX |
| Object detection | YOLO |

## Folder Structure

```text
vibestory/
├── backend/
│   ├── app.py
│   ├── train.py
│   └── requirements.txt
└── frontend/
    └── vibestory/
        ├── lib/main.dart
        └── pubspec.yaml
```

## Requirements

Install these before running the project:

- Python 3.10 or newer
- Flutter SDK
- MongoDB
- Xcode or Android Studio, depending on the device you want to run

## Backend Setup

Go to the backend folder:

```bash
cd backend
```

Create and activate a virtual environment:

```bash
python3.12 -m venv .venv && source .venv/bin/activate
```

Install Python packages:

```bash
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

Create a `.env` file inside `backend/`:

```env
MONGO_URL=mongodb://localhost:27017
DB_NAME=vibestory
JWT_SECRET=replace_this_with_a_long_random_string
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

## Required Model Files

Place these files inside the `backend/` folder:

```text
kokoro-v1.0.onnx
voices.bin
```

Optional YOLO model:

```text
best.pt
```

If `best.pt` is missing, the backend uses `yolov8n.pt` as a fallback.

## Run Backend

Make sure MongoDB is running, then start the backend:

```bash
cd backend
source .venv/bin/activate
uvicorn app:app --host 0.0.0.0 --port 8000
```

Open this URL to check the backend:

```text
http://localhost:8000/api/health
```

## Frontend Setup

Go to the Flutter app folder:

```bash
cd frontend/vibestory
```

Install Flutter packages:

```bash
flutter pub get
```

## Run Frontend

If running on the same Mac:

```bash
flutter run --dart-define=BASE_URL=http://localhost:8000
```

If running on a physical phone, use your Mac's Wi-Fi IP:

```bash
ipconfig getifaddr en0
```

Then run:

```bash
flutter run --dart-define=BASE_URL=http://YOUR_MAC_IP:8000
```

Example:

```bash
flutter run --dart-define=BASE_URL=http://192.168.1.12:8000
```

## Useful API Routes

| Method | Route | Use |
|---|---|---|
| POST | `/api/auth/signup` | Create account |
| POST | `/api/auth/login` | Login |
| POST | `/api/story/generate` | Generate story |
| GET | `/api/story/{story_id}/status` | Check story status |
| GET | `/api/profile` | Get user profile |
| POST | `/api/learn/detect` | Detect objects |
| POST | `/api/learn/submit-labels` | Save labels |
| GET | `/api/health` | Check server health |

## YOLO Training

The app saves labelled images inside:

```text
backend/yolo_dataset/
```

To check the dataset:

```bash
cd backend
source .venv/bin/activate
python train.py --check
```

To train:

```bash
python train.py
```

After training, keep the final model as:

```text
backend/best.pt
```

## Common Issues

### ClientException: Failed to fetch

Check these:

- Backend is running on port `8000`
- Phone and Mac are on the same Wi-Fi
- `BASE_URL` uses your Mac IP when running on a phone
- Health check opens on the phone: `http://YOUR_MAC_IP:8000/api/health`
- Whisper and Ghibli-Diffusion download automatically on first use (~4GB total). Keep internet on for first run.
- The YOLO dataset grows every time a user labels objects. Export and back it up regularly.

### Signup gives server error

Install the backend dependencies again:

```bash
cd backend
source .venv/bin/activate
python -m pip install -r requirements.txt
```

### Audio is not generated

Check that these files exist in `backend/`:

```text
kokoro-v1.0.onnx
voices.bin
```

## Do Not Commit

These files and folders are local only:

```text
backend/.env
backend/.venv/
backend/hf_cache/
backend/static/
backend/yolo_dataset/
backend/*.pt
backend/*.onnx
backend/voices.bin
```
