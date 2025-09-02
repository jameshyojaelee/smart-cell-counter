/**
 * Capture Screen - Camera interface for taking hemocytometer images
 */
import React, { useState, useRef, useEffect } from 'react';
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
import { Camera, CameraType, FlashMode } from 'expo-camera';
import * as ImagePicker from 'expo-image-picker';
import { Ionicons } from '@expo/vector-icons';
import { useAppStore } from '../src/state/store';
import { cvNative } from '../src/imaging/cvNative';
import { generateCaptureGuidance } from '../src/imaging/qc';
import { logUserInteraction, logError } from '../src/utils/logger';

export default function CaptureScreen(): JSX.Element {
  const cameraRef = useRef<Camera>(null);
  const [cameraType, setCameraType] = useState(CameraType.back);
  const [flashMode, setFlashMode] = useState(FlashMode.off);
  const [isCapturing, setIsCapturing] = useState(false);
  const [focusScore, setFocusScore] = useState(0);
  const [glareRatio, setGlareRatio] = useState(0);
  
  const {
    camera,
    setCameraState,
    setImageUris,
    updateCurrentSample,
    settings,
  } = useAppStore();

  useEffect(() => {
    requestCameraPermissions();
  }, []);

  const requestCameraPermissions = async (): Promise<void> => {
    try {
      const { status } = await Camera.requestCameraPermissionsAsync();
      setCameraState({ hasPermission: status === 'granted' });
      
      if (status !== 'granted') {
        Alert.alert(
          'Camera Permission',
          'Camera access is required to capture hemocytometer images.',
          [{ text: 'OK' }]
        );
      }
    } catch (error) {
      logError('Camera', error as Error, { context: 'requestPermissions' });
    }
  };

  const handleCameraReady = (): void => {
    setCameraState({ isReady: true });
    logUserInteraction('Capture', 'CameraReady');
  };

  const toggleFlash = (): void => {
    const newFlashMode = flashMode === FlashMode.off ? FlashMode.on : FlashMode.off;
    setFlashMode(newFlashMode);
    setCameraState({ flashMode: newFlashMode });
    logUserInteraction('Capture', 'ToggleFlash', { flashMode: newFlashMode });
  };

  const toggleCameraType = (): void => {
    const newType = cameraType === CameraType.back ? CameraType.front : CameraType.back;
    setCameraType(newType);
    logUserInteraction('Capture', 'ToggleCameraType', { cameraType: newType });
  };

  const handleCapture = async (): Promise<void> => {
    if (!cameraRef.current || isCapturing) return;

    setIsCapturing(true);
    logUserInteraction('Capture', 'TakePicture');

    try {
      const photo = await cameraRef.current.takePictureAsync({
        quality: 0.8,
        base64: false,
        skipProcessing: false,
      });

      if (photo?.uri) {
        // Update current sample with image
        updateCurrentSample({
          id: `sample_${Date.now()}`,
          timestamp: Date.now(),
          imagePath: photo.uri,
          operator: settings.defaultOperator,
          project: settings.defaultProject,
          chamberType: settings.defaultChamberType,
          stainType: settings.defaultStainType,
          dilutionFactor: settings.defaultDilutionFactor,
        });

        setImageUris({ original: photo.uri });
        
        // Navigate to crop screen
        router.push('/crop');
      }
    } catch (error) {
      logError('Capture', error as Error, { context: 'takePicture' });
      Alert.alert('Capture Error', 'Failed to capture image. Please try again.');
    } finally {
      setIsCapturing(false);
    }
  };

  const handleImportFromGallery = async (): Promise<void> => {
    logUserInteraction('Capture', 'ImportFromGallery');

    try {
      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ImagePicker.MediaTypeOptions.Images,
        allowsEditing: false,
        quality: 0.8,
        aspect: [4, 3],
      });

      if (!result.canceled && result.assets[0]) {
        const asset = result.assets[0];
        
        updateCurrentSample({
          id: `sample_${Date.now()}`,
          timestamp: Date.now(),
          imagePath: asset.uri,
          operator: settings.defaultOperator,
          project: settings.defaultProject,
          chamberType: settings.defaultChamberType,
          stainType: settings.defaultStainType,
          dilutionFactor: settings.defaultDilutionFactor,
        });

        setImageUris({ original: asset.uri });
        router.push('/crop');
      }
    } catch (error) {
      logError('Capture', error as Error, { context: 'importFromGallery' });
      Alert.alert('Import Error', 'Failed to import image from gallery.');
    }
  };

  const handleFocusLock = async (): Promise<void> => {
    // Mock focus lock functionality
    setCameraState({ exposureLocked: !camera.exposureLocked });
    logUserInteraction('Capture', 'ToggleFocusLock');
  };

  // Generate guidance based on current conditions
  const guidance = generateCaptureGuidance(
    focusScore,
    glareRatio,
    settings.qcThresholds
  );

  if (!camera.hasPermission) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.permissionContainer}>
          <Ionicons name="camera-off" size={64} color="#666" />
          <Text style={styles.permissionTitle}>Camera Permission Required</Text>
          <Text style={styles.permissionText}>
            Please grant camera access to capture hemocytometer images.
          </Text>
          <TouchableOpacity
            style={styles.permissionButton}
            onPress={requestCameraPermissions}
          >
            <Text style={styles.permissionButtonText}>Grant Permission</Text>
          </TouchableOpacity>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.cameraContainer}>
        <Camera
          ref={cameraRef}
          style={styles.camera}
          type={cameraType}
          flashMode={flashMode}
          onCameraReady={handleCameraReady}
          autoFocus={Camera.Constants.AutoFocus.on}
        >
          {/* Grid Overlay */}
          <View style={styles.gridOverlay}>
            <View style={styles.gridLine} />
            <View style={[styles.gridLine, styles.gridLineVertical]} />
            <View style={[styles.gridLine, styles.gridLineHorizontal]} />
            <View style={[styles.gridLine, styles.gridLineVertical, styles.gridLineRight]} />
          </View>

          {/* Status Indicators */}
          <View style={styles.statusContainer}>
            <View style={[
              styles.statusChip,
              focusScore >= settings.qcThresholds.minFocusScore ? styles.statusGood : styles.statusBad
            ]}>
              <Ionicons
                name={focusScore >= settings.qcThresholds.minFocusScore ? 'checkmark' : 'warning'}
                size={16}
                color="#fff"
              />
              <Text style={styles.statusText}>Focus</Text>
            </View>

            <View style={[
              styles.statusChip,
              glareRatio <= settings.qcThresholds.maxGlareRatio ? styles.statusGood : styles.statusBad
            ]}>
              <Ionicons
                name={glareRatio <= settings.qcThresholds.maxGlareRatio ? 'checkmark' : 'warning'}
                size={16}
                color="#fff"
              />
              <Text style={styles.statusText}>Glare</Text>
            </View>
          </View>

          {/* Guidance Text */}
          {guidance.warnings.length > 0 && (
            <View style={styles.guidanceContainer}>
              {guidance.warnings.map((warning, index) => (
                <View key={index} style={styles.warningChip}>
                  <Ionicons name="warning" size={14} color="#FF3B30" />
                  <Text style={styles.warningText}>{warning}</Text>
                </View>
              ))}
            </View>
          )}
        </Camera>
      </View>

      {/* Controls */}
      <View style={styles.controlsContainer}>
        {/* Top Controls */}
        <View style={styles.topControls}>
          <TouchableOpacity style={styles.controlButton} onPress={toggleFlash}>
            <Ionicons
              name={flashMode === FlashMode.on ? 'flash' : 'flash-off'}
              size={24}
              color={flashMode === FlashMode.on ? '#FFD60A' : '#666'}
            />
          </TouchableOpacity>

          <TouchableOpacity style={styles.controlButton} onPress={handleFocusLock}>
            <Ionicons
              name={camera.exposureLocked ? 'lock-closed' : 'lock-open'}
              size={24}
              color={camera.exposureLocked ? '#007AFF' : '#666'}
            />
          </TouchableOpacity>

          <TouchableOpacity style={styles.controlButton} onPress={toggleCameraType}>
            <Ionicons name="camera-reverse" size={24} color="#666" />
          </TouchableOpacity>
        </View>

        {/* Guidance */}
        <View style={styles.guidanceTextContainer}>
          {guidance.guidance.map((tip, index) => (
            <Text key={index} style={styles.guidanceText}>
              • {tip}
            </Text>
          ))}
        </View>

        {/* Bottom Controls */}
        <View style={styles.bottomControls}>
          <TouchableOpacity
            style={styles.importButton}
            onPress={handleImportFromGallery}
          >
            <Ionicons name="images" size={24} color="#007AFF" />
            <Text style={styles.importButtonText}>Gallery</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[
              styles.captureButton,
              (!guidance.canCapture || isCapturing) && styles.captureButtonDisabled
            ]}
            onPress={handleCapture}
            disabled={!guidance.canCapture || isCapturing}
          >
            {isCapturing ? (
              <ActivityIndicator size="large" color="#fff" />
            ) : (
              <View style={styles.captureButtonInner} />
            )}
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.settingsButton}
            onPress={() => router.push('/settings')}
          >
            <Ionicons name="settings" size={24} color="#666" />
            <Text style={styles.settingsButtonText}>Settings</Text>
          </TouchableOpacity>
        </View>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  permissionContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 20,
    backgroundColor: '#f8f9fa',
  },
  permissionTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginTop: 20,
    textAlign: 'center',
  },
  permissionText: {
    fontSize: 16,
    color: '#666',
    marginTop: 10,
    textAlign: 'center',
    lineHeight: 24,
  },
  permissionButton: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
    marginTop: 20,
  },
  permissionButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  cameraContainer: {
    flex: 1,
  },
  camera: {
    flex: 1,
  },
  gridOverlay: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'center',
    alignItems: 'center',
  },
  gridLine: {
    position: 'absolute',
    backgroundColor: 'rgba(255, 255, 255, 0.3)',
  },
  gridLineVertical: {
    width: 1,
    height: '60%',
  },
  gridLineHorizontal: {
    width: '60%',
    height: 1,
  },
  gridLineRight: {
    left: '60%',
  },
  statusContainer: {
    position: 'absolute',
    top: 20,
    left: 20,
    flexDirection: 'row',
  },
  statusChip: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
    marginRight: 8,
  },
  statusGood: {
    backgroundColor: '#34C759',
  },
  statusBad: {
    backgroundColor: '#FF3B30',
  },
  statusText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
    marginLeft: 4,
  },
  guidanceContainer: {
    position: 'absolute',
    top: 80,
    left: 20,
    right: 20,
  },
  warningChip: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255, 255, 255, 0.9)',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 8,
    marginBottom: 8,
  },
  warningText: {
    color: '#FF3B30',
    fontSize: 14,
    fontWeight: '500',
    marginLeft: 6,
    flex: 1,
  },
  controlsContainer: {
    backgroundColor: '#fff',
    paddingTop: 20,
  },
  topControls: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingHorizontal: 40,
    marginBottom: 20,
  },
  controlButton: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: '#f0f0f0',
    alignItems: 'center',
    justifyContent: 'center',
  },
  guidanceTextContainer: {
    paddingHorizontal: 20,
    marginBottom: 20,
  },
  guidanceText: {
    fontSize: 14,
    color: '#666',
    lineHeight: 20,
    marginBottom: 4,
  },
  bottomControls: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 40,
    paddingBottom: 40,
  },
  importButton: {
    alignItems: 'center',
    justifyContent: 'center',
    width: 80,
  },
  importButtonText: {
    fontSize: 12,
    color: '#007AFF',
    marginTop: 4,
  },
  captureButton: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: '#007AFF',
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.2,
    shadowRadius: 4,
  },
  captureButtonDisabled: {
    backgroundColor: '#ccc',
    elevation: 0,
    shadowOpacity: 0,
  },
  captureButtonInner: {
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: '#fff',
  },
  settingsButton: {
    alignItems: 'center',
    justifyContent: 'center',
    width: 80,
  },
  settingsButtonText: {
    fontSize: 12,
    color: '#666',
    marginTop: 4,
  },
});
