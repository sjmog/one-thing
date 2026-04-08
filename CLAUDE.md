# One Thing

Daily goal planning app with pomodoro timer.

## Architecture

Single `index.html` with embedded CSS/JS, no external dependencies. Uses localStorage for persistence.

## Release Channels

This app has two distribution channels:

| Channel | Location | Build Command | Distribution |
|---------|----------|---------------|--------------|
| Chrome Extension | `extension/` | N/A (static files) | Chrome Web Store |
| Desktop App | `electron/` | `npm run build:mac` | GitHub Releases |

## Release Process

After completing a feature:

1. **Commit changes** to main branch
2. **Release Chrome Extension** (if extension files changed):
   - Update version in `extension/manifest.json`
   - Zip the `extension/` folder
   - Upload to Chrome Web Store Developer Dashboard
3. **Release Desktop App**:
   - Update version in `electron/package.json`
   - Build: `cd electron && npm run build:mac` (or `build:win`, `build:linux`, `build` for all)
   - Create GitHub release with built artifacts from `electron/dist/`

## Build Commands (Electron)

```bash
cd electron
npm install          # Install dependencies
npm start            # Run in development
npm run build:mac    # Build macOS .dmg
npm run build:win    # Build Windows .exe
npm run build:linux  # Build Linux .AppImage
npm run build        # Build all platforms
```

## Notes

- The desktop app auto-hides the "install as new tab" hint via `window.electronAPI.isElectron`
- macOS builds are unsigned; users need to right-click → Open on first launch
- Build artifacts go to `electron/dist/` (gitignored)
