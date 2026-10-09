# Milestone 3: Interactive Object Detection & Human-in-the-Loop Labeling

## 1. Objective
Our goal for Milestone 3 was to introduce an educational, interactive Computer Vision module. Instead of just reading stories passively, users can explore objects inside the AI-generated pictures, verify what the AI detected, and draw their own bounding boxes around things they see.

---

## 2. Why We Did This (Research Context)
In machine learning, collecting labeled images usually takes a lot of time and requires paid annotators. In our research, we wanted to test a **Human-in-the-Loop** approach:
- *Can we use an existing object detection model (YOLO) as a first-pass helper, and let everyday users verify, correct, and add new annotations?*
- *Can we gamify this experience (giving points and badges) so users actually enjoy finding and labeling objects?*

---

## 3. What We Implemented

### A. YOLO Detection on Generated Artwork
- In `backend/app.py`:
  - Created the endpoint `POST /api/learn/detect`.
  - Runs YOLO on the selected story picture.
  - Returns bounding boxes with object names and confidence scores (for example, finding a tree with 88% confidence).

### B. Interactive Touch Canvas in Flutter (`LearnImageScreen`)
- Built in `frontend/vibestory/lib/main.dart`:
  - **AI Detection Display:**
    - Tapping "AI detect" asks the server to find objects and overlays teal colored boxes with labels and percentages (like `cat 90%` or `tree 85%`).
    - If the AI made a mistake, tapping any box opens a simple pop-up where the user can re-type the correct name.
  - **Manual Bounding Box Drawing:**
    - Users can tap "Draw boxes" mode.
    - We used touch gesture listeners to track when the user places their finger down and drags across the screen.
    - As the user drags, a live colored rectangle stretches with their finger.
    - When they lift their finger, a friendly pop-up asks: *"What is this? (e.g. apple, mountain, house)"*.
    - The new box is saved in violet color right on top of the image.

### C. Screen-to-Image Coordinate Mapping
- Every phone screen has a different physical size, resolution, and pixel density, while our backend images have a fixed resolution (800 by 400 pixels).
- To make sure drawn boxes match the real picture:
  - The mobile app scales the user's touch coordinates from the phone screen onto the original image resolution.
  - This ensures that whether someone is using a small phone or a large tablet, the bounding box lands on the exact same object in the image file.

### D. Gamification & Explorer Badges
- In `backend/app.py`:
  - Every time the user submits labels, the server awards **10 points per object** and updates their score in MongoDB.
- In `ProfileScreen` (`main.dart`):
  - Users unlock explorer badges as their score grows:
    - 0 to 49 points: **Story Seedling**
    - 50 to 199 points: **Curious Learner**
    - 200 to 499 points: **Object Hunter**
    - 500 to 999 points: **Super Finder**
    - 1,000+ points: **Legend Explorer**
  - Displays total objects found, total points, and total stories completed.

---

## 4. Key Challenges & How We Solved Them
1. **Handling different screen sizes:** If a user draws a box on a small iPhone versus an Android phone, the raw screen pixels are completely different. We solved this by mapping the phone's touch coordinates onto the image's original dimensions so the data is always consistent.
2. **Correcting AI mistakes easily:** If YOLO mistakes a dog for a wolf, the user doesn't need to delete the box. They simply tap the box and type the correct name, and the server updates it instantly.

---

## 5. Milestone Outcome
- An intuitive on-screen labeling canvas right inside the mobile app.
- AI detection assistance combined with manual drawing mode.
- A gamification system that turns data annotation into a fun reward-based activity for students and children.
