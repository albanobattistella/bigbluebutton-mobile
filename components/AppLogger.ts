// --- AppLogger Singleton ---
export class AppLogger {
  static instance: AppLogger;
  private listeners: ((logs: string[]) => void)[] = [];
  private logs: string[] = [];

  private constructor() {}

  static getInstance() {
    if (!AppLogger.instance) {
      AppLogger.instance = new AppLogger();
    }
    return AppLogger.instance;
  }

  info(msg: string) {
    this.addLog('INFO', msg);
  }
  
  debug(msg: string) {
    this.addLog('DEBUG', msg);
  }
  
  private addLog(level: string, msg: string) {
    const entry = `[${level}] ${new Date().toISOString()} ${msg}`;
    this.logs.push(entry);
    console.log(entry);
    setTimeout(() => {
      this.listeners.forEach((cb) => cb([...this.logs]));
    }, 0);
  }
  
  getLogs() {
    return this.logs;
  }
  
  subscribe(cb: (logs: string[]) => void) {
    this.listeners.push(cb);
    return () => {
      this.listeners = this.listeners.filter((l) => l !== cb);
    };
  }
  
  clear() {
    this.logs = [];
    setTimeout(() => {
      this.listeners.forEach((cb) => cb([...this.logs]));
    }, 0);
  }
} 