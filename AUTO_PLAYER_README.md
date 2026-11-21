# Lex Hopper Auto-Player

Automatically plays the Lex Hopper crossword game on an Android device and collects every word into a text file.

## How It Works

```
┌─────────────┐     ┌──────────┐     ┌──────────────┐
│  Android    │─────▶  ADB     │─────▶  Python      │
│  Device     │     │  Bridge  │     │  Script      │
│             │     │          │     │  - OCR words │
│  Crossword  │◀────┐         │     │  - Tap cells  │
│  Game       │     │ Tap/Type│     │  - Log words  │
└─────────────┘     └──────────┘     └──────┬───────┘
                                            │
                                      ┌─────▼────────┐
                                      │ words.txt    │
                                      │ (all words   │
                                      │  collected)  │
                                      └──────────────┘
```

## Prerequisites

### 1. Install ADB
```bash
# macOS (via Homebrew)
brew install android-platform-tools

# Verify
adb version
```

### 2. Install Tesseract OCR
```bash
# macOS
brew install tesseract
brew install tesseract-lang   # for Greek (ell) and other languages

# Verify
tesseract --version
tesseract --list-langs
```

### 3. Install Python Dependencies
```bash
cd /Users/chef/Desktop/lex_hopper
pip install -r requirements_auto_player.txt
```

### 4. Connect Your Android Device

**USB:**
```bash
# Enable Developer Options + USB Debugging on device
# Connect via USB
adb devices
```

**Wireless:**
```bash
# On your phone: Settings > About > tap Build Number 7 times
# Then: Settings > Developer Options > Wireless debugging
# Note the IP:PORT shown

adb pair 192.168.1.X:12345   # enter the PIN shown on phone
adb connect 192.168.1.X:12345
```

**Emulator:**
```bash
# Just start your emulator (e.g., from Android Studio)
# ADB auto-connects
adb devices
```

## Quick Start

### Step 1: Calibrate (first time only)
```bash
python auto_player.py --calibrate
```
This takes a screenshot and asks you for the coordinates of:
- The grid area
- Buttons (Check, Hint, Clear, Next Level)
- OCR region

### Step 2: Test with dry run
```bash
python auto_player.py --dry-run
```
This previews everything without actually tapping your device.

### Step 3: Screenshot-only mode (safest)
```bash
python auto_player.py --screenshot --interval 3
```
You play manually, the script just captures words from screenshots.

### Step 4: Full auto-play
```bash
python auto_player.py --max-levels 10
```
Plays up to 10 levels automatically.

### With Greek OCR
```bash
python auto_player.py --ocr-lang eng+ell
```

## Output

All collected words are saved to `collected_words.txt`:
```
# Lex Hopper — Auto-collected words
# Collected: 2026-11-20 14:30:00
# Total unique words: 247
#
apple
banana
...
```

The file is updated after every level and deduplicated across runs.

## Modes

| Mode | Command | Description |
|------|---------|-------------|
| **Full Auto** | `python auto_player.py` | Plays and collects words |
| **Screenshot** | `python auto_player.py --screenshot` | You play, it captures |
| **Dry Run** | `python auto_player.py --dry-run` | Test without touching device |
| **Calibrate** | `python auto_player.py --calibrate` | Set up coordinates |

## Troubleshooting

**"No ADB devices found"**
- Check USB connection, enable USB debugging
- Try `adb kill-server && adb start-server`

**OCR returns no words**
- Make sure the game screen is visible during calibration
- Adjust the OCR region coordinates
- Check Tesseract language packs: `tesseract --list-langs`

**Taps go to wrong places**
- Re-run `--calibrate` after any resolution change
- Check that the app is in the same orientation
