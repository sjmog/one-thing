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
   - Build: `cd electron && npm run build:mac`
   - Create GitHub release: `gh release create vX.X.X --title "vX.X.X" --notes "..."`
   - Upload dmg: `gh release upload vX.X.X "electron/dist/One Thing-X.X.X-arm64.dmg"`

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

## Sync Backend

Cross-device sync is powered by Cloudflare Workers + D1 database.

### Setup (First Time)

```bash
cd backend
npm install
npm run db:create        # Creates D1 database, outputs database_id
# Update wrangler.toml with your database_id
npm run db:migrate       # Creates tables
npm run deploy           # Deploys worker
# Update SYNC_API_URL in index.html and extension/newtab.html
```

### Backend Commands

```bash
cd backend
npm run dev              # Local development
npm run deploy           # Deploy to Cloudflare
npm run db:migrate       # Run schema migrations
npm run db:migrate:local # Run migrations locally
```

### Architecture

- **Auth**: Passphrase-based (SHA-256 hash becomes user ID)
- **Storage**: Cloudflare D1 (SQLite)
- **Sync**: Last-write-wins based on timestamp
- **API Endpoints**:
  - `POST /sync/push` - Push changes to server
  - `POST /sync/pull` - Pull changes since timestamp
  - `POST /sync/full` - Initial full sync

## Notes

- The desktop app auto-hides the "install as new tab" hint via `window.electronAPI.isElectron`
- macOS builds are unsigned; users need to right-click → Open on first launch
- Build artifacts go to `electron/dist/` (gitignored)
- Sync passphrase is stored in localStorage; if forgotten, data is inaccessible
