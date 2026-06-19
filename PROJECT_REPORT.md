# VibeStory Project Report

## 1. Project Title

**VibeStory: Voice-to-Illustrated Storytelling Mobile Application**

VibeStory is an AI-powered mobile application that converts a user's spoken or written idea into an illustrated and narrated story. The application also includes a learning module where users can detect and label objects in generated story images, helping create a YOLO-compatible dataset for future object detection training.

## 2. Project Overview

VibeStory combines mobile app development, backend API development, database storage, speech recognition, image generation, text-to-speech, object detection, and dataset preparation into one complete system.

The project has two main parts:

- **Backend:** A Python FastAPI server located in `backend/`
- **Frontend:** A Flutter mobile application located in `frontend/vibestory/`

The backend handles authentication, AI processing, story generation, image generation, audio generation, object detection, user scores, and dataset storage. The Flutter app provides the user interface for login, story input, recording audio, viewing generated stories, playing narration, labeling objects, and checking profile progress.

## 3. What The Project Does

The project allows a user to:

1. Create an account or log in.
2. Enter a story idea manually or record/upload audio.
3. Convert audio into text using Whisper.
4. Translate non-English speech into English when needed.
5. Generate a story flow from the text.
6. Split the story into multiple parts.
7. Generate an image for each story part using Stable Diffusion.
8. Generate narration audio using Kokoro TTS.
9. View and play the final story with synchronized images and audio.
10. Open generated images in a learning screen.
11. Run YOLO object detection on story images.
12. Draw bounding boxes manually and label objects.
13. Save labeled data into a YOLO dataset folder.
14. Award user points for submitted labels.
15. Train a YOLO model later using the collected dataset.

## 4. Why This Project Was Made

The purpose of this project is to build an interactive AI storytelling system that makes story creation more engaging and educational.

The project solves several problems:

- Children or users can create stories without typing long text.
- Voice input makes the app easier to use.
- AI-generated images make stories visually interesting.
- Narration makes the story feel complete and accessible.
- The learning module turns passive story viewing into active object discovery.
- User-labeled images create a dataset that can improve object detection models.

The project is useful because it combines creativity, accessibility, and machine learning in a single application.

## 5. When Each Major Process Happens

Different parts of the system run at different times:

- **At app launch:** The Flutter app checks whether a saved JWT token exists.
- **At signup/login:** The backend creates or verifies a user and returns a JWT token.
- **When recording audio:** The mobile app records audio locally and sends it to the backend.
- **When audio is uploaded:** Whisper transcribes the audio and translates it if needed.
- **When story generation starts:** The backend creates a story record in MongoDB and starts a background task.
- **During background generation:** The backend splits the story, generates images, creates audio, and updates progress.
- **While the frontend waits:** The Flutter app polls the backend every 2 seconds for story status.
- **When generation is complete:** The user can play the story with images and narration.
- **When learning starts:** The user selects a generated image and runs AI detection or manually labels objects.
- **When labels are submitted:** The backend saves labels in YOLO format and updates user score.
- **When training is needed:** `backend/train.py` can be run to train a YOLO model from collected labels.

## 6. Where Everything Is Located

Main project folders:

```text
vibestory/
├── backend/
│   ├── app.py
│   ├── train.py
│   ├── requirements.txt
│   ├── .env
│   ├── kokoro-v1.0.onnx
│   ├── voices.bin
│   ├── hf_cache/
│   ├── static/
│   └── yolo_dataset/
├── frontend/
│   └── vibestory/
│       ├── lib/main.dart
│       ├── pubspec.yaml
│       ├── assets/icon.png
│       ├── android/
│       ├── ios/
│       ├── macos/
│       ├── linux/
│       ├── windows/
│       └── web/
├── README.md
├── STORY.txt
└── PROJECT_REPORT.md
```

Important files:

- `backend/app.py`: Main FastAPI backend.
- `backend/train.py`: YOLO training script.
- `backend/requirements.txt`: Python dependencies.
- `frontend/vibestory/lib/main.dart`: Main Flutter app code.
- `frontend/vibestory/pubspec.yaml`: Flutter dependencies and assets.
- `backend/static/`: Generated story images and audio.
- `backend/yolo_dataset/`: User-labeled YOLO training dataset.
- `backend/hf_cache/`: Hugging Face model cache.
- `backend/.env`: Local backend configuration.

## 7. Technologies Used

### Frontend

- **Flutter:** Cross-platform mobile app framework.
- **Dart:** Programming language used by Flutter.
- **Material UI:** Used for app screens, navigation, buttons, cards, dialogs, and icons.
- **Google Fonts:** Used for typography.
- **Shared Preferences:** Used to store login token and username locally.
- **Record Package:** Used to record microphone audio.
- **Audioplayers:** Used to play generated narration audio.
- **File Picker:** Used to upload an existing audio file.
- **Permission Handler:** Used to request microphone permission.
- **Path Provider:** Used to access temporary file locations.
- **HTTP Package:** Used to communicate with the FastAPI backend.

### Backend

- **Python:** Backend programming language.
- **FastAPI:** API framework.
- **Uvicorn:** ASGI server used to run FastAPI.
- **MongoDB:** Database for users and stories.
- **Motor:** Async MongoDB driver.
- **Pydantic:** Request validation models.
- **Passlib and bcrypt:** Password hashing and verification.
- **JWT / PyJWT:** Token-based authentication.
- **Python-dotenv:** Loads `.env` configuration.
- **StaticFiles:** Serves generated images and audio files.

### AI / Machine Learning

- **OpenAI Whisper:** Converts speech/audio to text and translates non-English speech into English.
- **Diffusers:** Loads and runs Stable Diffusion.
- **Ghibli-Diffusion model:** Generates story illustrations.
- **Torch / TorchVision:** Deep learning runtime.
- **Kokoro ONNX:** Text-to-speech narration.
- **SoundFile:** Saves generated audio.
- **Ultralytics YOLO:** Object detection and YOLO model training.
- **OpenCV:** Image processing for dataset augmentation.
- **Albumentations:** Image augmentation for YOLO training.
- **Pillow:** Image creation/conversion.
- **YAML / PyYAML:** Writes YOLO dataset configuration files.

## 8. Backend Architecture

The backend is built in `backend/app.py`.

It uses FastAPI to expose REST API routes. It connects to MongoDB using Motor and stores user and story data in two main collections:

- `users`
- `stories`

The backend also creates local folders for generated files:

- `static/stories/`: Generated story images.
- `static/audio/`: Generated narration audio.
- `yolo_dataset/images/train/`: Training images for YOLO.
- `yolo_dataset/images/val/`: Validation images for YOLO.
- `yolo_dataset/labels/train/`: YOLO label files for training images.
- `yolo_dataset/labels/val/`: YOLO label files for validation images.

The backend uses lazy loading for AI models. This means models are not loaded immediately when the server starts. Instead, they load only when they are first needed. This saves startup time and memory.

Lazy-loaded models:

- Whisper model
- Stable Diffusion pipeline
- YOLO model
- Kokoro TTS model

## 9. Backend Configuration

The backend reads configuration from `.env`.

Important environment variables:

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

Purpose of these values:

- `MONGO_URL`: MongoDB connection string.
- `DB_NAME`: Database name.
- `JWT_SECRET`: Secret key used to sign login tokens.
- `WHISPER_MODEL`: Whisper model size.
- `YOLO_MODEL`: YOLO weights file.
- `IMAGE_STEPS`: Number of Stable Diffusion inference steps.
- `IMAGE_CFG`: Guidance scale for image generation.
- `IMAGE_W` and `IMAGE_H`: Generated image dimensions.
- `KOKORO_VOICE`: Voice used for narration.
- `DEFAULT_NUM_IMGS`: Default number of story images.
- `DATASET_DIR`: Folder where YOLO dataset is saved.

## 10. Frontend Architecture

The frontend is built in `frontend/vibestory/lib/main.dart`.

It is a Flutter app with a dark theme and three main tabs:

- **Home**
- **Learn**
- **Profile**

Main frontend screens:

- `AuthScreen`: Login and signup.
- `MainNav`: Bottom navigation.
- `HomeScreen`: Text input, audio recording, audio upload, story generation.
- `StoryGeneratingScreen`: Shows generation progress and polls backend.
- `StoryPlayScreen`: Displays story images and plays narration audio.
- `LearnFromStoryScreen`: Allows learning from a selected generated story.
- `LearnScreen`: Lists previous stories for object exploration.
- `LearnImageScreen`: AI detection, manual bounding boxes, and label submission.
- `ProfileScreen`: Shows user score, object count, story count, and previous stories.
- `SettingsScreen`: Sign out.

## 11. Frontend Design

The app uses a dark visual theme with:

- Black/dark background.
- Violet primary accent.
- Teal secondary accent.
- Green success color.
- Red error color.
- Card-based content sections.
- Bottom navigation.
- Rounded buttons and dialogs.
- Image previews.
- Progress indicators.

The UI is designed to feel like a story creation and learning app rather than a plain form-based tool.

## 12. Authentication Flow

The authentication system works as follows:

1. User signs up with name, email, and password.
2. Backend checks if email already exists.
3. Password is hashed using bcrypt.
4. User record is saved in MongoDB.
5. Backend creates a JWT token.
6. Flutter saves the token using Shared Preferences.
7. Future requests include the token in the `Authorization` header.
8. Backend validates the token before allowing protected routes.

Login works similarly:

1. User enters email and password.
2. Backend finds the user in MongoDB.
3. Password is verified against the stored hash.
4. Backend returns a JWT token.
5. Flutter stores the token and opens the main app.

## 13. Story Generation Flow

The story generation process works step by step:

1. User enters text or records/uploads audio.
2. If audio is used, Flutter sends the audio file to `/api/input/transcribe`.
3. Backend uses Whisper to transcribe the audio.
4. If the detected language is not English, Whisper translates it to English.
5. Flutter places the transcribed English text into the story input field.
6. User chooses number of images.
7. Flutter sends story text and image count to `/api/story/generate`.
8. Backend creates a story document in MongoDB with status `queued`.
9. Backend starts a background generation task.
10. The story is split into chunks.
11. Each chunk is converted into an image prompt.
12. Stable Diffusion generates one image per chunk.
13. Image files are saved into `static/stories/<story_id>/`.
14. Kokoro TTS generates narration audio.
15. Audio is saved into `static/audio/<story_id>.wav`.
16. MongoDB story status changes to `done`.
17. Flutter polls `/api/story/{story_id}/status` every 2 seconds.
18. When status becomes `done`, the user can play the story.

## 14. Image Generation

The backend uses the Diffusers library with the model:

```text
nitrosocke/Ghibli-Diffusion
```

The image prompt is created from each story chunk. The prompt includes:

- The actual story sentence.
- Important non-stopwords from the sentence.
- Ghibli style.
- Hand-drawn anime illustration.
- Soft colors.
- Children's book art.
- Detailed background.
- Whimsical atmosphere.

The backend also uses a negative prompt to reduce unwanted outputs:

```text
ugly, blurry, bad anatomy, watermark, text, nsfw, scary, violent
```

If image generation fails, the backend creates a placeholder image so that the story pipeline can still continue.

## 15. Audio Generation

The backend uses Kokoro ONNX for text-to-speech.

Required files:

- `kokoro-v1.0.onnx`
- `voices.bin`

The generated narration is saved as a `.wav` file inside:

```text
backend/static/audio/
```

If Kokoro is not available, the backend attempts to fall back to `pyttsx3`.

## 16. Story Playback

The Flutter app uses `audioplayers` to play narration audio.

The `StoryPlayScreen`:

- Loads generated story images.
- Loads story text chunks.
- Plays generated narration.
- Changes displayed image based on audio playback progress.
- Shows dot indicators for current image.
- Allows the user to open the Learn screen from the story.

The image index is calculated using audio progress:

```text
current_image = playback_fraction * number_of_images
```

This creates a simple synchronization between narration and visuals.

## 17. Learning Module

The Learn feature has two modes:

1. **AI Detect**
2. **Manual Labeling**

### AI Detect

When the user taps AI Detect:

1. Flutter downloads the selected image.
2. Flutter uploads the image bytes to `/api/learn/detect`.
3. Backend runs YOLO object detection.
4. Backend returns detected labels, confidence scores, and bounding boxes.
5. Flutter draws the detection boxes over the image.

### Manual Labeling

When the user taps Draw Boxes:

1. User draws a rectangle over an object.
2. App opens a dialog asking what the object is.
3. User enters a label.
4. The box and label are displayed on the image.
5. User can submit all labels.
6. Flutter sends labels to `/api/learn/submit-labels`.
7. Backend saves the image and label file in YOLO format.
8. User receives points.

## 18. YOLO Dataset Creation

When labels are submitted, the backend writes the data into a YOLO-compatible dataset.

Dataset structure:

```text
yolo_dataset/
├── images/
│   ├── train/
│   └── val/
├── labels/
│   ├── train/
│   └── val/
├── classes.txt
└── dataset.yaml
```

The backend:

- Copies the story image into the dataset folder.
- Converts image to JPEG if needed.
- Creates a `.txt` label file.
- Stores bounding boxes in YOLO format.
- Updates `classes.txt`.
- Regenerates `dataset.yaml`.
- Uses a deterministic 90 percent train / 10 percent validation split.

YOLO label format:

```text
class_id center_x center_y width height
```

All coordinates are normalized between 0 and 1.

## 19. Scoring System

The scoring system rewards users for labeling objects.

Current rule:

```text
1 object label = 10 points
```

When the user submits labels:

- Backend counts labels.
- Points are calculated.
- User score is increased in MongoDB.
- Total object count is increased.
- Updated score is returned to Flutter.

The Profile screen displays:

- User name.
- Badge title.
- Points.
- Total labeled objects.
- Total generated stories.
- Previous stories.

Badge levels:

- `Story Seedling`
- `Curious Learner`
- `Object Hunter`
- `Super Finder`
- `Legend Explorer`

## 20. YOLO Training

The project includes `backend/train.py` for training a YOLO model using the collected dataset.

The training script:

1. Reads images and labels from `yolo_dataset/`.
2. Reads class names from `classes.txt`.
3. Validates dataset structure.
4. Applies image augmentation using Albumentations.
5. Creates an augmented dataset in `dataset_aug/`.
6. Writes `vibestory_train.yaml`.
7. Starts YOLO training using Ultralytics.
8. Copies the final trained weights to `best.pt`.

Useful commands:

```bash
python train.py --check
python train.py
EPOCHS=50 BATCH=4 python train.py
BASE_MODEL=yolov8n.pt python train.py
```

Default training configuration:

- Base model: `yolo11l.pt`
- Output model: `best.pt`
- Epochs: `100`
- Batch size: `8`
- Image size: `640`
- Augmentations per image: `5`

## 21. API Endpoints

### Authentication

| Method | Endpoint | Purpose |
|---|---|---|
| POST | `/api/auth/signup` | Create new user |
| POST | `/api/auth/login` | Login existing user |
| GET | `/api/auth/me` | Get current user |

### Input

| Method | Endpoint | Purpose |
|---|---|---|
| POST | `/api/input/transcribe` | Upload audio and convert it to text |

### Story

| Method | Endpoint | Purpose |
|---|---|---|
| POST | `/api/story/generate` | Start story generation |
| GET | `/api/story/{story_id}/status` | Check generation status |
| GET | `/api/story/{story_id}` | Get story details |

### Profile

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/api/profile` | Get user profile, score, objects, and stories |

### Learning

| Method | Endpoint | Purpose |
|---|---|---|
| POST | `/api/learn/detect` | Run YOLO detection on an image |
| POST | `/api/learn/submit-labels` | Save user labels and award points |
| POST | `/api/learn/rename-label` | Rewrite labels after correction |
| GET | `/api/learn/dataset-stats` | Get dataset statistics |
| GET | `/api/learn/export-dataset` | Download YOLO dataset as ZIP |

### Health

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/api/health` | Check backend, device, YOLO, and dataset status |

## 22. Database Design

The project uses MongoDB.

### Users Collection

Stores:

- User ID
- Name
- Email
- Hashed password
- Score
- Total labeled objects
- Created date

Example fields:

```json
{
  "name": "User Name",
  "email": "user@example.com",
  "password": "hashed_password",
  "score": 0,
  "total_objects": 0,
  "created_at": "datetime"
}
```

### Stories Collection

Stores:

- Story ID
- User ID
- Original text
- Number of images
- Status
- Current generation step
- Refined story
- Story parts
- Image URLs
- Audio URL
- Created date

Example fields:

```json
{
  "user_id": "user_id",
  "original_text": "story idea",
  "num_images": 5,
  "status": "done",
  "step": "Ready",
  "refined_story": "story text",
  "parts": [],
  "images": [],
  "audio_url": "",
  "created_at": "datetime"
}
```

## 23. Security

Security features used:

- Passwords are hashed using bcrypt.
- JWT tokens are used for login sessions.
- Protected API routes require `Authorization: Bearer <token>`.
- User stories are associated with user IDs.
- `.env` is used for local secrets and configuration.

Important note:

- The current CORS configuration allows all origins using `allow_origins=["*"]`. This is fine for development, but production should restrict allowed origins.
- `JWT_SECRET` should be strong and private in production.

## 24. Static Files

Generated files are served through FastAPI static routes.

Static mount:

```text
/static
```

Examples:

```text
/static/stories/<story_id>/part_1.png
/static/audio/<story_id>.wav
```

Flutter loads these files using:

```text
BASE_URL + static_file_path
```

## 25. How The Project Was Built Step By Step

### Step 1: Project Structure

The project was divided into backend and frontend folders:

- `backend/` for FastAPI, AI models, MongoDB, and dataset handling.
- `frontend/vibestory/` for the Flutter mobile app.

### Step 2: Backend Setup

FastAPI was added to create REST API routes. Uvicorn was used as the local development server.

MongoDB was added to store users and generated stories.

### Step 3: Authentication

Signup and login APIs were created. Passwords were hashed using bcrypt, and JWT tokens were returned after successful authentication.

### Step 4: Flutter App Setup

A Flutter project was created. Dependencies were added for HTTP requests, local storage, audio recording, file upload, audio playback, permissions, and UI styling.

### Step 5: Auth UI

Login and signup screens were created. The app stores the token locally so users remain logged in.

### Step 6: Story Input UI

The Home screen was created with:

- Text input
- Microphone recording
- Audio upload
- Number of images selection
- Generate button

### Step 7: Speech-To-Text

The backend added Whisper support. Uploaded audio is transcribed and translated if needed.

### Step 8: Story Pipeline

The backend story generation route was created. It stores a story record and starts a background task.

### Step 9: Image Generation

Stable Diffusion through Diffusers was added. Each story chunk is converted into an image prompt and saved as a PNG file.

### Step 10: Audio Narration

Kokoro ONNX was added to generate narration audio from the story text.

### Step 11: Story Status Polling

The Flutter app polls the backend every 2 seconds to show generation progress.

### Step 12: Story Playback

The Story Play screen was created to show generated images and play narration audio.

### Step 13: Learning Module

The Learn screen was added so users can inspect story images, run AI detection, and manually label objects.

### Step 14: YOLO Detection

The backend added YOLO object detection using Ultralytics.

### Step 15: Dataset Saving

Submitted user labels are saved in YOLO format inside `yolo_dataset/`.

### Step 16: Profile and Scoring

The backend updates user score and object count. The Profile screen displays progress and previous stories.

### Step 17: Training Script

`train.py` was created to train YOLO on the collected dataset with augmentation.

### Step 18: Run Instructions

The project can be run using two main commands after MongoDB is active:

Backend:

```bash
cd "/Users/vishalsingh/Desktop/Vibe Story (Final)/vibestory/backend" && source .venv/bin/activate && uvicorn app:app --host 0.0.0.0 --port 8000
```

Frontend:

```bash
cd "/Users/vishalsingh/Desktop/Vibe Story (Final)/vibestory/frontend/vibestory" && flutter run --dart-define=BASE_URL=http://localhost:8000
```

For a physical phone, replace `localhost` with the Mac's Wi-Fi IP address.

## 26. Included Files And Assets

Included in the project:

- Backend source code.
- Flutter source code.
- Flutter platform folders for Android, iOS, macOS, Linux, Windows, and Web.
- App icon asset.
- Python requirements.
- README instructions.
- Story sample file.
- YOLO training script.

Local runtime files found in the backend:

- `.env`
- `.venv/`
- `hf_cache/`
- `static/`
- `yolo_dataset/`
- `kokoro-v1.0.onnx`
- `voices.bin`
- `yolov8n.pt`

These local runtime files are useful for running the project but should usually not be committed to GitHub because they are large, generated, or machine-specific.

## 27. Not Included / Should Not Be Committed

The following should generally not be committed:

- Virtual environment: `backend/.venv/`
- Secrets: `backend/.env`
- Model cache: `backend/hf_cache/`
- Generated files: `backend/static/`
- Training data: `backend/yolo_dataset/`
- Large model weights: `*.pt`
- ONNX models: `*.onnx`
- Voice data: `voices.bin`

Reason:

- They are large.
- They are machine-specific.
- Some contain private configuration.
- Generated files can be recreated.

## 28. How To Run The Project

First make sure MongoDB is running.

Then run backend:

```bash
cd "/Users/vishalsingh/Desktop/Vibe Story (Final)/vibestory/backend" && source .venv/bin/activate && uvicorn app:app --host 0.0.0.0 --port 8000
```

Then run frontend in a second terminal:

```bash
cd "/Users/vishalsingh/Desktop/Vibe Story (Final)/vibestory/frontend/vibestory" && flutter run --dart-define=BASE_URL=http://localhost:8000
```

Backend health check:

```text
http://localhost:8000/api/health
```

## 29. Testing And Validation

Validation done:

- Flutter analyzer was run successfully.
- Result: no Flutter issues found.
- Backend server starts successfully using Uvicorn.
- Health route is available at `/api/health`.

Useful checks:

```bash
flutter analyze
python train.py --check
```

Manual test flow:

1. Start MongoDB.
2. Start backend.
3. Start Flutter app.
4. Sign up.
5. Enter story text.
6. Generate story.
7. Wait until story status becomes ready.
8. Play story.
9. Open Learn screen.
10. Draw boxes and submit labels.
11. Check Profile score.
12. Check `yolo_dataset/` for saved files.

## 30. Challenges Faced

Possible challenges in this project:

- Managing large AI model files.
- Running image generation on CPU can be slow.
- Flutter cannot use `localhost` for physical phone testing; the Mac IP is needed.
- AI model downloads can take time on first run.
- Audio recording requires microphone permission.
- YOLO labels need correct coordinate conversion.
- Training requires enough labeled data.
- MongoDB must be running before backend APIs can work correctly.

## 31. Limitations

Current limitations:

- Image generation can be slow on machines without GPU.
- The generated story is currently based mainly on the user's provided text and simple chunking.
- The app depends on local backend availability.
- The YOLO dataset needs enough manually labeled images before training becomes useful.
- CORS is open for development.
- Large models are not suitable for direct GitHub storage.
- The app does not currently include cloud deployment configuration.

## 32. Future Improvements

Possible future improvements:

- Add cloud deployment for backend.
- Add better prompt engineering or LLM-based story refinement.
- Add progress percentages for each AI pipeline stage.
- Add user ability to delete stories.
- Add dataset export button directly inside Flutter UI.
- Add admin dashboard for dataset statistics.
- Add better audio-image synchronization based on story chunks.
- Add image regeneration option.
- Add support for more voices.
- Add multilingual story display.
- Add production-safe CORS settings.
- Add role-based access for admin/trainer users.
- Add automated tests for backend APIs.
- Add model selection settings.

## 33. Final Summary

VibeStory is a complete AI storytelling and learning application. It combines a Flutter mobile frontend with a FastAPI backend and multiple AI technologies. The user can create stories from text or voice, generate illustrated scenes, listen to narration, label objects in images, earn points, and build a YOLO-compatible dataset for future training.

The project demonstrates practical use of:

- Mobile app development
- REST API development
- Authentication
- MongoDB database design
- Speech-to-text
- Image generation
- Text-to-speech
- Object detection
- Dataset creation
- Machine learning training workflow
- User progress tracking

This makes the project both creative and technically strong, because it is not only an AI content generator but also a system for collecting training data and improving machine learning models over time.
