import firebase_admin
from firebase_admin import credentials, storage, firestore

firebase_client = None

class FirebaseClient:
    def __init__(self, cred_path, storage_bucket, database_id):
        self.cred = credentials.Certificate(cred_path)
        self.app = firebase_admin.initialize_app(self.cred, {
            'storageBucket': storage_bucket,
        })
        self.bucket = storage.bucket(app=self.app)
        self.firestore_client = firestore.client(app=self.app, database_id=database_id)

    def download_wav_from_storage(self, file_path: str) -> bytes:
        blob = self.bucket.blob(file_path)
        return blob.download_as_bytes()

    def write_prediction_to_firestore(
        self,
        path: str,
        user_id: str,
        predictionData: dict
    ):
        safe_doc_id = path.replace("/", "_")

        data = {
            "user_id": user_id,
            "predictionData": predictionData,
            "timestamp": firestore.SERVER_TIMESTAMP
        }

        doc_ref = self.firestore_client \
                          .collection("predictions") \
                          .document(safe_doc_id)
                          
        doc_ref.set(data, merge=True)
        
def init_firebase_client(cred_path, storage_bucket, database_id):
    global firebase_client
    if firebase_client is None:
        firebase_client = FirebaseClient(cred_path, storage_bucket, database_id)
    return firebase_client

def get_firebase_client():
    if firebase_client is None:
        raise RuntimeError("Firebase client not initialized. Call init_firebase_client() first.")
    return firebase_client