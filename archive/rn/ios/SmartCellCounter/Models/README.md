# Core ML Models

This directory contains Core ML models for iOS cell segmentation.

## Required Model: UNet256.mlmodel

To enable Core ML segmentation on iOS, place your trained UNet model here:

- **File name**: `UNet256.mlmodel`
- **Input**: 256x256 RGB image
- **Output**: 256x256 single-channel probability map
- **Model type**: Neural network (Core ML format)

### Model Conversion

If you have a TensorFlow or PyTorch model, convert it to Core ML format:

```python
import coremltools as ct

# From TensorFlow
model = ct.convert("path/to/unet_256.h5", 
                   inputs=[ct.ImageType(shape=(1, 256, 256, 3))])

# From PyTorch  
model = ct.convert(torch_model,
                   inputs=[ct.TensorType(shape=(1, 3, 256, 256))])

# Save as .mlmodel
model.save("UNet256.mlmodel")
```

### Fallback Behavior

If no Core ML model is provided:
- iOS will gracefully fall back to OpenCV classical segmentation
- The app will continue to function normally
- Performance may be slightly reduced compared to ML-accelerated segmentation

### Model Performance

Expected performance on iPhone 12 or newer:
- **Core ML UNet**: ~500ms for 256x256 segmentation
- **OpenCV fallback**: ~800ms for classical segmentation
- **Total pipeline**: < 3 seconds end-to-end
