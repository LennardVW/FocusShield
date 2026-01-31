# FocusShield

🛡️ Complete distraction blocker for macOS. Block websites, apps, and notifications during focus sessions.

## Features

- 🔒 **Website Blocking** - Block distracting websites (social media, news, etc.)
- 📱 **App Blocking** - Prevent opening distracting apps
- 🔕 **Auto DND** - Automatically enable Do Not Disturb
- ⏱️ **Pomodoro Timer** - 25/50 minute focus sessions
- 📊 **Session Analytics** - Track your focus time
- 🎯 **Smart Breaks** - Suggests breaks based on productivity
- ⌨️ **Global Hotkey** - Start/stop from anywhere
- 🔄 **Schedule** - Auto-start at specific times

## Installation

```bash
git clone https://github.com/LennardVW/FocusShield.git
cd FocusShield
swift build -c release
cp .build/release/focusshield /usr/local/bin/
```

## Usage

```bash
# Start 25-minute focus session
focusshield start 25

# Block specific domains
focusshield add twitter.com
focusshield add reddit.com

# View blocklist
focusshield list

# Check status
focusshield status
```

## Configuration

Create `~/.focusshield/config.json`:
```json
{
  "defaultDuration": 25,
  "blocklist": ["twitter.com", "reddit.com", "youtube.com"],
  "autoDND": true,
  "strictMode": false
}
```

## Global Hotkey

Default: `Ctrl + Option + F` - Start quick focus session

## Requirements
- macOS 15.0+ (Tahoe)
- Swift 6.0+
- Admin privileges (for network blocking)

## License
MIT
