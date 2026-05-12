"""
train.py — VibeStory YOLO Fine-tuner
=====================================
Trains on the dataset folder that app.py builds automatically whenever
a user submits labels in the app.

USAGE:
  python train.py

  # Override hyper-params via env vars:
  EPOCHS=50 BATCH=4 python train.py

  # Use a different dataset folder:
  DATASET_DIR=./my_data python train.py

  # Health-check your labels before training:
  python train.py --check

REQUIREMENTS:
  pip install ultralytics albumentations opencv-python pyyaml

Works identically on your local machine and Google Colab.
"""

import os
import sys
import cv2
import glob
import shutil
import argparse
import logging
import yaml
from pathlib import Path
from collections import Counter

import numpy as np
import albumentations as A

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
)
log = logging.getLogger("vibestory-train")

# ─── CONFIG — change these to match your setup ────────────────────────────────

# The base YOLO model to start fine-tuning from.
# Your seniors used "yolo11l.pt". You can also use "yolov8n.pt" (faster/smaller).
BASE_MODEL = os.getenv("BASE_MODEL", "yolo11l.pt")

# Where the finished best.pt will be copied when training is done.
OUTPUT_WEIGHTS = os.getenv("OUTPUT_WEIGHTS", "best.pt")

# The dataset folder that app.py writes to automatically.
DATASET_DIR = os.getenv("DATASET_DIR", "yolo_dataset")

# Training hyper-parameters (same as your seniors used)
EPOCHS     = int(os.getenv("EPOCHS",    "100"))
BATCH_SIZE = int(os.getenv("BATCH",     "8"))
IMG_SIZE   = int(os.getenv("IMGSZ",     "640"))

# Augmentations per image (your seniors used 5)
AUG_PER_IMAGE = int(os.getenv("AUG_PER_IMAGE", "5"))

# ═════════════════════════════════════════════════════════════════════════════
#  AUGMENTATION  (identical to seniors' training.ipynb)
# ═════════════════════════════════════════════════════════════════════════════

def build_augmentation_pipeline() -> A.Compose:
    """Same transforms your seniors used."""
    return A.Compose(
        [
            A.HorizontalFlip(p=0.5),
            A.RandomBrightnessContrast(p=0.3),
            A.Rotate(limit=15, p=0.3),
            A.Blur(blur_limit=3, p=0.2),
            A.RandomScale(scale_limit=0.1, p=0.3),
        ],
        bbox_params=A.BboxParams(format="yolo", label_fields=["class_labels"]),
    )


def load_yolo_labels(label_path: str):
    """Read a YOLO .txt file → (boxes, class_ids)."""
    boxes, class_ids = [], []
    with open(label_path, "r") as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) != 5:
                continue
            cls, x, y, w, h = parts
            boxes.append([float(x), float(y), float(w), float(h)])
            class_ids.append(int(float(cls)))
    return boxes, class_ids


def save_yolo_labels(output_path: str, boxes, class_ids):
    """Write boxes + class_ids back to a YOLO .txt file."""
    with open(output_path, "w") as f:
        for box, cls in zip(boxes, class_ids):
            f.write(f"{cls} {' '.join(map(str, box))}\n")


def augment_dataset(src_img_dir: str, src_lbl_dir: str,
                    dst_img_dir: str, dst_lbl_dir: str,
                    n_aug: int = AUG_PER_IMAGE):
    """
    Run augmentation on every image in src_img_dir and write
    augmented copies to dst dirs.  Mirrors training.ipynb exactly.
    """
    os.makedirs(dst_img_dir, exist_ok=True)
    os.makedirs(dst_lbl_dir, exist_ok=True)

    transform   = build_augmentation_pipeline()
    image_files = (
        glob.glob(os.path.join(src_img_dir, "*.png")) +
        glob.glob(os.path.join(src_img_dir, "*.jpg")) +
        glob.glob(os.path.join(src_img_dir, "*.jpeg"))
    )
    log.info("Found %d source images in %s", len(image_files), src_img_dir)

    copied = augmented = 0

    for img_file in image_files:
        base      = os.path.basename(img_file)
        stem, ext = os.path.splitext(base)
        lbl_file  = os.path.join(src_lbl_dir, stem + ".txt")

        if not os.path.exists(lbl_file):
            log.warning("No label for %s — skipping", base)
            continue

        shutil.copy(img_file, os.path.join(dst_img_dir, base))
        shutil.copy(lbl_file, os.path.join(dst_lbl_dir, stem + ".txt"))
        copied += 1

        image        = cv2.imread(img_file)
        image        = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        bboxes, cids = load_yolo_labels(lbl_file)

        for i in range(n_aug):
            try:
                aug      = transform(image=image, bboxes=bboxes, class_labels=cids)
                aug_img  = aug["image"]
                aug_bbox = aug["bboxes"]
                aug_cids = aug["class_labels"]

                if not aug_bbox:
                    continue

                cv2.imwrite(
                    os.path.join(dst_img_dir, f"aug_{i}_{base}"),
                    cv2.cvtColor(aug_img, cv2.COLOR_RGB2BGR),
                )
                save_yolo_labels(
                    os.path.join(dst_lbl_dir, f"aug_{i}_{stem}.txt"),
                    aug_bbox,
                    aug_cids,
                )
                augmented += 1

            except Exception as e:
                log.warning("Augmentation failed for %s (aug %d): %s", base, i, e)

    log.info("Augmentation done — %d originals + %d augmented = %d total",
             copied, augmented, copied + augmented)


# ═════════════════════════════════════════════════════════════════════════════
#  DATASET YAML
# ═════════════════════════════════════════════════════════════════════════════

def write_yaml(dataset_path: str, class_names: list, yaml_path: str):
    """Write the YOLO dataset YAML file."""
    content = {
        "path":  str(Path(dataset_path).absolute()),
        "train": "images/train",
        "val":   "images/val",
        "nc":    len(class_names),
        "names": {i: name for i, name in enumerate(class_names)},
    }
    with open(yaml_path, "w") as f:
        yaml.dump(content, f, default_flow_style=False, allow_unicode=True)
    log.info("YAML written to %s  (%d classes)", yaml_path, len(class_names))


# ═════════════════════════════════════════════════════════════════════════════
#  CLASS NAME DETECTION
# ═════════════════════════════════════════════════════════════════════════════

def detect_class_names(data_root: Path) -> list:
    """
    Read class names from classes.txt (written by app.py) or any .yaml
    in data_root.  Falls back to inferring from label IDs.
    """
    # 1. classes.txt written by app.py — preferred
    classes_txt = data_root / "classes.txt"
    if classes_txt.exists():
        names = [l.strip() for l in classes_txt.read_text().splitlines() if l.strip()]
        if names:
            log.info("Class names from classes.txt: %s", names)
            return names

    # 2. Any .yaml in the dataset root
    for yf in data_root.glob("*.yaml"):
        try:
            with open(yf) as f:
                d = yaml.safe_load(f)
            names = d.get("names")
            if names:
                if isinstance(names, list):
                    log.info("Class names from %s: %s", yf.name, names)
                    return names
                if isinstance(names, dict):
                    names = [names[k] for k in sorted(names)]
                    log.info("Class names from %s: %s", yf.name, names)
                    return names
        except Exception:
            pass

    # 3. Infer from label IDs
    label_dir = str(data_root / "labels" / "train")
    ids = set()
    for lf in glob.glob(os.path.join(label_dir, "*.txt")):
        with open(lf) as f:
            for line in f:
                parts = line.strip().split()
                if parts:
                    try:
                        ids.add(int(float(parts[0])))
                    except ValueError:
                        pass

    if ids:
        names = [f"class_{i}" for i in range(max(ids) + 1)]
        log.info("Class names inferred from label IDs: %s", names)
        return names

    log.error("Could not determine class names. Make sure classes.txt exists in %s", data_root)
    sys.exit(1)


# ═════════════════════════════════════════════════════════════════════════════
#  CORE TRAINING
# ═════════════════════════════════════════════════════════════════════════════

def run_training():
    """
    1. Read the dataset that app.py built in DATASET_DIR.
    2. Augment the train split into dataset_aug/.
    3. Write YAML.
    4. Fine-tune YOLO.
    5. Copy best.pt next to this script.
    """
    data_root = Path(DATASET_DIR).resolve()
    log.info("=== VibeStory YOLO Trainer ===")
    log.info("Dataset  : %s", data_root)
    log.info("Epochs   : %d  |  Batch: %d  |  ImgSize: %d", EPOCHS, BATCH_SIZE, IMG_SIZE)

    # ── Validate dataset exists ───────────────────────────────────────────────
    if not data_root.exists():
        log.error(
            "Dataset folder '%s' does not exist.\n"
            "Start the app, label some images, then run this script.",
            data_root,
        )
        sys.exit(1)

    train_img_dir = data_root / "images" / "train"
    train_lbl_dir = data_root / "labels" / "train"
    val_img_dir   = data_root / "images" / "val"
    val_lbl_dir   = data_root / "labels" / "val"

    n_train = len(list(train_img_dir.glob("*.jpg"))) if train_img_dir.exists() else 0
    n_val   = len(list(val_img_dir.glob("*.jpg")))   if val_img_dir.exists()   else 0

    if n_train == 0:
        log.error(
            "No training images found in %s.\n"
            "Label some images in the app first.",
            train_img_dir,
        )
        sys.exit(1)

    log.info("Found %d train images, %d val images", n_train, n_val)

    # ── Detect class names ────────────────────────────────────────────────────
    class_names = detect_class_names(data_root)

    # ── Augment train split ───────────────────────────────────────────────────
    aug_root      = Path("dataset_aug")
    dst_train_img = str(aug_root / "images" / "train")
    dst_train_lbl = str(aug_root / "labels" / "train")
    dst_val_img   = str(aug_root / "images" / "val")
    dst_val_lbl   = str(aug_root / "labels" / "val")

    for d in [dst_val_img, dst_val_lbl]:
        os.makedirs(d, exist_ok=True)

    log.info("Step 1/3 — Augmenting training data…")
    augment_dataset(
        str(train_img_dir), str(train_lbl_dir),
        dst_train_img,      dst_train_lbl,
        n_aug=AUG_PER_IMAGE,
    )

    # ── Copy val split ────────────────────────────────────────────────────────
    log.info("Step 2/3 — Copying validation data…")
    for f in val_img_dir.glob("*"):
        shutil.copy(f, dst_val_img)
    for f in val_lbl_dir.glob("*.txt"):
        shutil.copy(f, dst_val_lbl)

    # If val is still empty, copy a few train samples
    if not list(Path(dst_val_img).glob("*.jpg")):
        log.info("Val split empty — copying a few train samples for validation")
        for f in sorted(Path(dst_train_img).glob("*.jpg"))[:5]:
            shutil.copy(f, dst_val_img)
            lf = (Path(dst_train_lbl) / f.stem).with_suffix(".txt")
            if lf.exists():
                shutil.copy(lf, dst_val_lbl)

    log.info("Val images: %d", len(list(Path(dst_val_img).glob("*.jpg"))))

    # ── Write YAML ────────────────────────────────────────────────────────────
    yaml_path = "vibestory_train.yaml"
    write_yaml(str(aug_root.absolute()), class_names, yaml_path)

    # ── Train ─────────────────────────────────────────────────────────────────
    log.info("Step 3/3 — Training…")
    from ultralytics import YOLO

    # Fine-tune from best.pt if it exists, otherwise from the base model
    start_weights = OUTPUT_WEIGHTS if Path(OUTPUT_WEIGHTS).exists() else BASE_MODEL
    log.info("Starting from: %s", start_weights)

    model = YOLO(start_weights)
    model.train(
        data     = yaml_path,
        epochs   = EPOCHS,
        batch    = BATCH_SIZE,
        imgsz    = IMG_SIZE,
        patience = 20,
        save     = True,
        plots    = True,
    )

    # ── Copy best.pt next to this script ─────────────────────────────────────
    trained_best = Path("runs/detect/train/weights/best.pt")
    if not trained_best.exists():
        candidates = sorted(
            Path("runs/detect").glob("*/weights/best.pt"),
            key=lambda p: p.stat().st_mtime, reverse=True,
        )
        trained_best = candidates[0] if candidates else None

    if trained_best and trained_best.exists():
        shutil.copy(trained_best, OUTPUT_WEIGHTS)
        log.info("✅  Training done!  best.pt → %s", Path(OUTPUT_WEIGHTS).absolute())
    else:
        log.error("Could not find best.pt in runs/ — check YOLO output above.")


# ═════════════════════════════════════════════════════════════════════════════
#  DATASET HEALTH CHECK
# ═════════════════════════════════════════════════════════════════════════════

def check_dataset():
    """Print class distribution and flag any invalid labels."""
    data_root     = Path(DATASET_DIR).resolve()
    class_names   = detect_class_names(data_root)
    label_dir     = str(data_root / "labels" / "train")
    counts        = Counter()
    bad           = []
    n_files       = 0

    for lf in glob.glob(os.path.join(label_dir, "*.txt")):
        n_files += 1
        with open(lf) as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) != 5:
                    bad.append((lf, "malformed line"))
                    continue
                try:
                    cid = int(float(parts[0]))
                    if cid >= len(class_names):
                        bad.append((lf, f"class id {cid} >= nc {len(class_names)}"))
                    else:
                        counts[cid] += 1
                except ValueError:
                    bad.append((lf, f"non-numeric class '{parts[0]}'"))

    print(f"\n📊 Dataset check — {n_files} label files in {label_dir}")
    print(f"Classes ({len(class_names)}): {class_names}")
    print("\nClass distribution:")
    for cid in sorted(counts):
        print(f"  {class_names[cid]} (id={cid}): {counts[cid]} instances")
    if bad:
        print(f"\n⚠️  {len(bad)} problem(s) found:")
        for path, reason in bad[:20]:
            print(f"  {path}: {reason}")
    else:
        print("\n✅  All labels valid")


# ═════════════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ═════════════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(
        description="VibeStory YOLO fine-tuner",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Train on labels collected by the app:
  python train.py

  # Check dataset health before training:
  python train.py --check

  # Override hyper-params:
  EPOCHS=50 BATCH=4 python train.py

  # Use a different dataset folder:
  DATASET_DIR=./my_data python train.py

  # Use a different starting model:
  BASE_MODEL=yolov8n.pt python train.py
        """,
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Run a health check on the dataset labels, then exit",
    )
    args = parser.parse_args()

    if args.check:
        check_dataset()
    else:
        run_training()


if __name__ == "__main__":
    main()