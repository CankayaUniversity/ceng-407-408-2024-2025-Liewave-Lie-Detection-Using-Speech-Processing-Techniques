from app.services import preprocessor_service, model_service
from app.helpers import firebase_helper
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
import subprocess
import os

def predict(path: str, user_id: str):
    firebase_client = firebase_helper.get_firebase_client()
    model = model_service.get_model()

    aac_bytes = firebase_client.download_wav_from_storage(path)

    wav_bytes = convert_aac_bytes_to_wav_bytes(aac_bytes)

    inputs = preprocessor_service.preprocess_audio(wav_bytes)
    
    preds, confidence = model_service.predict(inputs)
    pred = "truth" if preds.item() == 0 else "lie"
    conf = round(confidence.item(), 2)
    
    prediction_data = {
        "prediction": pred, 
        "confidence": conf
    }

    firebase_client.write_prediction_to_firestore(path, user_id, prediction_data)

    return prediction_data

def convert_aac_bytes_to_wav_bytes(aac_bytes: bytes) -> bytes:
    ffmpeg_path = os.getenv("FFMPEG_PATH")

    command = [
        ffmpeg_path,
        '-y',
        '-i', 'pipe:0',
        '-f', 'wav',
        '-acodec', 'pcm_s16le',
        '-ar', '44100',
        'pipe:1'
    ]

    process = subprocess.run(
        command,
        input=aac_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True
    )
    wav_bytes = process.stdout
    return wav_bytes