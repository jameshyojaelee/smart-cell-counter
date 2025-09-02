/**
 * Crop Screen - Grid detection and perspective correction
 */
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Alert,
  ActivityIndicator,
  Dimensions,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import { useAppStore } from '../src/state/store';
import { cvNativeAdapter } from '../src/imaging/cvNativeAdapter';
import { logUserInteraction, logError } from '../src/utils/logger';

const { width: screenWidth, height: screenHeight } = Dimensions.get('window');

export default function CropScreen(): JSX.Element {
  const [isProcessing, setIsProcessing] = useState(false);
  const [gridDetected, setGridDetected] = useState(false);
  const [corners, setCorners] = useState<Array<{ x: number; y: number }>>([]);
  const [imageSize, setImageSize] = useState({ width: 0, height: 0 });

  const {
    originalImageUri,
    correctedImageUri,
    setImageUris,
    currentSample,
    updateCurrentSample,
    setProcessingState,
  } = useAppStore();

  useEffect(() => {
    if (originalImageUri && !correctedImageUri) {
      detectGrid();
    }
  }, [originalImageUri]);

  const detectGrid = async (): Promise<void> => {
    if (!originalImageUri) {
      Alert.alert('Error', 'No image to process');
      return;
    }

    setIsProcessing(true);
    setProcessingState({ isProcessing: true, currentStep: 'Detecting grid...', progress: 0.3 });
    logUserInteraction('Crop', 'DetectGrid');

    try {
      const result = await cvNativeAdapter.detectGridAndCorners(originalImageUri);
      
      if (result.corners && result.corners.length === 4) {
        setCorners(result.corners);
        setGridDetected(true);
        
        updateCurrentSample({
          focusScore: result.focusScore,
          glareRatio: result.glareRatio,
          chamberType: result.gridType || 'neubauer',
        });

        // Automatically proceed with perspective correction
        await performPerspectiveCorrection(result.corners);
      } else {
        setGridDetected(false);
        Alert.alert(
          'Grid Not Detected',
          'Could not automatically detect the hemocytometer grid. Please manually adjust the corners.',
          [
            { text: 'Manual Adjustment', onPress: enableManualMode },
            { text: 'Retake Photo', onPress: () => router.back() },
          ]
        );
      }
    } catch (error) {
      logError('Crop', error as Error, { context: 'detectGrid' });
      Alert.alert('Detection Error', 'Failed to detect grid. Please try again.');
    } finally {
      setIsProcessing(false);
      setProcessingState({ isProcessing: false, currentStep: '', progress: 0 });
    }
  };

  const enableManualMode = (): void => {
    // Set default corners for manual adjustment
    const defaultCorners = [
      { x: imageSize.width * 0.1, y: imageSize.height * 0.1 },
      { x: imageSize.width * 0.9, y: imageSize.height * 0.1 },
      { x: imageSize.width * 0.9, y: imageSize.height * 0.9 },
      { x: imageSize.width * 0.1, y: imageSize.height * 0.9 },
    ];
    setCorners(defaultCorners);
    setGridDetected(false);
    logUserInteraction('Crop', 'EnableManualMode');
  };

  const performPerspectiveCorrection = async (
    correctionCorners: Array<{ x: number; y: number }>
  ): Promise<void> => {
    if (!originalImageUri) return;

    setIsProcessing(true);
    setProcessingState({
      isProcessing: true,
      currentStep: 'Correcting perspective...',
      progress: 0.7,
    });

    try {
      const correctedUri = await cvNativeAdapter.perspectiveCorrect(
        originalImageUri,
        correctionCorners as [any, any, any, any]
      );
      
      setImageUris({ corrected: correctedUri });
      
      Alert.alert(
        'Correction Complete',
        'Image has been perspective-corrected. Proceed to cell detection?',
        [
          { text: 'Adjust Again', style: 'cancel' },
          {
            text: 'Proceed',
            onPress: () => router.push('/review'),
          },
        ]
      );
    } catch (error) {
      logError('Crop', error as Error, { context: 'perspectiveCorrection' });
      Alert.alert('Correction Error', 'Failed to correct perspective. Please try again.');
    } finally {
      setIsProcessing(false);
      setProcessingState({ isProcessing: false, currentStep: '', progress: 0 });
    }
  };

  const handleProceed = (): void => {
    if (corners.length === 4) {
      performPerspectiveCorrection(corners);
    } else {
      Alert.alert('Invalid Selection', 'Please ensure all four corners are selected.');
    }
  };

  const handleRetake = (): void => {
    logUserInteraction('Crop', 'RetakePhoto');
    router.back();
  };

  if (!originalImageUri) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.errorContainer}>
          <Ionicons name="alert-circle" size={64} color="#FF3B30" />
          <Text style={styles.errorTitle}>No Image Found</Text>
          <Text style={styles.errorText}>Please go back and capture an image first.</Text>
          <TouchableOpacity style={styles.errorButton} onPress={() => router.back()}>
            <Text style={styles.errorButtonText}>Go Back</Text>
          </TouchableOpacity>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.imageContainer}>
        <Image
          source={{ uri: correctedImageUri || originalImageUri }}
          style={styles.image}
          onLoad={(event) => {
            const { width, height } = event.source;
            setImageSize({ width, height });
          }}
        />
        
        {/* Corner Overlay */}
        {corners.length === 4 && (
          <View style={styles.cornerOverlay}>
            {corners.map((corner, index) => (
              <View
                key={index}
                style={[
                  styles.corner,
                  {
                    left: (corner.x / imageSize.width) * screenWidth - 10,
                    top: (corner.y / imageSize.height) * (screenHeight * 0.6) - 10,
                  },
                ]}
              >
                <View style={styles.cornerInner} />
              </View>
            ))}
            
            {/* Grid Lines */}
            <View style={styles.gridLines}>
              <View style={[styles.gridLine, styles.topLine]} />
              <View style={[styles.gridLine, styles.rightLine]} />
              <View style={[styles.gridLine, styles.bottomLine]} />
              <View style={[styles.gridLine, styles.leftLine]} />
            </View>
          </View>
        )}
        
        {/* Loading Overlay */}
        {isProcessing && (
          <View style={styles.loadingOverlay}>
            <ActivityIndicator size="large" color="#007AFF" />
            <Text style={styles.loadingText}>Processing...</Text>
          </View>
        )}
      </View>

      {/* Status */}
      <View style={styles.statusContainer}>
        <View style={[
          styles.statusChip,
          gridDetected ? styles.statusGood : styles.statusWarning
        ]}>
          <Ionicons
            name={gridDetected ? 'checkmark-circle' : 'warning'}
            size={20}
            color="#fff"
          />
          <Text style={styles.statusText}>
            {gridDetected ? 'Grid Detected' : 'Manual Adjustment'}
          </Text>
        </View>
      </View>

      {/* Instructions */}
      <View style={styles.instructionsContainer}>
        <Text style={styles.instructionsTitle}>
          {gridDetected ? 'Grid Detection Complete' : 'Manual Corner Adjustment'}
        </Text>
        <Text style={styles.instructionsText}>
          {gridDetected
            ? 'The hemocytometer grid has been automatically detected. You can proceed to cell detection or adjust the corners manually.'
            : 'Drag the corner points to match the hemocytometer grid boundaries. Ensure all four corners are positioned accurately.'
          }
        </Text>
      </View>

      {/* Controls */}
      <View style={styles.controlsContainer}>
        <TouchableOpacity style={styles.secondaryButton} onPress={handleRetake}>
          <Ionicons name="camera" size={20} color="#666" />
          <Text style={styles.secondaryButtonText}>Retake</Text>
        </TouchableOpacity>

        {!gridDetected && (
          <TouchableOpacity style={styles.secondaryButton} onPress={detectGrid}>
            <Ionicons name="scan" size={20} color="#007AFF" />
            <Text style={[styles.secondaryButtonText, { color: '#007AFF' }]}>
              Auto Detect
            </Text>
          </TouchableOpacity>
        )}

        <TouchableOpacity
          style={[styles.primaryButton, isProcessing && styles.primaryButtonDisabled]}
          onPress={handleProceed}
          disabled={isProcessing || corners.length !== 4}
        >
          {isProcessing ? (
            <ActivityIndicator size="small" color="#fff" />
          ) : (
            <>
              <Text style={styles.primaryButtonText}>Proceed</Text>
              <Ionicons name="arrow-forward" size={20} color="#fff" />
            </>
          )}
        </TouchableOpacity>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f9fa',
  },
  errorContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 20,
  },
  errorTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginTop: 20,
  },
  errorText: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
    marginTop: 10,
  },
  errorButton: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
    marginTop: 20,
  },
  errorButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  imageContainer: {
    flex: 1,
    margin: 20,
    borderRadius: 12,
    overflow: 'hidden',
    backgroundColor: '#000',
    elevation: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
  },
  image: {
    flex: 1,
    width: '100%',
  },
  cornerOverlay: {
    ...StyleSheet.absoluteFillObject,
  },
  corner: {
    position: 'absolute',
    width: 20,
    height: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cornerInner: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: '#007AFF',
    borderWidth: 2,
    borderColor: '#fff',
  },
  gridLines: {
    ...StyleSheet.absoluteFillObject,
  },
  gridLine: {
    position: 'absolute',
    backgroundColor: 'rgba(0, 122, 255, 0.6)',
  },
  topLine: {
    top: 0,
    left: 0,
    right: 0,
    height: 2,
  },
  rightLine: {
    top: 0,
    right: 0,
    bottom: 0,
    width: 2,
  },
  bottomLine: {
    bottom: 0,
    left: 0,
    right: 0,
    height: 2,
  },
  leftLine: {
    top: 0,
    left: 0,
    bottom: 0,
    width: 2,
  },
  loadingOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0, 0, 0, 0.7)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  loadingText: {
    color: '#fff',
    fontSize: 16,
    marginTop: 12,
  },
  statusContainer: {
    paddingHorizontal: 20,
    marginBottom: 16,
  },
  statusChip: {
    flexDirection: 'row',
    alignItems: 'center',
    alignSelf: 'center',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
  },
  statusGood: {
    backgroundColor: '#34C759',
  },
  statusWarning: {
    backgroundColor: '#FF9500',
  },
  statusText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
    marginLeft: 8,
  },
  instructionsContainer: {
    paddingHorizontal: 20,
    marginBottom: 20,
  },
  instructionsTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 8,
  },
  instructionsText: {
    fontSize: 14,
    color: '#666',
    lineHeight: 20,
  },
  controlsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingBottom: 20,
  },
  secondaryButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 8,
    backgroundColor: '#f0f0f0',
  },
  secondaryButtonText: {
    fontSize: 16,
    color: '#666',
    marginLeft: 8,
  },
  primaryButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
    backgroundColor: '#007AFF',
  },
  primaryButtonDisabled: {
    backgroundColor: '#ccc',
  },
  primaryButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#fff',
    marginRight: 8,
  },
});
