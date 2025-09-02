# Smart Cell Counter

An AI-powered mobile application for accurate hemocytometer cell counting and viability assessment using computer vision and machine learning.

## Features

🔬 **Automated Cell Detection**
- OpenCV-based image processing pipeline
- TensorFlow Lite model for segmentation refinement
- Adaptive thresholding and watershed splitting
- Sub-pixel accuracy cell counting

📱 **Mobile-First Design**
- React Native with Expo Router
- iOS and Android support
- On-device processing (no internet required)
- Intuitive touch interface

🧮 **Accurate Calculations**
- Standard hemocytometer formulas
- Proper inclusion rule implementation
- Outlier detection using MAD statistics
- Dilution factor corrections

🎯 **Viability Assessment**
- Trypan blue stain classification
- HSV color space analysis
- Adaptive thresholds based on image histogram
- Manual correction capabilities

📊 **Data Management**
- SQLite database storage
- CSV and PDF export
- Sample history and search
- Project and operator tracking

⚡ **Quality Control**
- Real-time focus and glare detection
- Overcrowding and undercrowding alerts
- Statistical variance monitoring
- Processing time optimization

## Quick Start

### Prerequisites

- Node.js 18+ and npm/yarn
- Expo CLI (`npm install -g @expo/cli`)
- iOS Simulator or Android Emulator
- Physical device for camera testing

### Installation

```bash
# Clone the repository
git clone https://github.com/your-org/smart-cell-counter.git
cd smart-cell-counter

# Install dependencies
yarn install

# Start the development server
npx expo start

# Run on iOS simulator
yarn ios

# Run on Android emulator
yarn android
```

### Native Module Setup (Required for iOS)

For full functionality on iOS and OpenCV on Android, set up the native modules:

```bash
# Generate native code
npx expo prebuild

# iOS setup with Core ML and Vision
cd ios && pod install && cd ..

# Build with native modules
yarn ios --device
yarn android --variant release
```

#### iOS-Specific Setup

The iOS version uses Apple's Vision framework for grid detection and Core ML for segmentation:

1. **Add Core ML Model** (Optional):
   - Place your UNet256.mlmodel in `ios/SmartCellCounter/Models/`
   - Xcode will automatically compile it to .mlmodelc
   - If no model is provided, the app falls back to OpenCV

2. **Configure Xcode Project**:
   - Open `ios/SmartCellCounter.xcworkspace` in Xcode
   - Set the Swift Compiler bridging header to: `SmartCellCounter/SmartCellCounter-Bridging-Header.h`
   - Ensure deployment target is iOS 15.0 or later
   - Add the Models folder to the Xcode project if using Core ML

3. **Camera Permissions**:
   The app automatically requests camera permissions with these descriptions:
   - Camera: "Camera is used to capture hemocytometer images for cell counting."
   - Photo Library: "Photo library access is used to import images for analysis."
   - Photo Library Add: "The app saves exported images and reports to your library."

4. **Backend Selection Logic**:
   - iOS: Vision → Core ML → OpenCV (fallback chain)
   - Android: OpenCV → TensorFlow Lite (existing path)
   - Processing times: < 3 seconds on iPhone 12 or newer

## Architecture

### Project Structure

```
smart-cell-counter/
├── app/                    # Expo Router screens
│   ├── _layout.tsx        # Root navigation layout
│   ├── index.tsx          # Home screen
│   ├── capture.tsx        # Camera interface
│   ├── crop.tsx           # Grid detection & correction
│   ├── review.tsx         # Detection review & editing
│   ├── results.tsx        # Final results & export
│   ├── history.tsx        # Sample history
│   ├── settings.tsx       # App configuration
│   └── help.tsx           # User guidance
├── src/
│   ├── components/        # Reusable UI components
│   ├── imaging/           # Image processing pipeline
│   │   ├── cvNative.ts    # OpenCV native wrapper (Android)
│   │   ├── iosBridge.ts   # iOS Vision/CoreML bridge
│   │   ├── cvNativeAdapter.ts # Cross-platform adapter
│   │   ├── segmentation.ts # Cell segmentation
│   │   ├── viability.ts   # Viability classification
│   │   ├── counting.ts    # Counting algorithms
│   │   ├── qc.ts          # Quality control
│   │   └── math.ts        # Statistical utilities
│   ├── data/              # Database layer
│   │   ├── db.ts          # SQLite initialization
│   │   └── repositories/  # Data access objects
│   ├── state/             # Zustand store
│   ├── types/             # TypeScript definitions
│   └── utils/             # Utility functions
├── assets/
│   ├── models/            # TensorFlow Lite models
│   └── fixtures/          # Test data
├── ios/                   # iOS native code
│   ├── Podfile           # CocoaPods dependencies
│   └── SmartCellCounter/
│       ├── Info.plist    # iOS app configuration
│       ├── SmartCellCounter-Bridging-Header.h
│       ├── VisionUtils.swift # Grid detection with Vision
│       ├── SegmentationCoreML.swift # Core ML segmentation
│       ├── CellCounterModule.swift # React Native bridge
│       ├── CellCounterModule.m # Objective-C bridge
│       └── Models/       # Core ML models (.mlmodel)
└── __tests__/             # Unit tests
```

### Technology Stack

- **Framework**: React Native + Expo
- **Navigation**: Expo Router (file-based routing)
- **State Management**: Zustand
- **Database**: Expo SQLite
- **Storage**: React Native MMKV
- **Image Processing**: 
  - iOS: Apple Vision + Core Image + Core ML
  - Android: OpenCV (native modules)
- **Machine Learning**: 
  - iOS: Core ML (UNet segmentation)
  - Android: TensorFlow Lite
- **UI Components**: Custom components with Expo Vector Icons
- **Testing**: Jest + React Native Testing Library
- **Type Safety**: TypeScript with strict mode

## Algorithms

### Grid Detection

The app uses platform-optimized computer vision for hemocytometer grid detection:

#### iOS Implementation (Apple Vision)
1. **Vision Framework**: VNDetectRectanglesRequest for robust rectangle detection
2. **Focus Assessment**: Laplacian variance for image sharpness
3. **Glare Detection**: HSV analysis for overexposed regions
4. **Perspective Correction**: Core Image CIFilter.perspectiveCorrection

#### Android Implementation (OpenCV)
1. **Preprocessing**: Convert to grayscale, apply CLAHE enhancement
2. **Edge Detection**: Canny edge detection to find grid lines
3. **Line Detection**: Hough transform to identify dominant orientations
4. **Corner Finding**: Intersection of perpendicular line sets
5. **Validation**: Geometric constraints and aspect ratio checks

```typescript
// Cross-platform grid detection pipeline
const result = await cvNativeAdapter.detectGridAndCorners(imageUri);
if (result.gridType && result.corners.length === 4) {
  // Proceed with perspective correction
  const correctedUri = await cvNativeAdapter.perspectiveCorrect(imageUri, result.corners);
}
```

### Cell Segmentation

Cross-platform segmentation pipeline with ML acceleration:

#### iOS Implementation
1. **Core ML UNet**: 256x256 neural network segmentation (when available)
2. **Fallback Pipeline**: OpenCV classical segmentation if Core ML unavailable
3. **Metal Acceleration**: GPU-accelerated processing via Vision framework

#### Android Implementation  
1. **Background Subtraction**: Gaussian blur background estimation
2. **Adaptive Thresholding**: Local threshold adaptation
3. **Morphological Operations**: Opening to remove noise
4. **Watershed Splitting**: Separate touching cells
5. **TensorFlow Lite**: Optional ML refinement
6. **Contour Analysis**: Size and circularity filtering

```typescript
const segmentationResult = await segmentCells(
  correctedImageUri,
  processingParams,
  pixelsPerMicron
);

// Platform-specific backend selection happens automatically
// iOS: Core ML → OpenCV fallback
// Android: OpenCV → TensorFlow Lite (optional)
```

### Viability Classification

Color-based classification using HSV analysis:

```typescript
function classifyTrypanBlueViability(colorStats: ColorStats): ViabilityResult {
  const { hue, saturation, value } = colorStats;
  
  // Dead cells appear blue (high hue, saturation)
  const isInBlueRange = hue >= 200 && hue <= 260;
  const hasHighSaturation = saturation >= 0.3;
  const hasLowValue = value <= 0.7;
  
  const isDead = isInBlueRange && hasHighSaturation && hasLowValue;
  
  return {
    isLive: !isDead,
    confidence: calculateConfidence(colorStats),
    reason: isDead ? 'Blue staining detected' : 'Live cell'
  };
}
```

### Counting Rules

Implements standard hemocytometer inclusion rules:

```typescript
function applyInclusionRule(detections: DetectionObject[], squareIndex: number): DetectionObject[] {
  return detections.filter(detection => {
    const { x, y } = detection.centroid;
    
    // Include top and left borders, exclude bottom and right
    return x >= left && x < right && y >= top && y < bottom;
  });
}
```

### Concentration Calculation

Standard hemocytometer formula implementation:

```
Concentration (cells/mL) = Average cells per square × 10⁴ × Dilution factor
Viability (%) = (Live cells / Total cells) × 100
```

## Configuration

### Processing Parameters

Adjust segmentation sensitivity in Settings:

- **Block Size**: Adaptive threshold neighborhood (31-101, odd numbers)
- **Threshold Constant (C)**: Offset from mean (-10 to 10)
- **Min/Max Cell Area**: Size filtering in μm² (50-5000)
- **Use Watershed**: Enable touching cell separation
- **TensorFlow Lite Refinement**: ML-based segmentation improvement

### Viability Thresholds

Customize color classification:

- **Hue Range**: Blue color detection (200-260°)
- **Saturation Minimum**: Dead cell saturation threshold (0.3)
- **Value Maximum**: Dead cell brightness threshold (0.7)

### Quality Control

Set quality thresholds:

- **Min Focus Score**: Laplacian variance threshold (100)
- **Max Glare Ratio**: Percentage of overexposed pixels (0.1)
- **Cell Density Limits**: Min/max cells per square (10-300)
- **Variance Threshold**: MAD-based outlier detection (2.5)

## Data Export

### CSV Format

The app exports data in multiple CSV formats:

1. **Summary CSV**: One row per sample with key metrics
2. **Square Counts CSV**: Per-square statistics
3. **Detections CSV**: Individual cell data (optional)

Example summary CSV:
```csv
Sample ID,Timestamp,Operator,Concentration (cells/mL),Viability (%),Live Cells,Dead Cells
sample_001,2024-01-15T10:30:00Z,Dr. Smith,2.5e6,85.2,170,30
```

### PDF Reports

Professional reports include:
- Sample metadata and processing parameters
- Statistical summary with confidence intervals
- Quality control alerts and recommendations
- Formulas and calculation details
- Optional image overlays

## Testing

### Unit Tests

Run the test suite:

```bash
# Run all tests
yarn test

# Run with coverage
yarn test --coverage

# Run specific test file
yarn test src/imaging/__tests__/counting.test.ts

# Watch mode for development
yarn test --watch
```

### Test Coverage

The app includes comprehensive tests for:

- Mathematical utilities (statistics, outlier detection)
- Counting algorithms (inclusion rules, concentration calculations)
- Data validation and export functions
- Component rendering and interactions

### Integration Testing

Use the provided fixture images to validate the complete pipeline:

```bash
# Run integration tests with fixture data
yarn test:integration
```

## Performance

### Optimization Targets

- **End-to-end processing**: < 3 seconds for 1080p images
- **Memory usage**: < 200MB during processing
- **Battery efficiency**: Optimized for mobile devices
- **Offline capability**: No internet connection required

### Performance Monitoring

The app includes built-in performance logging:

```typescript
import { logger } from '@/utils/logger';

// Automatic timing for async operations
const result = await logger.timeOperation('segmentation', async () => {
  return await segmentCells(imageUri, params);
});

// View performance statistics
const stats = logger.getPerformanceStats('segmentation');
console.log(`Average duration: ${stats.averageDuration}ms`);
```

## Deployment

### Building for Production

```bash
# Create production builds
npx expo build:ios
npx expo build:android

# Using EAS Build (recommended)
eas build --platform ios
eas build --platform android
```

### App Store Distribution

1. Configure app metadata in `app.json`
2. Set up signing certificates
3. Build release versions
4. Submit to App Store/Play Store using EAS Submit

## Contributing

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make changes and add tests
4. Run the test suite (`yarn test`)
5. Commit changes (`git commit -m 'Add amazing feature'`)
6. Push to branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Code Style

The project uses ESLint and Prettier with TypeScript strict mode:

```bash
# Check code style
yarn lint

# Format code
yarn format

# Type checking
yarn type-check
```

### Adding New Features

When adding new functionality:

1. Update TypeScript interfaces in `src/types/`
2. Add unit tests for new algorithms
3. Update the Help screen with usage instructions
4. Consider performance implications
5. Test on both iOS and Android

## Troubleshooting

### Common Issues

**Camera not working:**
- Ensure camera permissions are granted
- Test on physical device (camera doesn't work in simulator)
- Check for proper lighting conditions

**Grid detection fails:**
- Improve image focus and lighting
- Clean hemocytometer surface
- Use manual corner adjustment mode

**Poor cell detection:**
- Verify sample preparation and staining
- Adjust processing parameters in Settings
- Check cell density (avoid overcrowding)

**Export failures:**
- Ensure sufficient device storage
- Check file permissions
- Verify sharing app is installed

### Debug Mode

Enable detailed logging in development:

```typescript
// View processing logs
import { logger } from '@/utils/logger';
console.log(logger.exportLogs());

// Performance metrics
const metrics = logger.getPerformanceStats();
console.log(metrics);
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- OpenCV community for computer vision algorithms
- TensorFlow team for mobile ML framework
- Expo team for React Native development tools
- Research collaborators for validation data

## Citation

If you use this app in research, please cite:

```bibtex
@software{smart_cell_counter_2024,
  title = {Smart Cell Counter: AI-Powered Hemocytometer Analysis},
  author = {Your Name},
  year = {2024},
  url = {https://github.com/your-org/smart-cell-counter},
  version = {1.0.0}
}
```

## Support

- 📧 Email: support@smartcellcounter.com
- 🐛 Issues: [GitHub Issues](https://github.com/your-org/smart-cell-counter/issues)
- 📖 Documentation: [Wiki](https://github.com/your-org/smart-cell-counter/wiki)
- 💬 Discussions: [GitHub Discussions](https://github.com/your-org/smart-cell-counter/discussions)
