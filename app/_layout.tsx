/**
 * Root layout for the Smart Cell Counter app
 */
import { useEffect, useState } from 'react';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { initializeDatabase } from '../src/data/db';
import { logger } from '../src/utils/logger';
import { useAppStore } from '../src/state/store';
import { consentService } from '../src/privacy/consent';
import ConsentScreen from './consent';

export default function RootLayout(): JSX.Element {
  const [showConsent, setShowConsent] = useState(false);
  const [isInitialized, setIsInitialized] = useState(false);
  const initializePurchases = useAppStore((state) => state.initializePurchases);

  useEffect(() => {
    // Initialize database and monetization on app start
    const initializeApp = async (): Promise<void> => {
      try {
        logger.info('App', 'Initializing Smart Cell Counter');
        
        // Initialize database
        await initializeDatabase();
        logger.info('App', 'Database initialized successfully');
        
        // Check if we need to show consent screen
        if (consentService.shouldShowConsentScreen()) {
          setShowConsent(true);
        } else {
          // Initialize monetization if consent already given
          await initializePurchases();
        }
        
        setIsInitialized(true);
      } catch (error) {
        logger.error('App', 'Failed to initialize app', error);
        setIsInitialized(true); // Continue anyway
      }
    };

    initializeApp();
  }, [initializePurchases]);

  // Show consent screen if needed
  if (showConsent && isInitialized) {
    return <ConsentScreen />;
  }

  // Show loading or nothing while initializing
  if (!isInitialized) {
    return <></>;
  }

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <Stack
          screenOptions={{
            headerStyle: {
              backgroundColor: '#007AFF',
            },
            headerTintColor: '#fff',
            headerTitleStyle: {
              fontWeight: 'bold',
            },
            animation: 'slide_from_right',
          }}
        >
          <Stack.Screen
            name="index"
            options={{
              title: 'Smart Cell Counter',
              headerShown: false,
            }}
          />
          <Stack.Screen
            name="capture"
            options={{
              title: 'Capture Image',
              headerBackTitle: 'Back',
            }}
          />
          <Stack.Screen
            name="crop"
            options={{
              title: 'Crop & Correct',
              headerBackTitle: 'Back',
            }}
          />
          <Stack.Screen
            name="review"
            options={{
              title: 'Review Detections',
              headerBackTitle: 'Back',
            }}
          />
          <Stack.Screen
            name="results"
            options={{
              title: 'Results',
              headerBackTitle: 'Back',
            }}
          />
          <Stack.Screen
            name="history"
            options={{
              title: 'History',
              headerBackTitle: 'Back',
            }}
          />
          <Stack.Screen
            name="settings"
            options={{
              title: 'Settings',
              headerBackTitle: 'Back',
            }}
          />
          <Stack.Screen
            name="help"
            options={{
              title: 'Help',
              headerBackTitle: 'Back',
            }}
          />
          <Stack.Screen
            name="paywall"
            options={{
              title: 'Upgrade to Pro',
              headerBackTitle: 'Back',
              presentation: 'modal',
            }}
          />
          <Stack.Screen
            name="consent"
            options={{
              title: 'Privacy Settings',
              headerBackTitle: 'Back',
              presentation: 'modal',
            }}
          />
        </Stack>
        <StatusBar style="light" />
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
