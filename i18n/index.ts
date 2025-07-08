import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Localization from 'expo-localization';
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import translationDe from './locales/de/translation.json';
import translationEn from './locales/en/translation.json';
import translationPt from './locales/pt-BR/translation.json';

const resources = {
  en: { translation: translationEn },
  'pt-BR': { translation: translationPt },
  de: { translation: translationDe },
};

const LANGUAGE_KEY = 'language';

const initI18n = async () => {
  let savedLanguage = await AsyncStorage.getItem(LANGUAGE_KEY);
  if (!savedLanguage) {
    savedLanguage = Localization.getLocales()[0]?.languageTag || 'en';
  }
  const lng = Object.keys(resources).includes(savedLanguage) ? savedLanguage : 'en';
  i18n.use(initReactI18next).init({
    resources,
    lng,
    fallbackLng: 'en',
    interpolation: { escapeValue: false },
  });
};

initI18n();

export default i18n; 