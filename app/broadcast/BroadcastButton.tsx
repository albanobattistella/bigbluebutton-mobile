import { Button, NativeModules } from 'react-native';

export default function BroadcastButton() {
  const startBroadcast = () => {
    NativeModules.ScreenBroadcastPicker.start()
      .then(() => console.log('Broadcast started'))
      .catch((err: any) => console.warn('Broadcast error', err));
  };

  return <Button title="Start Screen Share" onPress={startBroadcast} />;
}
