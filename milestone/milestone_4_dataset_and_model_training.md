# Milestone 4: Dataset Pipeline, Data Augmentation & Model Fine-Tuning

## 1. Objective
Our goal for Milestone 4 was to close the machine learning loop. We wanted to take all the annotations submitted by users in Milestone 3, convert them into an industry-standard YOLO dataset, apply data augmentation to expand the dataset, and fine-tune a YOLO detection model.

---

## 2. Why We Did This (Research Context)
Most projects stop after building an app or showing images. In our research, we wanted to answer:
- *Can we build a continuous learning system where user interaction directly produces clean training data for the next model version?*
- *Can data augmentation prevent the model from overfitting on a small, crowdsourced set of anime illustrations?*

---

## 3. What We Implemented

### A. Automatic YOLO Dataset Engine
- In `backend/app.py`:
  - Whenever a user clicks "Submit labels", the backend automatically:
    1. Copies the story image into the dataset folder and converts it to a standard JPEG image.
    2. Automatically splits the data into two groups: **90% for training** and **10% for validation** (testing).
    3. Converts user-drawn box coordinates into standard relative YOLO format (storing center, width, and height as percentages of image size rather than raw pixels).
    4. Saves these coordinates into `.txt` annotation files.
    5. Appends any newly discovered object names to `classes.txt`.
    6. Automatically updates `dataset.yaml` so any YOLO training tool can read the dataset immediately.

### B. Dataset Export & Inspection APIs
- Added `GET /api/learn/dataset-stats`: returns how many images and labels exist in the training and validation sets.
- Added `GET /api/learn/export-dataset`: bundles the entire dataset into a single `yolo_dataset.zip` download with one click, making it easy to back up or move to Google Colab.

### C. Dataset Health Check Tool
- In `backend/train.py`, we created a health-check command (`python train.py --check`):
  - Scans all annotation text files.
  - Checks that every line has the correct 5-item box structure.
  - Verifies that object IDs match the names in `classes.txt`.
  - Prints a clean summary table showing how many instances of each object (trees, cats, birds, etc.) exist in the dataset.

### D. Data Augmentation Pipeline
- In `backend/train.py`:
  - Because human-labeled images start off small in number, training directly on them could cause the AI to memorize instead of learn.
  - We used the **Albumentations** computer vision library to apply realistic transformations:
    - Flipping images horizontally.
    - Slightly adjusting brightness and contrast.
    - Gentle rotations to simulate different angles.
    - Light blur to simulate motion or distance.
    - Subtle zoom in and zoom out.
  - The bounding boxes are automatically adjusted along with each picture so the labels stay aligned with the objects.
  - Every single original image generates 5 new augmented variations, giving the model much more varied data to learn from.

### E. Model Fine-Tuning Script
- In `backend/train.py`:
  - Reads the dataset, generates the augmented images, and fine-tunes the YOLO model.
  - Uses early stopping so training stops automatically if the model stops improving.
  - When training finishes, the best weights file (`best.pt`) is saved automatically.
  - The backend server (`app.py`) immediately picks up these new weights on future detection requests, completing the upgrade.

---

## 4. Key Challenges & How We Solved Them
1. **Preventing corrupted or negative boxes:** If a user drags a box backwards (from bottom-right to top-left), raw subtraction could result in negative widths. We fixed this in Flutter by sorting the coordinates and clamping all values inside the image boundaries.
2. **Preventing overfitting on anime art:** Studio Ghibli art has a unique hand-drawn look that standard models have rarely seen. Our data augmentation pipeline creates varied versions of each drawing so the fine-tuned model learns general visual patterns rather than memorizing individual pictures.

---

## 5. Milestone Outcome
- A complete, continuous machine learning loop:
  `AI Generates Art  ->  Users Label Objects  ->  System Builds Dataset  ->  Model Fine-Tunes`
- Standard YOLO dataset files ready for local training or cloud GPUs.
- An end-to-end research project showing how generative AI and computer vision can work together in an interactive educational application.
