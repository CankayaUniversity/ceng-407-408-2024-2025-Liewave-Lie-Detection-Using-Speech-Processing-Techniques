import torch
import torch.nn as nn
from transformers import Wav2Vec2Model

class LieDetectionModel(nn.Module):
    def __init__(self, pretrained_model_dir, num_classes=2, dropout=0.3):
        super().__init__()

        self.wav2vec2 = Wav2Vec2Model.from_pretrained(pretrained_model_dir)
        self.dropout = nn.Dropout(dropout)
        self.classifier = nn.Linear(self.wav2vec2.config.hidden_size, num_classes)

    def forward(self, input_values, attention_mask=None):
        outputs = self.wav2vec2(input_values, attention_mask=attention_mask)
        pooled = outputs.last_hidden_state.mean(dim=1)
        x = self.dropout(pooled)
        logits = self.classifier(x)
        return logits
    