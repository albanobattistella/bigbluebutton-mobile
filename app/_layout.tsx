import { DarkTheme, DefaultTheme, ThemeProvider } from '@react-navigation/native';
import { useFonts } from 'expo-font';
import 'react-native-reanimated';

import { ThemedText } from '@/components/ThemedText';
import { ThemedView } from '@/components/ThemedView';
import { useColorScheme } from '@/hooks/useColorScheme';
import { Button } from '@react-navigation/elements';
import { KeyboardAvoidingView, Platform, StyleSheet, TextInput, View } from 'react-native';
import BroadcastButton from './broadcast/BroadcastButton';

export default function RootLayout() {
  const colorScheme = useColorScheme();
  const [loaded] = useFonts({
    SpaceMono: require('../assets/fonts/SpaceMono-Regular.ttf'),
  });

  if (!loaded) {
    // Async font loading only occurs in development.
    return null;
  }

  return (
    <ThemeProvider value={colorScheme === 'dark' ? DarkTheme : DefaultTheme}>
      <ThemedView style={styles.container}>
        <KeyboardAvoidingView
          style={styles.inner}
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        >
          <ThemedText type="title" style={styles.title}>
            BigBlueButton
          </ThemedText>
          <ThemedText type="subtitle" style={styles.subtitle}>
            Join meetings with extra features—like screen sharing
          </ThemedText>
          <ThemedText style={styles.description}>
            You can join a meeting directly, or transfer one from another device by scanning a QR code.
          </ThemedText>

          <View style={styles.card}>
            <ThemedText style={styles.inputLabel}>Paste your meeting link below:</ThemedText>
            <TextInput
              placeholder="e.g. https://your-meeting-url"
              autoFocus={true}
              style={styles.input}
              placeholderTextColor="#888"
            />
            <Button onPress={() => {}} color="#0a7ea4">Join Meeting</Button>
          </View>

          <View style={styles.spacer} />
          <BroadcastButton />
        </KeyboardAvoidingView>
      </ThemedView>
    </ThemeProvider>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  inner: {
    width: '100%',
    maxWidth: 420,
    alignItems: 'center',
  },
  title: {
    marginBottom: 8,
    textAlign: 'center',
  },
  subtitle: {
    marginBottom: 8,
    textAlign: 'center',
  },
  description: {
    marginBottom: 24,
    textAlign: 'center',
    color: '#687076',
  },
  card: {
    width: '100%',
    backgroundColor: 'rgba(0,0,0,0.04)',
    borderRadius: 16,
    padding: 20,
    marginBottom: 24,
    shadowColor: '#000',
    shadowOpacity: 0.08,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 2 },
    elevation: 2,
  },
  inputLabel: {
    marginBottom: 8,
    fontWeight: '600',
  },
  input: {
    height: 44,
    borderColor: '#ccc',
    borderWidth: 1,
    borderRadius: 8,
    paddingHorizontal: 12,
    marginBottom: 12,
    backgroundColor: '#fff',
    fontSize: 16,
  },
  spacer: {
    height: 24,
  },
});
