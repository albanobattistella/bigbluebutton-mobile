import React, { useRef } from 'react';
import { Platform, Pressable, SafeAreaView, ScrollView, StyleSheet, Text, View } from 'react-native';
import Draggable from 'react-native-draggable';

interface DebugPopupProps {
  visible: boolean;
  position: { x: number; y: number };
  maximized: boolean;
  onClose: () => void;
  onMaximize: () => void;
  onRestore: () => void;
  onCopyApp: () => void;
  onCopyWeb: () => void;
  onClearApp: () => void;
  onClearWeb: () => void;
  appLogs: string[];
  webLogs: string[];
}

export default function DebugPopup({
  visible,
  position,
  maximized,
  onClose,
  onMaximize,
  onRestore,
  onCopyApp,
  onCopyWeb,
  onClearApp,
  onClearWeb,
  appLogs,
  webLogs,
}: DebugPopupProps) {
  if (!visible) return null;

  // Scroll refs for auto-scrolling
  const appLogsScrollRef = useRef<ScrollView>(null);
  const webLogsScrollRef = useRef<ScrollView>(null);

  // Auto-scroll to bottom when logs change
  React.useEffect(() => {
    if (appLogs.length > 0) {
      setTimeout(() => {
        appLogsScrollRef.current?.scrollToEnd({ animated: true });
      }, 100);
    }
  }, [appLogs]);

  React.useEffect(() => {
    if (webLogs.length > 0) {
      setTimeout(() => {
        webLogsScrollRef.current?.scrollToEnd({ animated: true });
      }, 100);
    }
  }, [webLogs]);

  const popupStyle = maximized
    ? [styles.debugPopup, styles.debugPopupMaximized]
    : [styles.debugPopup, { /* draggable will handle position */ }];

  return (
    <View style={styles.debugOverlay} pointerEvents="box-none">
      {maximized ? (
        <SafeAreaView style={popupStyle} pointerEvents="auto">
          <View style={styles.debugPopupSafeArea}>
            <View style={styles.debugHeader}>
              <Text style={styles.debugTitle}>Debug Console</Text>
              <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                <Pressable
                  onPress={() => {
                    onRestore();
                  }}
                  style={styles.debugButton}
                  accessibilityLabel={'Restore'}
                >
                  <Text style={styles.debugButtonText}>Restore</Text>
                </Pressable>
                <Pressable onPress={() => {
                  onClose();
                }} style={styles.debugButton}><Text style={styles.debugButtonText}>Close</Text></Pressable>
              </View>
            </View>
            <View style={[styles.debugBody, maximized && { flex: 1 }]}>
              <View style={[styles.debugColumn, maximized && styles.debugColumnMaximized]}>
                <Text style={styles.debugLabel}>APP</Text>
                <ScrollView 
                  ref={appLogsScrollRef}
                  style={[styles.debugScroll, maximized && styles.debugScrollMaximized]}
                  contentContainerStyle={maximized ? { flexGrow: 1 } : undefined}
                  showsVerticalScrollIndicator={true}
                  showsHorizontalScrollIndicator={true}
                  indicatorStyle="white"
                  scrollIndicatorInsets={{ right: 1 }}
                >
                  <Text selectable style={styles.debugText}>{appLogs.join('\n')}</Text>
                </ScrollView>
                <View style={styles.debugActions}>
                  <Pressable onPress={() => {
                    onCopyApp();
                  }} style={styles.debugButton}><Text style={styles.debugButtonText}>Copy</Text></Pressable>
                  <Pressable onPress={() => {
                    onClearApp();
                  }} style={styles.debugButton}><Text style={styles.debugButtonText}>Clear</Text></Pressable>
                </View>
              </View>
              <View style={[styles.debugColumn, maximized && styles.debugColumnMaximized]}>
                <Text style={styles.debugLabel}>Web</Text>
                <ScrollView 
                  ref={webLogsScrollRef}
                  style={[styles.debugScroll, maximized && styles.debugScrollMaximized]}
                  contentContainerStyle={maximized ? { flexGrow: 1 } : undefined}
                  showsVerticalScrollIndicator={true}
                  showsHorizontalScrollIndicator={true}
                  indicatorStyle="white"
                  scrollIndicatorInsets={{ right: 1 }}
                >
                  <Text selectable style={styles.debugText}>{webLogs.join('\n')}</Text>
                </ScrollView>
                <View style={styles.debugActions}>
                  <Pressable onPress={() => {
                    onCopyWeb();
                  }} style={styles.debugButton}><Text style={styles.debugButtonText}>Copy</Text></Pressable>
                  <Pressable onPress={() => {
                    onClearWeb();
                  }} style={styles.debugButton}><Text style={styles.debugButtonText}>Clear</Text></Pressable>
                </View>
              </View>
            </View>
          </View>
        </SafeAreaView>
      ) : (
        <Draggable
          x={position.x}
          y={position.y}
          minX={0}
          minY={0}
          onPressOut={() => {}}
          onDrag={() => {}}
          onRelease={() => {}}
        >
          <View style={popupStyle} pointerEvents="auto">
            <View style={styles.debugHeader}>
              <Text style={styles.debugTitle}>Debug Console</Text>
              <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                <Pressable
                  onPress={() => {
                    onMaximize();
                  }}
                  style={styles.debugButton}
                  accessibilityLabel={'Maximize'}
                >
                  <Text style={styles.debugButtonText}>Maximize</Text>
                </Pressable>
                <Pressable onPress={() => {
                  onClose();
                }} style={styles.debugButton}><Text style={styles.debugButtonText}>Close</Text></Pressable>
              </View>
            </View>
            <View style={styles.debugBody}>
              <View style={styles.debugColumn}>
                <Text style={styles.debugLabel}>APP</Text>
                <ScrollView 
                  ref={appLogsScrollRef}
                  style={styles.debugScroll}
                  showsVerticalScrollIndicator={true}
                  showsHorizontalScrollIndicator={true}
                  indicatorStyle="white"
                  scrollIndicatorInsets={{ right: 1 }}
                >
                  <Text selectable style={styles.debugText}>{appLogs.join('\n')}</Text>
                </ScrollView>
                <View style={styles.debugActions}>
                  <Pressable onPress={() => {
                    onCopyApp();
                  }} style={styles.debugButton}><Text style={styles.debugButtonText}>Copy</Text></Pressable>
                  <Pressable onPress={() => {
                    onClearApp();
                  }} style={styles.debugButton}><Text style={styles.debugButtonText}>Clear</Text></Pressable>
                </View>
              </View>
              <View style={styles.debugColumn}>
                <Text style={styles.debugLabel}>Web</Text>
                <ScrollView 
                  ref={webLogsScrollRef}
                  style={styles.debugScroll}
                  showsVerticalScrollIndicator={true}
                  showsHorizontalScrollIndicator={true}
                  indicatorStyle="white"
                  scrollIndicatorInsets={{ right: 1 }}
                >
                  <Text selectable style={styles.debugText}>{webLogs.join('\n')}</Text>
                </ScrollView>
                <View style={styles.debugActions}>
                  <Pressable onPress={() => {
                    onCopyWeb();
                  }} style={styles.debugButton}><Text style={styles.debugButtonText}>Copy</Text></Pressable>
                  <Pressable onPress={() => {
                    onClearWeb();
                  }} style={styles.debugButton}><Text style={styles.debugButtonText}>Clear</Text></Pressable>
                </View>
              </View>
            </View>
          </View>
        </Draggable>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  debugOverlay: {
    position: 'absolute',
    top: 0, left: 0, right: 0, bottom: 0,
    backgroundColor: 'rgba(10,20,10,0.35)',
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 1000,
  },
  debugPopup: {
    width: 832, // Increased by 30% from 640
    maxWidth: 1040, // Increased by 30% from 800
    minHeight: 416, // Increased by 30% from 320
    flexDirection: 'column',
    backgroundColor: 'rgba(20,30,20,0.95)',
    borderRadius: 16,
    padding: 16,
    shadowColor: '#000',
    shadowOpacity: 0.2,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 4 },
  },
  debugPopupMaximized: {
    position: 'absolute',
    left: 0,
    top: 0,
    width: '100%',
    height: '100%',
    minHeight: undefined,
    maxWidth: undefined,
    borderRadius: 0,
    padding: 0,
    zIndex: 2000,
    paddingTop: 24,
    paddingBottom: 24,
    paddingLeft: 12,
    paddingRight: 12,
  },
  debugPopupSafeArea: {
    flex: 1,
    padding: 8,
  },
  debugHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  debugTitle: {
    color: '#00ff00',
    fontSize: 18,
    fontWeight: 'bold',
    fontFamily: 'monospace',
  },
  debugButton: {
    backgroundColor: 'rgba(0,64,0,0.2)',
    borderRadius: 6,
    paddingHorizontal: 12,
    paddingVertical: 6,
    marginLeft: 8,
  },
  debugButtonText: {
    color: '#00ff00',
    fontFamily: 'monospace',
    fontWeight: 'bold',
    fontSize: 14,
  },
  debugBody: {
    flexDirection: 'row',
    gap: 12,
    flex: 1,
    minHeight: 260, // Increased by 30% from 200
  },
  debugColumn: {
    flex: 1,
    flexDirection: 'column',
    marginHorizontal: 4,
  },
  debugColumnMaximized: {
    flex: 1,
    minHeight: 0,
    maxHeight: '100%',
  },
  debugLabel: {
    color: '#00ff00',
    fontFamily: 'monospace',
    fontWeight: 'bold',
    fontSize: 15,
    marginBottom: 4,
  },
  debugScroll: {
    backgroundColor: 'rgba(0,0,0,0.2)',
    borderRadius: 8,
    padding: 8,
    minHeight: 156, // Increased by 30% from 120
    maxHeight: 286, // Increased by 30% from 220
    marginBottom: 8,
  },
  debugScrollMaximized: {
    flex: 1,
    minHeight: 0,
    maxHeight: '100%',
    marginBottom: 8,
  },
  debugText: {
    color: '#00ff00',
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    fontSize: 13,
  },
  debugActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: 8,
  },
}); 