import '@/i18n';
import { Picker } from '@react-native-picker/picker';
import { DarkTheme, DefaultTheme, ThemeProvider } from '@react-navigation/native';
import { useFonts } from 'expo-font';
import React from 'react';
import { useTranslation } from 'react-i18next';
import 'react-native-reanimated';

import { ThemedText } from '@/components/ThemedText';
import { ThemedView } from '@/components/ThemedView';
import { useColorScheme } from '@/hooks/useColorScheme';
import { Button, KeyboardAvoidingView, Platform, StyleSheet, TextInput, View } from 'react-native';
import MeetingWebView from './MeetingWebView';

export default function RootLayout() {
  const colorScheme = useColorScheme();
  const [loaded] = useFonts({
    SpaceMono: require('../assets/fonts/SpaceMono-Regular.ttf'),
  });
  const { t, i18n } = useTranslation();
  const [selectedLanguage, setSelectedLanguage] = React.useState(i18n.language);
  const [showMeeting, setShowMeeting] = React.useState(false);
  const [meetingUrl, setMeetingUrl] = React.useState('https://demo-ios-bbb30.bbb.imdt.dev/rooms/xy8-0jk-asw-v1f/join');

  const handleLanguageChange = (lang: string) => {
    setSelectedLanguage(lang);
    i18n.changeLanguage(lang);
  };

  if (!loaded) {
    // Async font loading only occurs in development.
    return null;
  }

  if (showMeeting) {
    return (
      <MeetingWebView
        url={meetingUrl}
        onClose={() => setShowMeeting(false)}
      />
    );
  }

  return (
    <ThemeProvider value={colorScheme === 'dark' ? DarkTheme : DefaultTheme}>
      <ThemedView style={styles.container}>
        <KeyboardAvoidingView
          style={styles.inner}
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        >
          <ThemedText type="title" style={styles.title}>
            {t('home.title')}
          </ThemedText>
          <ThemedText type="subtitle" style={styles.subtitle}>
            {t('home.subtitle')}
          </ThemedText>
          <ThemedText style={styles.description}>
            {t('home.description')}
          </ThemedText>

          <View style={styles.card}>
            <ThemedText style={styles.inputLabel}>{t('home.inputLabel')}</ThemedText>
            <TextInput
              placeholder={t('home.inputPlaceholder')}
              autoFocus={true}
              style={styles.input}
              placeholderTextColor="#888"
              value={meetingUrl}
              onChangeText={setMeetingUrl}
              onSubmitEditing={() => setShowMeeting(true)}
            />
            <Button title={t('home.joinButton')} onPress={() => setShowMeeting(true)} color="#0a7ea4" />
          </View>

          <View style={styles.spacer} />

          {/* Language Picker */}
          {/* Removed from here */}
        </KeyboardAvoidingView>
        {/* Language Picker moved here for bottom-left alignment */}
        <View style={styles.languagePickerContainer}>
          <Picker
            selectedValue={selectedLanguage}
            onValueChange={handleLanguageChange}
            style={{ color: '#000', fontSize: 16 }}
          >
            <Picker.Item label="English" value="en" />
            <Picker.Item label="Deutsch" value="de" />
            <Picker.Item label="Português (Brasil)" value="pt-BR" />
          </Picker>
        </View>
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
  languagePickerContainer: {
    position: 'absolute',
    left: 24,
    bottom: 24,
    width: 270,
    backgroundColor: 'rgba(255,255,255,0.9)',
    borderRadius: 8,
    padding: 4,
    // Optional: add shadow for visibility
    shadowColor: '#000',
    shadowOpacity: 0.08,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 2 },
    elevation: 2,
  },
});
