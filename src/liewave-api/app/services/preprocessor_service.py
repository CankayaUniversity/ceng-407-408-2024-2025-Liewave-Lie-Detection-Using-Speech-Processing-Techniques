import torchaudio
from app.services.model_service import get_processor
import io
import os
import torch

def preprocess_audio(source) -> torch.Tensor:
    """
    Load audio from bytes, resample to 16kHz, convert to mono,
    tokenize/process with Wav2Vec2Processor, and return input tensor.
    """
    if isinstance(source, bytes):
        waveform, sample_rate = torchaudio.load(io.BytesIO(source))
    elif isinstance(source, str) and os.path.isfile(source):
        waveform, sample_rate = torchaudio.load(source)
    else:
        raise ValueError("Invalid audio source. Must be file path or bytes.")
    
    if sample_rate != 16000:
        resampler = torchaudio.transforms.Resample(orig_freq=sample_rate, new_freq=16000)
        waveform = resampler(waveform)

    if waveform.size(0) > 1:
        waveform = waveform.mean(dim=0, keepdim=True)

    processor = get_processor()
    
    inputs = processor(waveform.squeeze(0), sampling_rate=16000, return_tensors="pt", padding=True)

    return inputs["input_values"]
