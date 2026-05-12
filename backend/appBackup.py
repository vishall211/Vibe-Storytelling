"""
VibeStory Backend — app.py
=================================
"""

import os, io, json, asyncio, tempfile, logging, threading, random, shutil, zipfile
from pathlib import Path
from typing import List, Dict, Optional
from datetime import datetime, timedelta
from concurrent.futures import ThreadPoolExecutor

import yaml
import jwt
from passlib.context import CryptContext
from bson import ObjectId
import motor.motor_asyncio
from fastapi import FastAPI, HTTPException, Depends, UploadFile, File, BackgroundTasks, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel

from dotenv import load_dotenv
load_dotenv() 

logging.basicConfig(level=logging.INFO, format="%(asctime)s  %(levelname)-8s  %(message)s")
log = logging.getLogger("vibestory")

# ─── Config ───────────────────────────────────────────────────────────────────
MONGO_URL       = os.getenv("MONGO_URL",     "mongodb://localhost:27017")
DB_NAME         = os.getenv("DB_NAME",       "vibestory")
JWT_SECRET      = os.getenv("JWT_SECRET",    "vibestory_secret_42")
JWT_ALGO        = "HS256"
JWT_EXPIRE_DAYS = 30
WHISPER_MODEL   = os.getenv("WHISPER_MODEL", "small")
GHIBLI_MODEL_ID = "nitrosocke/Ghibli-Diffusion"
IMAGE_STEPS     = int(os.getenv("IMAGE_STEPS",   "30"))
IMAGE_CFG       = float(os.getenv("IMAGE_CFG",   "5.0"))
IMAGE_W         = int(os.getenv("IMAGE_W",       "800"))
IMAGE_H         = int(os.getenv("IMAGE_H",       "400"))
KOKORO_VOICE    = os.getenv("KOKORO_VOICE",  "af_heart")
DEFAULT_NUM_IMG = int(os.getenv("DEFAULT_NUM_IMGS", "5"))

# ── YOLO: points to best.pt by default ───────────────────────────────────────
YOLO_MODEL_PATH = os.getenv("YOLO_MODEL", "best.pt")

# ── Industry-standard YOLO dataset folder ────────────────────────────────────
# This is what gets written every time a user submits labels.
# Point train.py at this folder:  python train.py --mode dataset --data ./yolo_dataset
DATASET_DIR = Path(os.getenv("DATASET_DIR", "yolo_dataset"))

_HF_CACHE = str(Path(__file__).parent / "hf_cache")
os.environ.setdefault("HF_HOME",               _HF_CACHE)
os.environ.setdefault("TRANSFORMERS_CACHE",    _HF_CACHE)
os.environ.setdefault("HUGGINGFACE_HUB_CACHE", _HF_CACHE)
Path(_HF_CACHE).mkdir(parents=True, exist_ok=True)

STATIC_DIR  = Path("static")
STORIES_DIR = STATIC_DIR / "stories"
AUDIO_DIR   = STATIC_DIR / "audio"
for _d in [STATIC_DIR, STORIES_DIR, AUDIO_DIR]:
    _d.mkdir(parents=True, exist_ok=True)

# Create YOLO dataset folder structure up-front so it's always ready
for _split in ["train", "val"]:
    (DATASET_DIR / "images" / _split).mkdir(parents=True, exist_ok=True)
    (DATASET_DIR / "labels" / _split).mkdir(parents=True, exist_ok=True)

executor = ThreadPoolExecutor(max_workers=2)

# ─── Lazy model holders ───────────────────────────────────────────────────────
_whisper_model  = None
_diffusion_pipe = None
_yolo_model     = None
_kokoro         = None

# ═════════════════════════════════════════════════════════════════════════════
#  MODEL LOADERS  (unchanged from v6)
# ═════════════════════════════════════════════════════════════════════════════

def _load_whisper():
    global _whisper_model
    if _whisper_model is None:
        import whisper
        log.info("Loading Whisper '%s'…", WHISPER_MODEL)
        _whisper_model = whisper.load_model(WHISPER_MODEL)
        log.info("Whisper loaded")
    return _whisper_model

def _load_diffusion():
    global _diffusion_pipe
    if _diffusion_pipe is None:
        import torch
        from diffusers import StableDiffusionPipeline
        dtype = torch.float16 if torch.cuda.is_available() else torch.float32
        log.info("Loading Ghibli-Diffusion…")
        pipe = StableDiffusionPipeline.from_pretrained(
            GHIBLI_MODEL_ID, torch_dtype=dtype,
            safety_checker=None, requires_safety_checker=False)
        if torch.cuda.is_available():
            pipe = pipe.to("cuda")
            pipe.enable_attention_slicing()
        _diffusion_pipe = pipe
        log.info("Ghibli-Diffusion loaded")
    return _diffusion_pipe

def _load_yolo():
    global _yolo_model
    if _yolo_model is None:
        from ultralytics import YOLO
        model_path = YOLO_MODEL_PATH
        if not Path(model_path).exists():
            log.warning(
                "⚠️  '%s' not found — falling back to yolov8n.pt.",
                model_path,
            )
            model_path = "yolov8n.pt"
        log.info("Loading YOLO from '%s'…", model_path)
        _yolo_model = YOLO(model_path)
        log.info(
            "YOLO loaded — %d classes: %s",
            len(_yolo_model.names),
            list(_yolo_model.names.values()),
        )
    return _yolo_model

def _load_kokoro():
    global _kokoro
    if _kokoro is None:
        try:
            from kokoro_onnx import Kokoro
            log.info("Loading Kokoro TTS…")
            _kokoro = Kokoro("kokoro-v1.0.onnx", "voices.bin")
            log.info("Kokoro TTS loaded")
        except Exception as e:
            log.warning("Kokoro unavailable (%s) — pyttsx3 fallback", e)
    return _kokoro

# ═════════════════════════════════════════════════════════════════════════════
#  SYNC INFERENCE  (unchanged)
# ═════════════════════════════════════════════════════════════════════════════

def _sync_transcribe(audio_path: str) -> Dict:
    model    = _load_whisper()
    orig_res = model.transcribe(audio_path, task="transcribe")
    lang     = orig_res.get("language", "en")
    original = orig_res["text"].strip()
    english  = original
    if lang != "en":
        en_res  = model.transcribe(audio_path, task="translate")
        english = en_res["text"].strip()
    return {"original": original, "english": english, "language": lang}

def _sync_gen_image(prompt: str, save_path: Path) -> int:
    pipe  = _load_diffusion()
    neg   = "ugly, blurry, bad anatomy, watermark, text, nsfw, scary, violent"
    seed  = random.randint(0, 999999)
    import torch
    gen   = torch.manual_seed(seed)
    img   = pipe(
        prompt, negative_prompt=neg,
        num_inference_steps=IMAGE_STEPS, guidance_scale=IMAGE_CFG,
        width=IMAGE_W, height=IMAGE_H, generator=gen,
    ).images[0]
    img.save(save_path)
    return seed

def _sync_tts(text: str, save_path: Path):
    kok = _load_kokoro()
    if kok:
        import soundfile as sf
        samples, sr = kok.create(text, voice=KOKORO_VOICE, speed=0.85, lang="en-us")
        sf.write(str(save_path), samples, sr)
    else:
        import pyttsx3
        engine = pyttsx3.init()
        engine.setProperty("rate", 140)
        engine.save_to_file(text, str(save_path))
        engine.runAndWait()

def _sync_yolo(img_path: str) -> List[Dict]:
    yolo    = _load_yolo()
    results = yolo(img_path)
    out     = []
    for r in results:
        for box in r.boxes:
            x1, y1, x2, y2 = [int(v) for v in box.xyxy[0].tolist()]
            out.append({
                "label":      yolo.names[int(box.cls[0])],
                "confidence": round(float(box.conf[0]), 3),
                "box": {"x": x1, "y": y1, "width": x2 - x1, "height": y2 - y1},
            })
    return out

# ═════════════════════════════════════════════════════════════════════════════
#  ASYNC WRAPPERS  (unchanged)
# ═════════════════════════════════════════════════════════════════════════════

async def do_transcribe(audio_bytes: bytes, suffix: str = ".webm") -> Dict:
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(audio_bytes)
        tmp_path = tmp.name
    try:
        return await asyncio.get_event_loop().run_in_executor(
            executor, _sync_transcribe, tmp_path)
    finally:
        os.unlink(tmp_path)

async def do_gen_image(prompt: str, save_path: Path) -> int:
    return await asyncio.get_event_loop().run_in_executor(
        executor, lambda: _sync_gen_image(prompt, save_path))

async def do_tts(text: str, save_path: Path):
    await asyncio.get_event_loop().run_in_executor(
        executor, lambda: _sync_tts(text, save_path))

async def do_yolo(img_bytes: bytes) -> List[Dict]:
    with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
        tmp.write(img_bytes)
        tmp_path = tmp.name
    try:
        return await asyncio.get_event_loop().run_in_executor(
            executor, _sync_yolo, tmp_path)
    finally:
        os.unlink(tmp_path)

# ─── Story helpers (unchanged) ────────────────────────────────────────────────

def chunk_story(text: str, num_chunks: int) -> List[str]:
    sentences = [s.strip() for s in text.split(".") if s.strip()]
    if not sentences:
        sentences = [text.strip()]
    if len(sentences) >= num_chunks:
        size  = len(sentences) // num_chunks
        extra = len(sentences) % num_chunks
        chunks, start = [], 0
        for i in range(num_chunks):
            end = start + size + (1 if i < extra else 0)
            chunks.append(". ".join(sentences[start:end]) + ".")
            start = end
    else:
        words = text.split()
        size  = max(1, len(words) // num_chunks)
        extra = len(words) % num_chunks
        chunks, start = [], 0
        for i in range(num_chunks):
            end = start + size + (1 if i < extra else 0)
            chunks.append(" ".join(words[start:end]))
            start = end
        while len(chunks) < num_chunks:
            chunks.append(chunks[-1] if chunks else text)
    return chunks[:num_chunks]

def build_prompt(sentence: str) -> str:
    stop = {"the","a","an","and","or","but","in","on","at","to","for","of",
            "with","he","she","it","they","was","were","had","have","has",
            "his","her","their"}
    words = [w.strip(".,!?;:'\"") for w in sentence.split()
             if w.lower().strip(".,!?;:'\"") not in stop]
    return (
        f"Ghibli style, {sentence.strip()}, {' '.join(words[:10])}, "
        "hand-drawn anime illustration, soft colors, beautiful detailed background, "
        "whimsical atmosphere, children's book art, highly detailed, masterpiece"
    )

def make_placeholder(path: Path, index: int):
    try:
        from PIL import Image, ImageDraw
        colors = ["#1a1a2e","#16213e","#0f3460","#533483","#2b2d42"]
        img = Image.new("RGB", (IMAGE_W, IMAGE_H), colors[(index - 1) % 5])
        ImageDraw.Draw(img).text((IMAGE_W // 2 - 30, IMAGE_H // 2 - 10),
                                  f"Part {index}", fill="#888888")
        img.save(path)
    except Exception:
        pass

# ═════════════════════════════════════════════════════════════════════════════
#  DATASET HELPERS  ← NEW in v7
# ═════════════════════════════════════════════════════════════════════════════

def _classes_path() -> Path:
    return DATASET_DIR / "classes.txt"

def _load_classes() -> List[str]:
    """Read existing class list from classes.txt (one name per line)."""
    p = _classes_path()
    if not p.exists():
        return []
    return [l.strip() for l in p.read_text().splitlines() if l.strip()]

def _save_classes(names: List[str]):
    """Write updated class list and regenerate dataset.yaml."""
    _classes_path().write_text("\n".join(names) + "\n")
    _write_dataset_yaml(names)
    log.info("classes.txt updated — %d classes", len(names))

def _write_dataset_yaml(names: List[str]):
    """Write the YOLO-compatible dataset.yaml that train.py and ultralytics expect."""
    content = {
        "path":  str(DATASET_DIR.absolute()),
        "train": "images/train",
        "val":   "images/val",
        "nc":    len(names),
        "names": {i: n for i, n in enumerate(names)},
    }
    yaml_path = DATASET_DIR / "dataset.yaml"
    with open(yaml_path, "w") as f:
        yaml.dump(content, f, default_flow_style=False, allow_unicode=True)

def _write_label_file(label_path: Path, labels: List[Dict], name_to_id: Dict[str, int]):
    """
    Write a YOLO .txt label file.

    Each label dict looks like:
        {"label": "tree", "box": {"x": 10, "y": 20, "width": 100, "height": 80}}
    Coordinates are absolute pixels in IMAGE_W × IMAGE_H space.
    We normalise to YOLO format: class_id  cx  cy  w  h  (all 0-1).
    """
    lines = []
    for lbl in labels:
        name = lbl.get("label", "").strip().lower()
        if not name or name not in name_to_id:
            continue
        b  = lbl["box"]
        cx = (b["x"] + b["width"]  / 2) / IMAGE_W
        cy = (b["y"] + b["height"] / 2) / IMAGE_H
        w  =  b["width"]  / IMAGE_W
        h  =  b["height"] / IMAGE_H
        # clamp to valid range
        cx, cy, w, h = (max(0.0, min(1.0, v)) for v in (cx, cy, w, h))
        lines.append(f"{name_to_id[name]} {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}")
    label_path.write_text("\n".join(lines) + "\n" if lines else "")

def _save_sample_to_dataset(
    story_id: str,
    image_index: int,
    image_url: str,          # e.g.  /static/stories/<sid>/part_1.png
    labels: List[Dict],
):
    """
    Copy the story image into the YOLO dataset folder and write its label file.

    • 90 % of samples go to train/, 10 % to val/  (decided by hash so it's
      deterministic — the same image always lands in the same split).
    • New class names are appended to classes.txt automatically.
    • dataset.yaml is regenerated every time so it stays in sync.
    """
    # ── 1. Resolve source image path ─────────────────────────────────────────
    if image_url.startswith("/"):
        src = Path("." + image_url)
    else:
        src = Path(image_url)

    if not src.exists():
        log.warning("Dataset write skipped — source image not found: %s", src)
        return

    # ── 2. Decide train / val split (hash-based, deterministic) ──────────────
    split = "val" if (hash(f"{story_id}_{image_index}") % 10 == 0) else "train"

    # ── 3. File names ─────────────────────────────────────────────────────────
    stem     = f"{story_id}_{image_index}"
    img_dst  = DATASET_DIR / "images" / split / f"{stem}.jpg"
    lbl_dst  = DATASET_DIR / "labels" / split / f"{stem}.txt"

    # ── 4. Copy image (convert to JPEG if needed via Pillow) ──────────────────
    try:
        from PIL import Image as PILImage
        with PILImage.open(src) as im:
            im.convert("RGB").save(img_dst, "JPEG", quality=95)
    except Exception:
        shutil.copy(src, img_dst)   # fallback: straight copy

    # ── 5. Update class list ──────────────────────────────────────────────────
    existing_classes = _load_classes()
    new_names = [
        lbl.get("label", "").strip().lower()
        for lbl in labels
        if lbl.get("label", "").strip()
    ]
    added = False
    for name in new_names:
        if name and name not in existing_classes:
            existing_classes.append(name)
            added = True
    if added:
        _save_classes(existing_classes)

    name_to_id = {n: i for i, n in enumerate(existing_classes)}

    # ── 6. Write label file ───────────────────────────────────────────────────
    _write_label_file(lbl_dst, labels, name_to_id)

    log.info(
        "Dataset ← %s split=%s  labels=%d  total_classes=%d",
        stem, split, len(labels), len(existing_classes),
    )


def _dataset_stats() -> Dict:
    """Return a quick summary of the current on-disk dataset."""
    stats = {"classes": _load_classes(), "splits": {}}
    for split in ("train", "val"):
        img_dir = DATASET_DIR / "images" / split
        lbl_dir = DATASET_DIR / "labels" / split
        n_imgs  = len(list(img_dir.glob("*.jpg"))) if img_dir.exists() else 0
        n_lbls  = len(list(lbl_dir.glob("*.txt"))) if lbl_dir.exists() else 0
        stats["splits"][split] = {"images": n_imgs, "labels": n_lbls}
    stats["total_images"] = sum(v["images"] for v in stats["splits"].values())
    return stats


# ═════════════════════════════════════════════════════════════════════════════
#  AUTH HELPERS  (unchanged)
# ═════════════════════════════════════════════════════════════════════════════
pwd_ctx   = CryptContext(schemes=["bcrypt"], deprecated="auto", bcrypt__rounds=12)
hash_pw   = lambda pw: pwd_ctx.hash(pw)
verify_pw = lambda pw, h: pwd_ctx.verify(pw, h)

def create_token(uid: str) -> str:
    exp = datetime.utcnow() + timedelta(days=JWT_EXPIRE_DAYS)
    return jwt.encode({"sub": uid, "exp": exp}, JWT_SECRET, algorithm=JWT_ALGO)

def decode_token(token: str) -> str:
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGO])["sub"]
    except Exception:
        raise HTTPException(401, "Invalid or expired token")

# ═════════════════════════════════════════════════════════════════════════════
#  FASTAPI APP + DB
# ═════════════════════════════════════════════════════════════════════════════
app = FastAPI(title="VibeStory API", version="8.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"],
                   allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.mount("/static", StaticFiles(directory="static"), name="static")

_mongo      = motor.motor_asyncio.AsyncIOMotorClient(MONGO_URL)
db          = _mongo[DB_NAME]
users_col   = db["users"]
stories_col = db["stories"]

# ─── Schemas ──────────────────────────────────────────────────────────────────
class SignupReq(BaseModel):
    name: str; email: str; password: str

class LoginReq(BaseModel):
    email: str; password: str

class StoryGenReq(BaseModel):
    text: str
    num_images: int = DEFAULT_NUM_IMG

class LabelSubmitReq(BaseModel):
    story_id: str
    image_index: int
    image_url: str = ""
    labels: List[Dict]

class RenameLabelReq(BaseModel):
    story_id: str
    image_index: int
    image_url: str = ""
    labels: List[Dict]   # full corrected label list for this image

# ─── Auth dependency ──────────────────────────────────────────────────────────
async def current_user(request: Request):
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        raise HTTPException(401, "Missing token")
    uid  = decode_token(auth[7:])
    user = await users_col.find_one({"_id": ObjectId(uid)})
    if not user:
        raise HTTPException(401, "User not found")
    return user

# ═════════════════════════════════════════════════════════════════════════════
#  AUTH ROUTES  (unchanged)
# ═════════════════════════════════════════════════════════════════════════════

@app.post("/api/auth/signup")
async def signup(req: SignupReq):
    if await users_col.find_one({"email": req.email.lower()}):
        raise HTTPException(400, "Email already registered")
    doc = {
        "name": req.name.strip(),
        "email": req.email.lower().strip(),
        "password": hash_pw(req.password),
        "score": 0,
        "total_objects": 0,
        "created_at": datetime.utcnow(),
    }
    res   = await users_col.insert_one(doc)
    token = create_token(str(res.inserted_id))
    return {"token": token, "name": req.name, "user_id": str(res.inserted_id)}

@app.post("/api/auth/login")
async def login(req: LoginReq):
    user = await users_col.find_one({"email": req.email.lower()})
    if not user or not verify_pw(req.password, user["password"]):
        raise HTTPException(401, "Wrong email or password")
    token = create_token(str(user["_id"]))
    return {"token": token, "name": user["name"], "user_id": str(user["_id"])}

@app.get("/api/auth/me")
async def me(user=Depends(current_user)):
    return {
        "user_id": str(user["_id"]),
        "name": user["name"],
        "email": user["email"],
        "score": user.get("score", 0),
        "total_objects": user.get("total_objects", 0),
    }

# ═════════════════════════════════════════════════════════════════════════════
#  INPUT
# ═════════════════════════════════════════════════════════════════════════════

@app.post("/api/input/transcribe")
async def route_transcribe(audio: UploadFile = File(...), user=Depends(current_user)):
    raw    = await audio.read()
    suffix = Path(audio.filename or "audio.webm").suffix or ".webm"
    return await do_transcribe(raw, suffix)

# ═════════════════════════════════════════════════════════════════════════════
#  STORY GENERATION  (unchanged)
# ═════════════════════════════════════════════════════════════════════════════

@app.post("/api/story/generate")
async def start_gen(req: StoryGenReq, bg: BackgroundTasks, user=Depends(current_user)):
    num  = max(1, min(20, req.num_images))
    sid  = str(ObjectId())
    sdir = STORIES_DIR / sid
    sdir.mkdir(parents=True)

    await stories_col.insert_one({
        "_id":           ObjectId(sid),
        "user_id":       str(user["_id"]),
        "original_text": req.text,
        "num_images":    num,
        "status":        "queued",
        "step":          "Starting…",
        "refined_story": "",
        "parts":         [],
        "images":        [],
        "audio_url":     "",
        "created_at":    datetime.utcnow(),
    })
    bg.add_task(_pipeline, sid, req.text, sdir, num)
    return {"story_id": sid}

async def _set(sid: str, **kw):
    await stories_col.update_one({"_id": ObjectId(sid)}, {"$set": kw})

async def _pipeline(sid: str, text: str, story_dir: Path, num_images: int):
    try:
        await _set(sid, status="running", step="Building story scenes…")

        chunks = chunk_story(text.strip(), num_images)
        parts  = [{"text": c, "prompt": build_prompt(c)} for c in chunks]
        await _set(sid, refined_story=text.strip(), parts=parts, step="Generating images…")

        image_urls = []
        for i, part in enumerate(parts):
            await _set(sid, step=f"Drawing image {i + 1} of {len(parts)}…")
            img_path = story_dir / f"part_{i + 1}.png"
            try:
                await do_gen_image(part["prompt"], img_path)
            except Exception as e:
                log.error("Image %d failed: %s", i + 1, e)
                make_placeholder(img_path, i + 1)
            url = f"/static/stories/{sid}/part_{i + 1}.png"
            image_urls.append(url)
            await _set(sid, images=image_urls)

        await _set(sid, step="Generating narration…")
        audio_url = ""
        try:
            audio_path = AUDIO_DIR / f"{sid}.wav"
            await do_tts(text.strip(), audio_path)
            audio_url = f"/static/audio/{sid}.wav"
        except Exception as e:
            log.error("TTS failed: %s", e)

        await _set(sid, status="done", step="Ready",
                   images=image_urls, audio_url=audio_url)

    except Exception as e:
        log.exception("Pipeline crashed for story %s", sid)
        await _set(sid, status="error", step=str(e))

@app.get("/api/story/{story_id}/status")
async def story_status(story_id: str, user=Depends(current_user)):
    doc = await stories_col.find_one({"_id": ObjectId(story_id)})
    if not doc:
        raise HTTPException(404, "Story not found")
    doc["_id"] = str(doc["_id"])
    doc.pop("user_id", None)
    return doc

@app.get("/api/story/{story_id}")
async def get_story(story_id: str, user=Depends(current_user)):
    doc = await stories_col.find_one({"_id": ObjectId(story_id)})
    if not doc:
        raise HTTPException(404, "Story not found")
    doc["_id"] = str(doc["_id"])
    return doc

# ═════════════════════════════════════════════════════════════════════════════
#  PROFILE  (unchanged)
# ═════════════════════════════════════════════════════════════════════════════

@app.get("/api/profile")
async def profile(user=Depends(current_user)):
    cursor = stories_col.find(
        {"user_id": str(user["_id"]), "status": "done"},
        {"_id": 1, "refined_story": 1, "images": 1, "parts": 1,
         "created_at": 1, "audio_url": 1},
    ).sort("created_at", -1)
    stories = []
    async for s in cursor:
        s["_id"] = str(s["_id"])
        stories.append(s)
    return {
        "name":          user["name"],
        "score":         user.get("score", 0),
        "total_objects": user.get("total_objects", 0),
        "stories":       stories,
    }

# ═════════════════════════════════════════════════════════════════════════════
#  LEARN — YOLO detection + user labels
# ═════════════════════════════════════════════════════════════════════════════

@app.post("/api/learn/detect")
async def learn_detect(image: UploadFile = File(...), user=Depends(current_user)):
    raw  = await image.read()
    dets = await do_yolo(raw)
    return {"detections": dets}

@app.post("/api/learn/submit-labels")
async def submit_labels(req: LabelSubmitReq, user=Depends(current_user)):
    """
    Accepts user-drawn bounding boxes, awards points, and writes the image +
    label file directly into the YOLO dataset folder on disk.

    To train afterwards, just run:
        python train.py
    To share / back up the dataset:
        GET /api/learn/export-dataset
    """
    if not req.labels:
        raise HTTPException(400, "No labels provided")

    n      = len(req.labels)
    points = n * 10

    # ── Write to YOLO dataset folder on disk ──────────────────────────────────
    try:
        _save_sample_to_dataset(
            story_id    = req.story_id,
            image_index = req.image_index,
            image_url   = req.image_url,
            labels      = req.labels,
        )
    except Exception as e:
        log.error("Dataset write failed: %s", e)

    # ── Update user score in MongoDB ──────────────────────────────────────────
    await users_col.update_one(
        {"_id": user["_id"]},
        {"$inc": {"score": points, "total_objects": n}},
    )
    updated = await users_col.find_one({"_id": user["_id"]})

    return {
        "points_awarded": points,
        "new_score":      updated.get("score", 0),
        "total_objects":  updated.get("total_objects", 0),
        "dataset_stats":  _dataset_stats(),
    }

@app.post("/api/learn/rename-label")
async def rename_label(req: RenameLabelReq, user=Depends(current_user)):
    """
    Renames a label that was already submitted and rewrites the label file on disk.
    The client must re-send the full labels list with the correction applied.
    """
    # Re-write the label file on disk with the corrected name
    try:
        _save_sample_to_dataset(
            story_id    = req.story_id,
            image_index = req.image_index,
            image_url   = req.image_url,
            labels      = req.labels,
        )
    except Exception as e:
        log.warning("Dataset re-write after rename failed: %s", e)
    return {"ok": True}


# ─── NEW: dataset info + download ─────────────────────────────────────────────

@app.get("/api/learn/dataset-stats")
async def dataset_stats(user=Depends(current_user)):
    """
    Returns a summary of how many labelled images are in the on-disk dataset.
    Useful to show progress in the app ("You've labelled 42 images!").
    """
    return _dataset_stats()

@app.get("/api/learn/export-dataset")
async def export_dataset(user=Depends(current_user)):
    """
    Zips the entire yolo_dataset/ folder and returns it as a download.

    Use this to:
      • Share the dataset with your team / seniors
      • Upload to Google Colab and run train.py
      • Back it up

    The ZIP contains:
        yolo_dataset/
            images/train/*.jpg
            images/val/*.jpg
            labels/train/*.txt
            labels/val/*.txt
            classes.txt
            dataset.yaml
    """
    stats = _dataset_stats()
    if stats["total_images"] == 0:
        raise HTTPException(404, "No labelled images in dataset yet. "
                                  "Label some images in the app first.")

    zip_path = Path(tempfile.mktemp(suffix=".zip"))
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for f in DATASET_DIR.rglob("*"):
            if f.is_file():
                zf.write(f, f.relative_to(DATASET_DIR.parent))

    return FileResponse(
        path        = str(zip_path),
        filename    = "yolo_dataset.zip",
        media_type  = "application/zip",
        background  = BackgroundTasks(),   # temp file cleaned up after send
    )

# ═════════════════════════════════════════════════════════════════════════════
#  HEALTH
# ═════════════════════════════════════════════════════════════════════════════

@app.get("/api/health")
async def health():
    import torch
    yolo_exists = Path(YOLO_MODEL_PATH).exists()
    return {
        "status":     "ok",
        "cuda":       torch.cuda.is_available(),
        "device":     (torch.cuda.get_device_name(0)
                       if torch.cuda.is_available() else "CPU"),
        "yolo_model": YOLO_MODEL_PATH,
        "yolo_ready": yolo_exists,
        "dataset":    _dataset_stats(),
        "version":    "8.0.0",
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=False)