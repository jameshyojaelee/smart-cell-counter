/**
 * Crop Screen - Grid detection and perspective correction with advanced corner editor
 */
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import { useAppStore } from '../src/state/store';
import { cvNativeAdapter } from '../src/imaging/cvNativeAdapter';
import { logUserInteraction, logError } from '../src/utils/logger';
import { CornerEditor, Corner } from '../src/components/CornerEditor';

export default function CropScreen(): JSX.Element {
  const [isProcessing, setIsProcessing] = useState(false);
  const [gridDetected, setGridDetected] = useState(false);
  const [corners, setCorners] = useState<Corner[]>([]);
  const [showEditor, setShowEditor] = useState(false);

  const {
    originalImageUri,
    correctedImageUri,
    setImageUris,
    currentSample,
    updateCurrentSample,
    setProcessingState,
    setPixelsPerMicron,
    setLastGridCorners,
    settings,
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
        setPixelsPerMicron(result.pixelsPerMicron || null);
        setLastGridCorners(result.corners);

        // Show the corner editor for manual adjustment
        setShowEditor(true);
      } else {
        setGridDetected(false);
        // Enable manual mode and show editor
        enableManualMode();
        setShowEditor(true);
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
      { x: 150, y: 120 },  // Top-left
      { x: 550, y: 120 },  // Top-right
      { x: 550, y: 420 },  // Bottom-right
      { x: 150, y: 420 }   // Bottom-left
    ];
    setCorners(defaultCorners);
    setGridDetected(true);
    logUserInteraction('Crop', 'EnableManualMode');
  };

  const performPerspectiveCorrection = async (
    correctionCorners: Corner[]
  ): Promise<void> => {
    if (!originalImageUri) return;

    setIsProcessing(true);
    setProcessingState({
      isProcessing: true,
      currentStep: 'Applying perspective correction...',
      progress: 0.7,
    });

    try {
      const correctedUri = await cvNativeAdapter.perspectiveCorrect(
        originalImageUri,
        correctionCorners as [Corner, Corner, Corner, Corner]
      );
      
      setImageUris({ corrected: correctedUri });
      
      Alert.alert(
        'Correction Complete',
        'Image has been perspective-corrected. Proceed to cell detection?',
        [
          { text: 'Adjust Again', style: 'cancel', onPress: () => setShowEditor(true) },
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
          <Text style={styles.errorText}>Please go back and import an image first.</Text>
          <TouchableOpacity style={styles.errorButton} onPress={() => router.back()}>
            <Text style={styles.errorButtonText}>Go Back</Text>
          </TouchableOpacity>
        </View>
      </SafeAreaView>
    );
  }

  // Show CornerEditor when grid is detected
  if (showEditor && originalImageUri) {
    return (
      <CornerEditor
        imageUri={correctedImageUri || originalImageUri}
        initialCorners={corners}
        largeHandles={settings?.largeHandles || false}
        onChange={(newCorners) => {
          setCorners(newCorners);
          setLastGridCorners(newCorners);
        }}
        onConfirm={(finalCorners) => {
          setCorners(finalCorners);
          setLastGridCorners(finalCorners);
          setShowEditor(false);
          performPerspectiveCorrection(finalCorners);
        }}
        onCancel={() => {
          setShowEditor(false);
          router.back();
        }}
        onAutoDetect={() => {
          setShowEditor(false);
          detectGrid();
        }}
      />
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      {/* Loading state for grid detection */}
      {isProcessing ? (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color="#007AFF" />
          <Text style={styles.loadingTitle}>Detecting Grid</Text>
          <Text style={styles.loadingText}>Analyzing hemocytometer structure...</Text>
        </View>
      ) : (
        <View style={styles.previewContainer}>
          <Image
            source={{ uri: correctedImageUri || originalImageUri }}
            style={styles.previewImage}
          />
          <View style={styles.previewOverlay}>
            <Ionicons name="scan" size={64} color="#007AFF" />
            <Text style={styles.previewTitle}>Grid Detection</Text>
            <Text style={styles.previewText}>
              {gridDetected ? 'Grid detected! Opening editor...' : 'Detecting hemocytometer grid...'}
            </Text>
          </View>
        </View>
      )}

      {/* Quick Actions */}
      <View style={styles.quickActions}>
        <TouchableOpacity style={styles.quickActionButton} onPress={handleRetake}>
          <Ionicons name="camera" size={24} color="#007AFF" />
          <Text style={styles.quickActionText}>Retake</Text>
        </TouchableOpacity>
        
        <TouchableOpacity style={styles.quickActionButton} onPress={() => {
          enableManualMode();
          setShowEditor(true);
        }}>
          <Ionicons name="create" size={24} color="#FF9500" />
          <Text style={styles.quickActionText}>Manual</Text>
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
    padding: 40,
  },
  errorTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#FF3B30',
    marginTop: 20,
    marginBottom: 12,
  },
  errorText: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
    lineHeight: 24,
    marginBottom: 30,
  },
  errorButton: {
    backgroundColor: '#007AFF',
    borderRadius: 12,
    paddingVertical: 16,
    paddingHorizontal: 32,
  },
  errorButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  loadingContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 40,
  },
  loadingTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#333',
    marginTop: 20,
    marginBottom: 8,
  },
  loadingText: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
  },
  previewContainer: {
    flex: 1,
    margin: 20,
    borderRadius: 12,
    overflow: 'hidden',
    backgroundColor: '#000',
    position: 'relative',
  },
  previewImage: {
    width: '100%',
    height: '100%',
    opacity: 0.7,
  },
  previewOverlay: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(0, 0, 0, 0.3)',
  },
  previewTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#fff',
    marginTop: 16,
    marginBottom: 8,
  },
  previewText: {
    fontSize: 16,
    color: '#fff',
    textAlign: 'center',
    opacity: 0.9,
  },
  quickActions: {
    flexDirection: 'row',
    paddingHorizontal: 20,
    paddingVertical: 16,
    backgroundColor: '#fff',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    gap: 16,
  },
  quickActionButton: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#f0f0f0',
    borderRadius: 12,
    paddingVertical: 20,
  },
  quickActionText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#333',
    marginTop: 8,
  },
});
