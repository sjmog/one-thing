const { contextBridge, ipcRenderer } = require('electron');

// Expose a flag to indicate we're running in Electron
contextBridge.exposeInMainWorld('electronAPI', {
  isElectron: true,
  onCheckFocus: (callback) => ipcRenderer.on('check-focus', callback),
  sendFocusStatus: (isFocused) => ipcRenderer.send('focus-status', isFocused)
});
