const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const { autoUpdater } = require('electron-updater');

// Keep a global reference of the window object to prevent garbage collection
let mainWindow = null;
let updateReady = false;
let focusCheckInterval = null;

// Auto-updater configuration - silent background updates
autoUpdater.autoDownload = true;
autoUpdater.autoInstallOnAppQuit = true;
autoUpdater.logger = null; // Disable verbose logging

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

  // Check for updates silently (only in production)
  if (app.isPackaged) {
    autoUpdater.checkForUpdates();
  }
});

// Auto-updater events - silent auto-restart when not focused
autoUpdater.on('update-downloaded', () => {
  updateReady = true;
  // Start checking if we can safely restart
  if (!focusCheckInterval) {
    focusCheckInterval = setInterval(() => {
      if (mainWindow) {
        mainWindow.webContents.send('check-focus');
      }
    }, 2000); // Check every 2 seconds
  }
});

// IPC handler for focus check response
ipcMain.on('focus-status', (event, isFocused) => {
  if (updateReady && !isFocused) {
    // No input focused - safe to restart
    if (focusCheckInterval) {
      clearInterval(focusCheckInterval);
      focusCheckInterval = null;
    }
    autoUpdater.quitAndInstall(true, true); // Silent restart
  }
});
