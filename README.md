# One Thing

A minimal new tab page for daily planning. Set your goal, track nice-to-dos, and stay focused with a built-in pomodoro timer.

**Live demo:** https://sjmog.github.io/one-thing/

## Features

- **Daily Goal** - One main focus for the day
- **Nice to Do** - Secondary tasks that would be nice to complete
- **Todo Sidebar** - Persistent backlog that carries across days
- **Pomodoro Timer** - 20-minute default, fully customizable
- **Focus Mode** - Set what you're working on during each timer session
- **Dark Mode** - Easy on the eyes
- **Fully Local** - All data stored in your browser's localStorage

## Installation

### Option 1: Chrome Extension (Recommended)

The easiest way to use One Thing as your new tab page.

1. Download `one-thing-extension.zip` from the [latest release](https://github.com/sjmog/one-thing/releases/latest)
2. Unzip the file
3. Open your browser's extensions page:
   - Chrome: `chrome://extensions`
   - Edge: `edge://extensions`
   - Brave: `brave://extensions`
   - Arc: `arc://extensions`
4. Enable **Developer mode** (toggle in top right)
5. Click **Load unpacked**
6. Select the unzipped `extension` folder
7. Open a new tab - done!

### Option 2: Set as Homepage/New Tab URL

Use the hosted version at https://sjmog.github.io/one-thing/

#### Chrome / Brave / Edge
1. Install the [New Tab Redirect](https://chrome.google.com/webstore/detail/new-tab-redirect/icpgjfneehieebagbmdbhnlpiopdcmna) extension
2. Set the URL to `https://sjmog.github.io/one-thing/`

#### Firefox
1. Install the [New Tab Override](https://addons.mozilla.org/en-US/firefox/addon/new-tab-override/) extension
2. Set the URL to `https://sjmog.github.io/one-thing/`

#### Safari
1. Open Safari → Settings (⌘ + ,)
2. Go to "General" tab
3. Set "New tabs open with" to "Homepage"
4. Set Homepage to `https://sjmog.github.io/one-thing/`

#### Arc
1. Open Arc Settings (⌘ + ,)
2. Go to "Links" section
3. Under "New Tab", select "Custom URL"
4. Paste `https://sjmog.github.io/one-thing/`

### Option 3: Local File

1. Download `index.html` from this repo
2. Save it somewhere permanent on your computer
3. Set your browser's new tab/homepage to the file path

## Usage

- **Goal**: Click "GOAL" or the text area to set your main focus
- **Nice to Do**: Click "NICE TO DO" to add secondary tasks
  - Press `Enter` to add a new item
  - Press `Tab` or `↓` to move to next item (creates new if on last)
  - Press `Shift+Tab` or `↑` to move to previous item
  - Hover to reveal check (complete) and × (delete) buttons
- **Todo Sidebar**: Click the ☰ hamburger menu to open your persistent backlog
- **Timer**: Click the time to edit, click ▶ to start
  - Set a "Focus" label when the timer starts
  - Timer state persists across page refreshes
- **Dark Mode**: Click the ☀/☾ icon in the top right
- **Date Navigation**: Use ← → arrows or click the date to jump to any day

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Enter` | Add new item below current |
| `Backspace` (empty) | Delete current item |
| `Tab` | Move to next item |
| `Shift+Tab` | Move to previous item |
| `↑` `↓` | Navigate between items |

## Publishing to Chrome Web Store

To publish your own version:

1. Create a [Chrome Web Store Developer account](https://chrome.google.com/webstore/devconsole/) ($5 one-time fee)
2. Prepare assets:
   - 128×128 icon (already included)
   - At least one 1280×800 or 640×400 screenshot
   - 440×280 small promotional tile (optional)
3. Zip the `extension` folder contents (not the folder itself)
4. Go to the Developer Dashboard → Add new item
5. Upload the zip and fill in the listing details
6. Submit for review (usually takes a few days)

## License

MIT
