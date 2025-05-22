import torch
import torch.nn.functional as F
from transformers import Wav2Vec2Processor
from app.models.model import LieDetectionModel

_model_instance = None
_processor_instance = None

def init_model(model_path: str) -> None:
    global _model_instance, _processor_instance
    if _model_instance is None:
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        _model_instance = LieDetectionModel(pretrained_model_dir=model_path, num_classes=2)
        _model_instance.load_state_dict(torch.load(f"{model_path}/lie_detection_model.pth", map_location=device))
        _model_instance.to(device)
        _model_instance.eval()
    if _processor_instance is None:
        _processor_instance = Wav2Vec2Processor.from_pretrained(model_path)

def get_model() -> LieDetectionModel:
    if _model_instance is None:
        raise RuntimeError("Model not initialized. Call init_model() first.")
    return _model_instance

def get_processor() -> Wav2Vec2Processor:
    if _processor_instance is None:
        raise RuntimeError("Processor not initialized. Call init_model() first.")
    return _processor_instance

def predict(inputs: torch.Tensor) -> torch.Tensor:
    model = get_model()
    device = next(model.parameters()).device
    inputs = inputs.to(device)
    with torch.no_grad():
        logits = model(inputs)
        probs  = F.softmax(logits, dim=1)
        confidences, preds = torch.max(probs, dim=1)

    return preds, confidences
