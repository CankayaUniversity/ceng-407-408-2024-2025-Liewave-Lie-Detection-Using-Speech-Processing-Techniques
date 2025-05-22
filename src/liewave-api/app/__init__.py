import os
from dotenv import load_dotenv
from flask import Flask
from app.routes.predict import predict_bp
from app.services.model_service import init_model
from app.helpers.firebase_helper import init_firebase_client

def create_app():
    load_dotenv()
    
    app = Flask(__name__)

    init_firebase_client(
        cred_path=os.getenv("FIREBASE_CREDENTIALS_PATH"),
        storage_bucket=os.getenv("STORAGE_BUCKET"),
        database_id=os.getenv("FIREBASE_DATABASE_ID")
    )
    
    init_model(os.getenv("MODEL_PATH"))
    
    app.register_blueprint(predict_bp)

    return app