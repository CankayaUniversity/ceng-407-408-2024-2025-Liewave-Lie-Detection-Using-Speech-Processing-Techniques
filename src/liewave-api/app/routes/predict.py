from flask import Blueprint, request, jsonify
from app.services import prediction_service

predict_bp = Blueprint("predict", __name__)

@predict_bp.route("/predict", methods=["POST"])
def predict_route():
    data = request.json
    path = data.get("path")
    user_id = data.get("user_id")

    if not path or not user_id:
        return jsonify({"error": "Missing wav_url or user_id"}), 400

    try:
        prediction_data = prediction_service.predict(path, user_id)
        return jsonify({"prediction_data":prediction_data, "user_id": user_id}), 200

    except Exception as e:
        return jsonify({"error": f"Internal error: {str(e)}"}), 500
