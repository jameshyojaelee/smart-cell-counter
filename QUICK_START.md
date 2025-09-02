# Smart Cell Counter - Quick Start Guide

Get up and running with the Smart Cell Counter app in minutes!

## 🚀 Installation

### Prerequisites
- Node.js 18+ 
- Expo CLI: `npm install -g @expo/cli`
- iOS Simulator or Android Emulator (or physical device)

### Setup
```bash
# 1. Install dependencies
cd smart-cell-counter
yarn install

# 2. Start development server
npx expo start

# 3. Run on device/simulator
yarn ios    # iOS
yarn android # Android
```

## 📱 First Use

### 1. Capture Image
- Open the app and tap "New Analysis"
- Point camera at hemocytometer with good lighting
- Ensure grid is in focus (green status indicators)
- Tap the blue capture button

### 2. Crop & Correct
- App automatically detects grid corners (blue dots)
- If detection fails, manually adjust corner points
- Tap "Proceed" to apply perspective correction

### 3. Review Detections
- AI automatically detects and classifies cells
- Green circles = live cells, Red circles = dead cells
- Tap cells to toggle live/dead classification
- Select which squares to include in count

### 4. View Results
- See concentration, viability, and statistics
- Add notes about the sample
- Save to history or share results

## ⚙️ Key Settings

Navigate to Settings to adjust:

**Processing Parameters:**
- Block Size: 51 (increase for larger cells)
- Threshold Constant: -2 (adjust for different staining)
- Cell Area: 50-5000 μm² (size filtering)

**Viability Thresholds:**
- Blue Hue: 200-260° (trypan blue detection)
- Saturation: 0.3 minimum (dead cell threshold)

## 🔬 Best Practices

### Sample Preparation
1. Mix 1:1 with 0.4% trypan blue
2. Wait 2-5 minutes for staining
3. Load 10-15 μL into hemocytometer
4. Let cells settle for 2-3 minutes

### Image Capture
- Use bright, even lighting
- Ensure hemocytometer is clean
- Focus on grid lines
- Avoid glare and reflections
- Hold camera steady

### Optimal Cell Density
- Target: 50-200 cells per large square
- Too crowded (>300): Dilute sample
- Too sparse (<10): Concentrate sample

## 📊 Understanding Results

**Concentration Formula:**
```
cells/mL = Average count per square × 10⁴ × Dilution factor
```

**Viability Formula:**
```
Viability % = (Live cells / Total cells) × 100
```

**Quality Indicators:**
- ✅ Green: Good quality, reliable results
- ⚠️ Yellow: Acceptable with cautions
- ❌ Red: Poor quality, consider retaking

## 🚨 Troubleshooting

**Grid not detected:**
- Improve lighting and focus
- Clean hemocytometer surface
- Use manual corner adjustment

**Poor cell detection:**
- Check sample preparation
- Adjust threshold settings
- Ensure proper staining

**High variance between squares:**
- Mix sample more thoroughly
- Check for debris or air bubbles
- Consider sample quality

## 📤 Export Options

**CSV Export:**
- Summary data for spreadsheet analysis
- Optional individual cell data
- Compatible with Excel, R, Python

**PDF Report:**
- Professional analysis report
- Includes images and statistics
- Ready for documentation

**Sharing:**
- Email results directly
- Save to Files app
- Compatible with cloud storage

## 🧪 Test with Mock Data

The app includes mock detection for testing:

1. Import any image from gallery
2. App will simulate cell detection
3. Practice the workflow without real samples
4. Perfect for training and demonstrations

## 📞 Need Help?

- **In-app Help:** Tap Help button for detailed tutorials
- **Issues:** Check GitHub Issues for common problems
- **Email:** support@smartcellcounter.com

## 🎯 Pro Tips

1. **Batch Processing:** Process multiple samples, then export all at once
2. **Custom Settings:** Save different parameter sets for different cell types  
3. **Quality Control:** Always check focus and glare indicators before capturing
4. **Backup Data:** Regularly export your sample history
5. **Validation:** Compare results with manual counts initially

---

**Happy Counting! 🔬✨**

Ready to analyze your first sample? Open the app and tap "New Analysis" to get started!
