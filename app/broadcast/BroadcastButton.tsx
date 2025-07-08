import { useTranslation } from 'react-i18next';
import { Button, NativeModules } from 'react-native';

export default function BroadcastButton() {
  const { t } = useTranslation();
  const startBroadcast = () => {
    NativeModules.ScreenBroadcastPicker.start()
      .then(() => console.log('Broadcast started'))
      .catch((err: any) => console.warn('Broadcast error', err));
  };

  return <Button title={t('home.screenShareButton')} onPress={startBroadcast} />;
}
