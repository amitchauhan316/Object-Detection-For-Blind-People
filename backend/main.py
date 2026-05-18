from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from datetime import datetime
import google.generativeai as genai
import shutil, os, json
import cv2

from gtts import gTTS
from fastapi.responses import FileResponse

# Set environment variables to prevent hangs
os.environ['YOLO_VERBOSE'] = 'False'
os.environ['PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK'] = 'True'

# OCR initialization (lazy loading - only when needed)
OCR_AVAILABLE = False
OCR_TYPE = "none"
ocr = None
reader = None

def initialize_ocr():
    """Initialize EasyOCR for text detection (primary choice)."""
    global OCR_AVAILABLE, OCR_TYPE, reader

    if OCR_AVAILABLE:
        return  # Already initialized

    try:
        import easyocr
        print("📍 Loading EasyOCR for English and Hindi...")
        reader = easyocr.Reader(['en', 'hi'], gpu=False)  # Set gpu=True if CUDA available
        OCR_AVAILABLE = True
        OCR_TYPE = "easyocr"
        print("✅ EasyOCR initialized successfully for English and Hindi")
        return
    except Exception as e:
        print(f"⚠️ EasyOCR initialization failed: {e}")
        OCR_AVAILABLE = False
        print("⚠️ Text detection disabled")

# OCR will be initialized on first use only

# =========================
# 🔑 PUT YOUR NEW GEMINI KEY HERE
# =========================
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

print("✅ Gemini configured")  # Commented out to prevent import hangs

# =========================
app = FastAPI(title="VisionWalk Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ===== Backend Directory Setup =====
BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_DIR = os.path.join(BACKEND_DIR, "uploads")
LOG_DIR = os.path.join(BACKEND_DIR, "logs")
os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(LOG_DIR, exist_ok=True)

LOG_FILE = os.path.join(LOG_DIR, "activity_log.json")

# ===== Model Paths =====
MODEL_PATHS = {
    "yolo": os.path.join(BACKEND_DIR, "yolov8n.pt"),
    "currency": os.path.join(BACKEND_DIR, "Currency_Model.pt"),
    "document": os.path.join(BACKEND_DIR, "document_detection.pt"),
    "image": os.path.join(BACKEND_DIR, "indoor_dataset.pt"),
    # Note: Text detection uses EasyOCR directly, no YOLO model needed
}

print("\n📍 Backend Directory:", BACKEND_DIR)
for model_name, path in MODEL_PATHS.items():
    exists = os.path.exists(path)
    status = "✅" if exists else "❌"
    print(f"{status} {model_name}: {path}")

# =========================
def load_logs():
    if not os.path.exists(LOG_FILE):
        return []
    try:
        with open(LOG_FILE, "r") as f:
            return json.load(f)
    except:
        return []

def save_log(data):
    logs = load_logs()
    logs.insert(0, data)
    with open(LOG_FILE, "w") as f:
        json.dump(logs, f, indent=4)

# =========================

def load_image(image_path):
    img = cv2.imread(image_path)
    if img is None:
        raise ValueError(f"Unable to read image: {image_path}")
    return img


def get_genai_text(response):
    try:
        candidates = getattr(response, "candidates", None)
        if candidates:
            first = candidates[0]
            content = getattr(first, "content", None)
            if content is not None:
                parts = getattr(content, "parts", None) or []
                if isinstance(parts, list) and len(parts) > 0:
                    text = getattr(parts[0], "text", None)
                    if text:
                        return text
            finish_message = getattr(first, "finish_message", None)
            if finish_message:
                return finish_message
        return getattr(response, "text", str(response))
    except Exception:
        return str(response)

# =========================
@app.get("/")
def home():
    return {"status": "VisionWalk running"}

# Load YOLO on demand only (not at startup)
YOLO = None

def get_yolo():
    global YOLO
    if YOLO is None:
        try:
            from ultralytics import YOLO as YOLOClass
            YOLO = YOLOClass
            print("✅ YOLO imported successfully")
        except Exception as e:
            print(f"❌ YOLO import failed: {e}")
            YOLO = None
    return YOLO

# Initialize model variables (load on first use)
yolo_model = None
currency_model = None
text_interpreter = None
document_model = None
image_model = None

def load_yolo_model(model_name):
    """Load YOLO model with error handling and absolute path resolution"""
    global yolo_model, currency_model, text_interpreter, document_model, image_model

    YOLOClass = get_yolo()
    if YOLOClass is None:
        print(f"⚠️ Cannot load {model_name} model - YOLO not available")
        return None

    # Get the model path from the MODEL_PATHS dictionary
    model_path = MODEL_PATHS.get(model_name)
    if model_path is None:
        print(f"⚠️ Unknown model name: {model_name}")
        return None

    # Check if model file exists
    if not os.path.exists(model_path):
        print(f"⚠️ Model file not found: {model_path}")
        # List available model files
        print(f"   Available files in {BACKEND_DIR}:")
        for f in os.listdir(BACKEND_DIR):
            if f.endswith('.pt'):
                print(f"     - {f}")
        return None

    try:
        if model_name == "yolo" and yolo_model is None:
            yolo_model = YOLOClass(model_path)
            print(f"✅ {model_name} model loaded from {model_path}")
            return yolo_model
        elif model_name == "currency" and currency_model is None:
            currency_model = YOLOClass(model_path)
            print(f"✅ {model_name} model loaded from {model_path}")
            return currency_model
        elif model_name == "text" and text_interpreter is None:
            text_interpreter = YOLOClass(model_path)
            print(f"✅ {model_name} model loaded from {model_path}")
            return text_interpreter
        elif model_name == "document" and document_model is None:
            document_model = YOLOClass(model_path)
            print(f"✅ {model_name} model loaded from {model_path}")
            return document_model
        elif model_name == "image" and image_model is None:
            image_model = YOLOClass(model_path)
            print(f"✅ {model_name} model loaded from {model_path}")
            return image_model
        else:
            # Model already loaded, return it
            if model_name == "yolo":
                return yolo_model
            elif model_name == "currency":
                return currency_model
            elif model_name == "text":
                return text_interpreter
            elif model_name == "document":
                return document_model
            elif model_name == "image":
                return image_model
    except Exception as e:
        print(f"⚠️ Failed to load {model_name} model from {model_path}: {e}")
        return None

print("🟢 YOLO will load on first use")


# -------------------------------# 💰 CURRENCY CLASSES
# -------------------------------
CURRENCY_CLASSES = {
    0: '₹10 Note',
    1: '₹20 Note',
    2: '₹50 Note',
    3: '₹100 Note',
    4: '₹200 Note',
    5: '₹500 Note',
    6: '₹2000 Note'
}

# -------------------------------# � DOCUMENT CLASSES
# -------------------------------
DOCUMENT_CLASSES = {
    0: 'PAN Card',
    1: 'Aadhaar Card',
    2: 'Driving License',
    3: 'Passport',
    4: 'Voter ID',
    5: 'Bank Passbook'
}


# -------------------------------
# �🔧 COMMON FUNCTION (TFLite)
# -------------------------------
def run_tflite(interpreter, image):
    if image is None:
        raise ValueError("No image provided to TFLite model")

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    height = input_details[0]['shape'][1]
    width = input_details[0]['shape'][2]

    img = cv2.resize(image, (width, height))
    img = np.expand_dims(img, axis=0).astype("float32") / 255.0

    interpreter.set_tensor(input_details[0]['index'], img)
    interpreter.invoke()

    output = interpreter.get_tensor(output_details[0]['index'])

    return output

@app.post("/detect")
async def detect_object(file: UploadFile = File(...)):
    # Load yolo model if not loaded
    global yolo_model
    if yolo_model is None:
        yolo_model = load_yolo_model("yolo")
    
    if yolo_model is None:
        return {
            "objects": [],
            "message": "YOLO model not available"
        }

    image_path = f"{UPLOAD_DIR}/{datetime.now().timestamp()}_{file.filename}"

    try:
        # ✅ unique filename (important for realtime)
        with open(image_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        img = load_image(image_path)
        # 🔥 FASTER inference
        results = yolo_model(img, imgsz=640, conf=0.35)

        boxes = results[0].boxes

        if boxes is None or len(boxes) == 0:
            return {
                "objects": [],
                "message": "No object detected"
            }

        detected_objects = []

        width = img.shape[1]

        for box in boxes:
            cls_id = int(box.cls[0])
            conf = float(box.conf[0])

            name = yolo_model.names[cls_id]             # ✅ Get position
            x_center = float(box.xywh[0][0])

            if x_center < width * 0.33:
                position = "left"
            elif x_center < width * 0.66:
                position = "center"
            else:
                position = "right"

            detected_objects.append({
                "name": name,
                "confidence": round(conf, 2),
                "position": position
            })

        # ✅ Sort by confidence
        detected_objects = sorted(
            detected_objects,
            key=lambda x: x["confidence"],
            reverse=True
        )

        # Save only top 3 (log light rahe)
        save_log({
            "type": "detect",
            "objects": detected_objects[:3],
            "time": datetime.now().isoformat()
        })
        return {
            "objects": detected_objects[:5],  # send top 5 only
            "top_object": detected_objects[0]["name"]
        }

    except Exception as e:
        print("YOLO ERROR:", e)

        return {
            "objects": [],
            "message": "Detection failed"
        }

    finally:
        if os.path.exists(image_path):
            os.remove(image_path)

@app.post("/capture-detect")
async def capture_detect(file: UploadFile = File(...)):
    # Load yolo model if not loaded
    global yolo_model
    if yolo_model is None:
        yolo_model = load_yolo_model("yolo")
    
    if yolo_model is None:
        return {
            "object": "Model not available",
            "confidence": 0
        }

    image_path = f"{UPLOAD_DIR}/{datetime.now().timestamp()}_{file.filename}"

    try:
        with open(image_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        img = load_image(image_path)

        results = yolo_model(
            img,
            imgsz=640,   # accuracy important for manual capture
            conf=0.40,
            verbose=False
        )

        boxes = results[0].boxes

        if boxes is None or len(boxes) == 0:
            return {
                "object": "No object found",
                "confidence": 0
            }

        # take TOP detection
        best_box = boxes[0]

        cls_id = int(best_box.cls[0])
        conf = float(best_box.conf[0])
        name = yolo_model.names[cls_id]

        save_log({
            "type": "capture_detect",
            "object": name,
            "confidence": conf,
            "time": datetime.now().isoformat()
        })

        return {
            "object": name,
            "confidence": round(conf, 2)
        }

    except Exception as e:
        print("CAPTURE DETECT ERROR:", e)
        return {
            "object": "Detection failed",
            "confidence": 0
        }

    finally:
        if os.path.exists(image_path):
            os.remove(image_path)
# -------------------------------
# 💰 CURRENCY DETECTION
# -------------------------------
@app.post("/capture-detect/currency")
async def detect_currency(file: UploadFile = File(...)):
    global currency_model
    # Load currency model if not loaded
    if currency_model is None:
        currency_model = load_yolo_model("currency")

    if currency_model is None:
        return {
            "type": "currency",
            "prediction": "Model not available",
            "confidence": 0,
            "error": "Currency model failed to load"
        }

    image_path = f"{UPLOAD_DIR}/{datetime.now().timestamp()}_{file.filename}"

    try:
        with open(image_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        img = load_image(image_path)
        results = currency_model(img, imgsz=640, conf=0.60)  # Increased confidence threshold
        boxes = results[0].boxes

        if boxes is None or len(boxes) == 0:
            return {
                "type": "currency",
                "prediction": "No currency detected",
                "confidence": 0,
                "suggestion": "Show currency note clearly"
            }

        best_box = boxes[0]
        cls_id = int(best_box.cls[0])
        confidence = float(best_box.conf[0])
        currency_name = CURRENCY_CLASSES.get(cls_id, f"Unknown Currency ({cls_id})")

        # Only return if confident enough
        if confidence < 0.60:
            return {
                "type": "currency",
                "prediction": "Uncertain detection",
                "confidence": round(confidence, 2),
                "suggestion": "Try again with clearer image"
            }

        save_log({
            "type": "currency_detection",
            "prediction": currency_name,
            "confidence": round(confidence, 2),
            "time": datetime.now().isoformat()
        })

        return {
            "type": "currency",
            "prediction": currency_name,
            "confidence": round(confidence, 2),
            "status": "success"
        }

    except Exception as e:
        print("CURRENCY ERROR:", e)
        return {
            "type": "currency",
            "prediction": "Detection failed",
            "confidence": 0,
            "error": str(e)[:100]
        }

    finally:
        if os.path.exists(image_path):
            os.remove(image_path)


# -------------------------------
# 🧾 TEXT DETECTION
# -------------------------------
@app.post("/capture-detect/text")
async def detect_text(file: UploadFile = File(...)):
    image_path = f"{UPLOAD_DIR}/{datetime.now().timestamp()}_{file.filename}"

    try:
        with open(image_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        img = load_image(image_path)

        # Use OCR for text detection
        if not OCR_AVAILABLE:
            initialize_ocr()  # Try to initialize OCR

        if OCR_AVAILABLE and reader is not None:
            try:
                # Use EasyOCR
                result = reader.readtext(image_path)

                extracted_texts = []
                for detection in result:
                    bbox, text, confidence = detection
                    if confidence > 0.4:  # Only high confidence text
                        extracted_texts.append({
                            "text": text,
                            "confidence": round(float(confidence), 2)
                        })

                ocr_language = "en_hi_easyocr"

                # Log activity
                save_log({
                    "type": "text_detection",
                    "extracted_texts": extracted_texts,
                    "count": len(extracted_texts),
                    "ocr_engine": OCR_TYPE,
                    "language": ocr_language,
                    "time": datetime.now().isoformat()
                })

                if extracted_texts:
                    return {
                        "type": "text",
                        "texts": extracted_texts,
                        "total_detected": len(extracted_texts),
                        "ocr_engine": OCR_TYPE,
                        "language": ocr_language,
                        "status": "success"
                    }
                else:
                    return {
                        "type": "text",
                        "texts": [],
                        "total_detected": 0,
                        "ocr_engine": OCR_TYPE,
                        "language": ocr_language,
                        "status": "no_text_found",
                        "message": "No text detected in image"
                    }

            except Exception as ocr_error:
                print(f"EasyOCR processing error: {ocr_error}")
                return {
                    "type": "text",
                    "texts": [],
                    "status": "ocr_error",
                    "message": f"EasyOCR processing failed: {str(ocr_error)[:100]}"
                }

        else:
            # No OCR available
            return {
                "type": "text",
                "texts": [],
                "status": "ocr_not_available",
                "message": "OCR not available - install easyocr: pip install easyocr"
            }

    except Exception as e:
        print("TEXT DETECTION ERROR:", e)
        return {
            "type": "text",
            "texts": [],
            "status": "error",
            "message": str(e)[:100]
        }

    finally:
        if os.path.exists(image_path):
            os.remove(image_path)


# -------------------------------
# 📄 DOCUMENT DETECTION
# -------------------------------
@app.post("/capture-detect/document")
async def detect_document(file: UploadFile = File(...)):
    global document_model
    if document_model is None:
        document_model = load_yolo_model("document")

    if document_model is None:
        return {
            "type": "document",
            "prediction": "Model not available",
            "confidence": 0,
            "error": "Document model failed to load"
        }

    image_path = f"{UPLOAD_DIR}/{datetime.now().timestamp()}_{file.filename}"

    try:
        with open(image_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        img = load_image(image_path)

        results = document_model(
            img,
            imgsz=640,
            conf=0.50,           # Balanced confidence threshold
            iou=0.5,
            verbose=False
        )

        boxes = results[0].boxes

        if boxes is None or len(boxes) == 0:
            return {
                "type": "document",
                "prediction": "No document detected",
                "confidence": 0,
                "suggestion": "Please show the document clearly"
            }

        # Get best detection
        best_box = boxes[0]
        cls_id = int(best_box.cls[0])
        confidence = float(best_box.conf[0])

        document_type = DOCUMENT_CLASSES.get(cls_id, f"Unknown Document ({cls_id})")

        # Log activity
        save_log({
            "type": "document_detection",
            "document_type": document_type,
            "confidence": round(confidence, 2),
            "time": datetime.now().isoformat()
        })

        return {
            "type": "document",
            "prediction": document_type,
            "confidence": round(confidence, 2),
            "status": "success"
        }

    except Exception as e:
        print("DOCUMENT DETECTION ERROR:", e)
        return {
            "type": "document",
            "prediction": "Detection failed",
            "confidence": 0,
            "error": str(e)[:100]
        }

    finally:
        if os.path.exists(image_path):
            os.remove(image_path)


# -------------------------------
# 🖼️ IMAGE DETECTION (placeholder)
# -------------------------------
@app.post("/capture-detect/image")
async def detect_image(file: UploadFile = File(...)):
    global image_model
    # Load image model if not loaded
    if image_model is None:
        image_model = load_yolo_model("image")

    if image_model is None:
        return {
            "type": "image",
            "prediction": "Model not available",
            "confidence": 0,
            "error": "Image model failed to load"
        }

    image_path = f"{UPLOAD_DIR}/{datetime.now().timestamp()}_{file.filename}"

    try:
        with open(image_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        img = load_image(image_path)
        results = image_model(img, imgsz=640, conf=0.35)
        boxes = results[0].boxes

        if boxes is None or len(boxes) == 0:
            return {
                "type": "image",
                "prediction": "No object detected",
                "confidence": 0
            }

        best_box = boxes[0]
        cls_id = int(best_box.cls[0])
        confidence = float(best_box.conf[0])
        name = image_model.names[cls_id]

        return {
            "type": "image",
            "prediction": name,
            "confidence": round(confidence, 2)
        }

    except Exception as e:
        print("IMAGE ERROR:", e)
        return {
            "type": "image",
            "prediction": "Detection failed",
            "confidence": 0
        }

    finally:
        if os.path.exists(image_path):
            os.remove(image_path)


# =====================================================
# AI ASSISTANT — GEMINI REAL
# =====================================================

class ChatRequest(BaseModel):
    message: str

SYSTEM_PROMPT = """
You are VisionWalk AI assistant for blind users.
Reply short, simple, helpful.
Support English Hindi Gujarati.
"""

@app.post("/assistant/chat")
async def ai_chat(req: ChatRequest):

    try:
        prompt = SYSTEM_PROMPT + "\nUser: " + req.message

        model = genai.GenerativeModel("gemini-1.5-flash")
        response = model.generate_content(prompt)

        reply = get_genai_text(response)

        print("AI OK:", reply[:60])
        
        save_log({
            "type": "chat",
            "q": req.message,
            "a": reply,
            "time": datetime.now().isoformat()
        })

        return {"reply": reply, "status": "success"}

    except Exception as e:
        print("❌ GEMINI ERROR:", e)
        error_reply = f"AI temporarily unavailable: {str(e)[:50]}"
        
        save_log({
            "type": "chat",
            "q": req.message,
            "a": error_reply,
            "error": str(e),
            "time": datetime.now().isoformat()
        })

        return {"reply": "AI service temporarily unavailable. Please try again.", "status": "error", "error": str(e)}

# =====================================================
# AI ASSISTANT — VOICE COMMAND PROCESSOR (JSON ROUTER)
# =====================================================

ROUTER_PROMPT = """
You are the routing engine for 'VisionWalk', an app for blind users.
Analyze the user's voice message and decide what action the app should take.
Respond ONLY with a valid JSON object matching this schema:
{
  "action": "...",
  "reply": "..."
}

Possible 'action' values:
- "torch_on" : turn on the flashlight
- "torch_off" : turn off the flashlight
- "torch_toggle" : toggle flashlight
- "camera_switch" : switch between front and back camera
- "capture" : capture an image
- "describe" : describe the current camera view
- "navigate_home" : go to the home page
- "navigate_assistant" : go to voice assistant page
- "navigate_activity" : go to calendar/activity page
- "navigate_settings" : go to settings
- "navigate_text" : go to text detection
- "navigate_document" : go to document detection
- "navigate_currency" : go to currency detection
- "navigate_food" : go to food labels
- "navigate_find" : go to find mode
- "navigate_image" : go to image detection
- "navigate_help" : go to help page
- "chat" : for general questions or conversation. Put your verbal response in the 'reply' field.

Determine intent accurately for Gujarati, Hindi, and English. 
Return ONLY the raw JSON object, without any Markdown formatting (no ```json).
"""

@app.post("/assistant/command")
async def process_voice_command(req: ChatRequest):
    try:
        model = genai.GenerativeModel("gemini-1.5-flash")
        response = model.generate_content(ROUTER_PROMPT + "\nUser Message: " + req.message)

        reply_text = get_genai_text(response).strip().removeprefix("```json").removesuffix("```").strip()
        
        # Parse JSON to ensure validity
        command_data = json.loads(reply_text)
        
        save_log({
            "type": "command_route",
            "q": req.message,
            "action": command_data.get("action", "unknown"),
            "time": datetime.now().isoformat()
        })

        return command_data

    except Exception as e:
        print("❌ ROUTER ERROR:", e)
        return {
            "action": "error",
            "reply": "Sorry, I couldn't process this voice command."
        }

# =====================================================
# HISTORY
# =====================================================
@app.get("/history")
def history():
    return load_logs()

# =====================================================
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host="0.0.0.0",   # ✅ important
        port=8000,
    )