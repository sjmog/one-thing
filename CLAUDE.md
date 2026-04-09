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
3. **Release Desktop App** (with auto-update support):
   - Update version in `electron/package.json`
   - Build and publish: `cd electron && npm run release`
   - This builds, signs, notarizes, and publishes to GitHub Releases automatically
   - The app checks for updates on launch and prompts users to install

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
- macOS builds are code signed and notarized for seamless installation
- Build artifacts go to `electron/dist/` (gitignored)
- Sync passphrase is stored in localStorage; if forgotten, data is inaccessible
- Auto-update checks GitHub Releases on app launch

## Auto-Update Setup (macOS Code Signing)

The app uses `electron-updater` with GitHub Releases. Required environment variables for building:

```bash
# Apple Developer credentials (for code signing)
export APPLE_ID="your@email.com"
export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"  # Generate at appleid.apple.com
export APPLE_TEAM_ID="XXXXXXXXXX"  # Your 10-character Team ID

# GitHub token (for publishing releases)
export GH_TOKEN="ghp_xxxxxxxxxxxx"  # Needs repo scope
```

To release: `cd electron && npm run release`
