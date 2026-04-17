const { app, BrowserWindow, ipcMain, nativeTheme } = require('electron');
const path = require('path');
const { autoUpdater } = require('electron-updater');

// Update dock icon based on dark mode (macOS only)
const updateDockIcon = () => {
  if (process.platform !== 'darwin') return;
  const iconName = nativeTheme.shouldUseDarkColors ? 'icon-dark.png' : 'icon.png';
  const iconPath = app.isPackaged
    ? path.join(process.resourcesPath, iconName)
    : path.join(__dirname, iconName);
  app.dock.setIcon(iconPath);
};

// Keep a global reference of the window object to prevent garbage collection
let mainWindow = null;
let updateReady = false;
let focusCheckInterval = null;

const UPDATE_CHECK_INTERVAL_MS = 10 * 1000; // re-check every 10 seconds
const FOCUS_POLL_INTERVAL_MS = 5000;

// Auto-updater configuration - silent background updates
autoUpdater.autoDownload = true;
autoUpdater.autoInstallOnAppQuit = true;
autoUpdater.logger = null; // Disable verbose logging

// Surface errors so they're visible when the app is launched from a terminal
autoUpdater.on('error', (error) => {
  console.error('Auto-updater error:', error);
});

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 800,
    minHeight: 600,
    title: 'One Thing',
    titleBarStyle: 'hiddenInset',
    trafficLightPosition: { x: 16, y: 16 },
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  // Load the index.html - path differs between dev and production
  const isDev = !app.isPackaged;
  const indexPath = isDev
    ? path.join(__dirname, '..', 'index.html')
    : path.join(process.resourcesPath, 'index.html');
  mainWindow.loadFile(indexPath);

  // Losing window focus is a good moment to slip in a pending update.
  mainWindow.on('blur', attemptSilentInstall);

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

// macOS: Quit when all windows are closed (except on macOS)
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

// macOS: Re-create window when dock icon is clicked
app.on('activate', () => {
  if (mainWindow === null) {
    createWindow();
  }
});

// Create window when Electron is ready
app.whenReady().then(() => {
  createWindow();

  // Set dock icon based on current theme
  updateDockIcon();

  // Listen for theme changes
  nativeTheme.on('updated', updateDockIcon);

  // Check for updates silently (only in production)
  if (app.isPackaged) {
    autoUpdater.checkForUpdates();
    // Re-check periodically so long-running sessions still pick up new releases
    setInterval(() => {
      if (!updateReady) autoUpdater.checkForUpdates();
    }, UPDATE_CHECK_INTERVAL_MS);
  }
});

// Try to install a downloaded update if it's safe right now.
function attemptSilentInstall() {
  if (!updateReady || !mainWindow) return;

  // If the window isn't focused the user can't be typing in our app — install now.
  if (!mainWindow.isFocused()) {
    finalizeInstall();
    return;
  }

  // Window has focus — ask the renderer whether an input is actively focused.
  mainWindow.webContents.send('check-focus');
}

function finalizeInstall() {
  if (focusCheckInterval) {
    clearInterval(focusCheckInterval);
    focusCheckInterval = null;
  }
  autoUpdater.quitAndInstall(true, true); // Silent restart
}

// Auto-updater events - silent auto-restart when not focused
autoUpdater.on('update-downloaded', () => {
  updateReady = true;
  attemptSilentInstall();
  // Polling fallback in case the window stays focused and no blur fires
  if (!focusCheckInterval) {
    focusCheckInterval = setInterval(attemptSilentInstall, FOCUS_POLL_INTERVAL_MS);
  }
});

// IPC handler for focus check response
ipcMain.on('focus-status', (event, isFocused) => {
  if (updateReady && !isFocused) finalizeInstall();
});
