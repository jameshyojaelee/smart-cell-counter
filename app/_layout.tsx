/**
 * Root layout for the Smart Cell Counter app
 */
import { useEffect } from 'react';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { initializeDatabase } from '../src/data/db';
import { logger } from '../src/utils/logger';

export default function RootLayout(): JSX.Element {
  useEffect(() => {
    // Initialize database on app start
    const initializeApp = async (): Promise<void> => {
      try {
        logger.info('App', 'Initializing Smart Cell Counter');
        await initializeDatabase();
        logger.info('App', 'Database initialized successfully');
      } catch (error) {
        logger.error('App', 'Failed to initialize database', error);
      }
    };

    initializeApp();
  }, []);

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
        </Stack>
        <StatusBar style="light" />
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
