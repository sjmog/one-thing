const { app, BrowserWindow, dialog } = require('electron');
const path = require('path');
const { autoUpdater } = require('electron-updater');

// Keep a global reference of the window object to prevent garbage collection
let mainWindow = null;

// Auto-updater configuration
autoUpdater.autoDownload = true;
autoUpdater.autoInstallOnAppQuit = true;

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

  // Check for updates after app starts (only in production)
  if (app.isPackaged) {
    autoUpdater.checkForUpdatesAndNotify();
  }
});

// Auto-updater events
autoUpdater.on('update-available', (info) => {
  console.log('Update available:', info.version);
});

autoUpdater.on('update-downloaded', (info) => {
  dialog.showMessageBox(mainWindow, {
    type: 'info',
    title: 'Update Ready',
    message: `Version ${info.version} has been downloaded and will be installed when you quit the app.`,
    buttons: ['Restart Now', 'Later']
  }).then((result) => {
    if (result.response === 0) {
      autoUpdater.quitAndInstall();
    }
  });
});

autoUpdater.on('error', (err) => {
  console.error('Auto-updater error:', err);
});
