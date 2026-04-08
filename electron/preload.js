const { contextBridge } = require('electron');

// Expose a flag to indicate we're running in Electron
contextBridge.exposeInMainWorld('electronAPI', {
  isElectron: true
});
