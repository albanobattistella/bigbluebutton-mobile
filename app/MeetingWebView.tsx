import { Ionicons } from '@expo/vector-icons';
import React, { useRef, useState } from 'react';
import { Clipboard, Dimensions, Platform, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { WebView, WebViewMessageEvent } from 'react-native-webview';
import { AppLogger } from '../components/AppLogger';
import DebugPopup from '../components/DebugPopup';
import stopScreenShare from './methods/stopScreenShare';
import { handleWebviewMessage } from './webview/message-handler';

interface MeetingWebViewProps {
  url: string;
  onClose: () => void;
}

export default function MeetingWebView({ url, onClose: externalOnClose }: MeetingWebViewProps) {
  const webviewRef = useRef(null);
  const [status, setStatus] = useState<'Loading' | 'Loaded' | 'Error'>('Loading');
  const [webLogs, _setWebLogs] = useState<string[]>([]);
  const [appLogs, _setAppLogs] = useState<string[]>(AppLogger.getInstance().getLogs());
  
  const onClose = React.useCallback(() => {
    stopScreenShare(1);
    externalOnClose();
  }, [externalOnClose]);
  
  // Robust popup state management
  const window = Dimensions.get('window');
  const initialPopupState = {
    visible: false,
    position: { x: window.width * 0.05, y: window.height * 0.15 },
    maximized: false,
    dragOffset: undefined as { x: number; y: number } | undefined,
  };
  type DebugPopupState = typeof initialPopupState;
  const [_debugPopupState, _setDebugPopupState] = useState(initialPopupState);

  // Logging wrappers for state setters
  const setDebugPopupState = (updater: DebugPopupState | ((prev: DebugPopupState) => DebugPopupState)) => {
    _setDebugPopupState((prev: DebugPopupState) => {
      const next = typeof updater === 'function' ? (updater as (prev: DebugPopupState) => DebugPopupState)(prev) : updater;
      return next;
    });
  };
  const setWebLogs = (updater: any) => {
    _setWebLogs((prev: any) => {
      const next = typeof updater === 'function' ? updater(prev) : updater;
      return next;
    });
  };
  const setAppLogs = (updater: any) => {
    _setAppLogs((prev: any) => {
      const next = typeof updater === 'function' ? updater(prev) : updater;
      return next;
    });
  };
  const setStatusLogged = (updater: any) => {
    setStatus((prev: any) => {
      const next = typeof updater === 'function' ? updater(prev) : updater;
      return next;
    });
  };

  // Subscribe to AppLogger updates
  React.useEffect(() => {
    const unsub = AppLogger.getInstance().subscribe(setAppLogs);
    return unsub;
  }, []);

  React.useEffect(() => {
  }, []);

  // --- Injected JS for WebView ---
  const injectedJS = `
    (function() {
      function wrapConsole(method) {
        var orig = console[method];
        console[method] = function() {
          var msg = Array.prototype.slice.call(arguments).join(' ');
          window.ReactNativeWebView.postMessage(JSON.stringify({ type: 'web-log', level: method, msg }));
          orig.apply(console, arguments);
        };
      }
      ['log','info','warn','error'].forEach(wrapConsole);
    })();
    true;
  `;

  // --- WebView Message Handler ---
  function onWebviewMessage(event: WebViewMessageEvent) {
    try {
      const data = JSON.parse(event.nativeEvent.data);
      
      if (data.type === 'web-log') {
        setWebLogs((prev: any) => [
          `[${data.level.toUpperCase()}] ${new Date().toISOString()} ${data.msg}`,
          ...prev,
        ].slice(0, 500));
      } else {
        // Log all messages to app logger
        AppLogger.getInstance().info(`WebView postMessage: ${JSON.stringify(data)}`);

        // Call the actual message handler
        handleWebviewMessage(1, webviewRef, event);
      }
    } catch (e) {
      // Log non-JSON messages to app logger as well
      AppLogger.getInstance().info(`WebView postMessage (non-JSON): ${event.nativeEvent.data}`);
    }
  }

  // Popup handlers
  const handleOpenDebug = () => {
    setDebugPopupState({
      visible: true,
      position: { x: window.width * 0.05, y: window.height * 0.15 },
      maximized: false,
      dragOffset: undefined,
    });
  };
  const handleCloseDebug = () => setDebugPopupState((prev: DebugPopupState) => ({ ...prev, visible: false, dragOffset: undefined }));
  const handleMaximize = () => setDebugPopupState((prev: DebugPopupState) => ({ ...prev, maximized: true, dragOffset: undefined }));
  const handleRestore = () => setDebugPopupState((prev: DebugPopupState) => ({ ...prev, maximized: false, dragOffset: undefined }));
  const handleCopyApp = () => {
    if (typeof navigator !== 'undefined' && navigator.clipboard) {
      navigator.clipboard.writeText(appLogs.join('\n'));
    } else if (Clipboard) {
      Clipboard.setString(appLogs.join('\n'));
    }
  };
  const handleCopyWeb = () => {
    if (typeof navigator !== 'undefined' && navigator.clipboard) {
      navigator.clipboard.writeText(webLogs.join('\n'));
    } else if (Clipboard) {
      Clipboard.setString(webLogs.join('\n'));
    }
  };
  const handleClearApp = () => AppLogger.getInstance().clear();
  const handleClearWeb = () => setWebLogs([]);

  const handleReload = () => {
    // @ts-ignore
    webviewRef.current?.reload();
    setStatusLogged('Loading');
  };

  // Use the logging wrappers for state
  const debugPopupState = _debugPopupState;

  return (
    <View style={styles.container}>
      {/* Toolbar */}
      <View style={styles.toolbar}>
        <TouchableOpacity onPress={onClose} style={styles.toolbarButton} accessibilityLabel="Close">
          <Ionicons name="close" size={24} color="#222" />
        </TouchableOpacity>
        <TouchableOpacity onPress={handleReload} style={styles.toolbarButton} accessibilityLabel="Refresh">
          <Ionicons name="refresh" size={24} color="#222" />
        </TouchableOpacity>
        <View style={styles.statusContainer}>
          <TouchableOpacity onPress={handleOpenDebug}>
            <Text style={styles.statusText}>{status}</Text>
          </TouchableOpacity>
        </View>
      </View>
      {/* WebView */}
      <WebView
        ref={webviewRef}
        source={{ uri: url }}
        onLoadStart={() => setStatusLogged('Loading')}
        onLoadEnd={() => setStatusLogged('Loaded')}
        onError={() => setStatusLogged('Error')}
        onMessage={onWebviewMessage}
        style={styles.webview}
        contentMode='mobile'
        allowsInlineMediaPlayback={true}
        mediaCapturePermissionGrantType='grant'
        applicationNameForUserAgent='BigBlueButton-Tablet'
        injectedJavaScript={injectedJS}
        mediaPlaybackRequiresUserAction={false}
        webviewDebuggingEnabled={true}
      />
      {debugPopupState.visible && (
        <DebugPopup
          visible={debugPopupState.visible}
          position={debugPopupState.position}
          maximized={debugPopupState.maximized}
          onClose={handleCloseDebug}
          onMaximize={handleMaximize}
          onRestore={handleRestore}
          onCopyApp={handleCopyApp}
          onCopyWeb={handleCopyWeb}
          onClearApp={handleClearApp}
          onClearWeb={handleClearWeb}
          appLogs={appLogs}
          webLogs={webLogs}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f9fb',
  },
  toolbar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingTop: Platform.OS === 'ios' ? 36 : 16, // extra top padding for iPad/iOS status bar
    paddingBottom: 12,
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#e5e7eb',
    shadowColor: '#000',
    shadowOpacity: 0.06,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 2 },
    elevation: 3,
    zIndex: 2,
  },
  toolbarButton: {
    marginRight: 16,
    padding: 8,
    borderRadius: 6,
    backgroundColor: '#f1f3f6',
    justifyContent: 'center',
    alignItems: 'center',
  },
  statusContainer: {
    flex: 1,
    alignItems: 'flex-end',
  },
  statusText: {
    fontSize: 15,
    color: '#4b5563',
    fontWeight: '500',
    letterSpacing: 0.2,
  },
  webview: {
    flex: 1,
  },
}); 