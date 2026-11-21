#!/usr/bin/env python3
"""
Lex Hopper Auto-Player
=====================
Automates playing the crossword game via ADB and extracts all words to a file.

Requirements:
  - ADB installed and device connected:  https://developer.android.com/tools/adb
  - Tesseract OCR:  https://github.com/tesseract-ocr/tesseract
  - Python 3.8+ packages:  pip install Pillow pytesseract

Usage:
  python auto_player.py                     # default settings
  python auto_player.py --output words.txt  # custom output file
  python auto_player.py --ocr-lang eng+ell  # English + Greek OCR
  python auto_player.py --dry-run           # preview without tapping
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

# ── Try imports, show friendly errors ─────────────────────────────────────────
try:
    from PIL import Image
    import pytesseract
except ImportError:
    print("ERROR: Missing dependencies.")
    print("  Install with:  pip install Pillow pytesseract")
    print("  Also install Tesseract OCR:  https://github.com/tesseract-ocr/tesseract")
    sys.exit(1)


# ── Configuration ──────────────────────────────────────────────────────────────
# Adjust these coordinates to match your device / emulator screen.
# Run `python auto_player.py --calibrate` to find them.

DEFAULT_CONFIG = {
    # Region of interest for OCR (crop the grid + clues area)
    "ocr_region": (0, 0, 0, 0),  # (x1, y1, x2, y2) — 0 means "full screen"

    # Grid area (for tapping cells)
    "grid_area": {"x": 0, "y": 0, "width": 0, "height": 0, "cols": 5, "rows": 5},

    # Button positions (tap targets)
    "buttons": {
        "check":      {"x": 0, "y": 0},
        "hint":       {"x": 0, "y": 0},
        "clear":      {"x": 0, "y": 0},
        "next_level": {"x": 0, "y": 0},
    },

    # Delays (seconds)
    "delays": {
        "after_screenshot": 0.3,
        "after_tap":        0.2,
        "after_type":       0.1,
        "between_levels":   2.0,
    },
}

# Words already known — skip them (loaded from output file on restart)
KNOWN_WORDS = set()


# ── ADB Helpers ─────────────────────────────────────────────────────────────────
def adb(cmd: str, timeout: int = 10) -> str:
    """Run an ADB command and return stdout."""
    full = f"adb {cmd}"
    try:
        result = subprocess.run(
            full, shell=True, capture_output=True, text=True, timeout=timeout
        )
        return result.stdout.strip()
    except subprocess.TimeoutExpired:
        print(f"  [WARN] ADB command timed out: {cmd}")
        return ""


def adb_device_list() -> list:
    """Return list of connected device serials."""
    out = adb("devices -l")
    devices = []
    for line in out.splitlines()[1:]:  # skip header
        parts = line.split()
        if parts and parts[1] == "device":
            devices.append(parts[0])
    return devices


def get_screen_size() -> tuple:
    """Return (width, height) of device screen."""
    out = adb("shell wm size")
    # "Physical size: 1080x2340"
    m = re.search(r"(\d+)x(\d+)", out)
    if m:
        return (int(m.group(1)), int(m.group(2)))
    return (1080, 2340)  # fallback


def take_screenshot(local_path: str) -> bool:
    """Capture device screen and save to local_path."""
    remote = "/sdcard/screen.png"
    adb("shell screencap -p " + remote)
    time.sleep(0.3)
    result = adb(f"pull {remote} {local_path}")
    adb(f"shell rm {remote}")
    # Verify file exists and is non-empty
    if os.path.isfile(local_path) and os.path.getsize(local_path) > 1000:
        return True
    return False


def tap(x: int, y: int) -> None:
    """Tap at coordinates (x, y)."""
    adb(f"shell input tap {x} {y}")
    time.sleep(DEFAULT_CONFIG["delays"]["after_tap"])


def swipe(x1: int, y1: int, x2: int, y2: int, duration: int = 300) -> None:
    """Swipe from (x1,y1) to (x2,y2)."""
    adb(f"shell input swipe {x1} {y1} {x2} {y2} {duration}")
    time.sleep(DEFAULT_CONFIG["delays"]["after_tap"])


def type_text(text: str) -> None:
    """Type text via ADB (space = %s, newline = %n)."""
    encoded = text.replace(" ", "%s")
    adb(f'shell input text "{encoded}"')
    time.sleep(DEFAULT_CONFIG["delays"]["after_type"])


def key_event(code: int) -> None:
    """Send a key event (66=ENTER, 67=BACK, 257=VOLUME_UP, etc.)."""
    adb(f"shell input keyevent {code}")


# ── OCR ─────────────────────────────────────────────────────────────────────────
def ocr_image(image_path: str, lang: str = "eng", region: tuple = None) -> list:
    """
    Run OCR on a screenshot and return a list of unique words found.
    Optionally crop to a region first.
    """
    img = Image.open(image_path)

    if region and region != (0, 0, 0, 0):
        img = img.crop(region)

    # Extract text
    text = pytesseract.image_to_string(img, lang=lang)

    # Also get detailed data for coordinates
    words = []
    for line in text.splitlines():
        # Clean and split
        tokens = re.findall(r"[A-Za-zα-ωΑ-Ω#]+", line.lower())
        for token in tokens:
            # Filter: at least 2 letters, skip single chars and pure numbers
            if len(token) >= 2 and re.search(r"[A-Za-zα-ωΑ-Ω]", token):
                # Replace '#' with space for phrases
                clean = token.replace("#", " ").strip()
                if clean and clean not in ("the", "a", "an"):  # skip tiny stop words
                    words.append(clean)

    return words


def ocr_with_data(image_path: str, lang: str = "eng") -> list:
    """Return list of (word, confidence, bbox) tuples."""
    img = Image.open(image_path)
    data = pytesseract.image_to_data(img, lang=lang, output_type=pytesseract.Output.DICT)

    results = []
    n = len(data["text"])
    for i in range(n):
        word = data["text"][i].strip().lower()
        conf = int(data["conf"][i])
        if conf > 50 and len(word) >= 2 and re.search(r"[A-Za-zα-ωΑ-Ω]", word):
            x = data["left"][i]
            y = data["top"][i]
            w = data["width"][i]
            h = data["height"][i]
            clean = word.replace("#", " ").strip()
            if clean:
                results.append((clean, conf, (x, y, w, h)))

    return results


# ── Calibration ─────────────────────────────────────────────────────────────────
def calibrate() -> dict:
    """
    Interactive calibration: takes a screenshot, shows it, and asks the user
    to tap on key UI elements to record their positions.
    """
    print("\n" + "=" * 60)
    print("  CALIBRATION MODE")
    print("=" * 60)
    print("\nThis will take a screenshot of your device.")
    print("Make sure the Crossword game screen is visible.")
    print("\nPress Enter when ready...")
    input()

    devices = adb_device_list()
    if not devices:
        print("ERROR: No ADB devices found. Connect your device and retry.")
        sys.exit(1)

    tmp_path = "/tmp/lex_hopper_calibrate.png"
    if not take_screenshot(tmp_path):
        print("ERROR: Failed to take screenshot.")
        sys.exit(1)

    size = get_screen_size()
    print(f"\nDevice screen size: {size[0]} x {size[1]}")
    print(f"\nScreenshot saved to: {tmp_path}")
    print("Open this image and note the coordinates of key elements.\n")

    # Ask user for coordinates
    config = DEFAULT_CONFIG.copy()

    print("--- GRID AREA ---")
    config["grid_area"]["x"] = int(input("  Grid left edge (x):  ").strip() or "0")
    config["grid_area"]["y"] = int(input("  Grid top edge (y):  ").strip() or "0")
    config["grid_area"]["width"] = int(input("  Grid width:  ").strip() or "0")
    config["grid_area"]["height"] = int(input("  Grid height:  ").strip() or "0")
    config["grid_area"]["cols"] = int(input("  Grid columns (default 5):  ").strip() or "5")
    config["grid_area"]["rows"] = int(input("  Grid rows (default 5):  ").strip() or "5")

    print("\n--- BUTTONS ---")
    for btn in ("check", "hint", "clear", "next_level"):
        x = int(input(f"  {btn.capitalize()} button center (x):  ").strip() or "0")
        y = int(input(f"  {btn.capitalize()} button center (y):  ").strip() or "0")
        config["buttons"][btn] = {"x": x, "y": y}

    print("\n--- OCR REGION ---")
    print("  (0 = full screen, or specify x1 y1 x2 y2)")
    r = input("  OCR region (x1 y1 x2 y2, or press Enter for full screen):  ").strip()
    if r:
        parts = r.split()
        config["ocr_region"] = tuple(int(p) for p in parts)
    else:
        config["ocr_region"] = (0, 0, 0, 0)

    # Save config
    config_path = "auto_player_config.json"
    with open(config_path, "w") as f:
        json.dump(config, f, indent=2)
    print(f"\n✓ Configuration saved to {config_path}")
    return config


# ── Word Logger ──────────────────────────────────────────────────────────────────
class WordLogger:
    """Manages the output file: appends new words, tracks duplicates."""

    def __init__(self, filepath: str):
        self.filepath = filepath
        self.new_count = 0
        self.total_count = 0
        self.all_words = set()

        # Load existing words
        if os.path.isfile(filepath):
            with open(filepath, "r", encoding="utf-8") as f:
                for line in f:
                    word = line.strip().lower()
                    if word:
                        self.all_words.add(word)
            self.total_count = len(self.all_words)
            print(f"  Loaded {self.total_count} existing words from {filepath}")

    def add(self, words: list) -> list:
        """Add words, return only the new ones."""
        new = []
        for w in words:
            if w not in self.all_words:
                self.all_words.add(w)
                new.append(w)
                self.new_count += 1
                self.total_count += 1
        return new

    def flush(self) -> None:
        """Write all words to file (sorted)."""
        with open(self.filepath, "w", encoding="utf-8") as f:
            f.write(f"# Lex Hopper — Auto-collected words\n")
            f.write(f"# Collected: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"# Total unique words: {self.total_count}\n")
            f.write("#\n")
            for word in sorted(self.all_words):
                f.write(f"{word}\n")

    def summary(self) -> str:
        return f"Total: {self.total_count} | New this run: {self.new_count}"


# ── Game Automator ──────────────────────────────────────────────────────────────
class GameAutomator:
    """Controls the crossword game via ADB."""

    def __init__(self, config: dict, ocr_lang: str = "eng", dry_run: bool = False):
        self.config = config
        self.ocr_lang = ocr_lang
        self.dry_run = dry_run
        self.tmp_screenshot = "/tmp/lex_hopper_screen.png"
        self.level = 1

    def capture(self) -> bool:
        """Take a screenshot and return success."""
        if not self.dry_run:
            return take_screenshot(self.tmp_screenshot)
        return os.path.isfile(self.tmp_screenshot)

    def read_screen(self) -> list:
        """OCR the current screen and return words."""
        if not self.capture():
            return []
        return ocr_image(
            self.tmp_screenshot,
            lang=self.ocr_lang,
            region=self.config.get("ocr_region", (0, 0, 0, 0)),
        )

    def read_screen_detailed(self) -> list:
        """OCR with position data."""
        if not self.capture():
            return []
        return ocr_with_data(self.tmp_screenshot, lang=self.ocr_lang)

    def tap_cell(self, row: int, col: int) -> None:
        """Tap a grid cell by row/col."""
        if self.dry_run:
            return
        grid = self.config["grid_area"]
        cell_w = grid["width"] / grid["cols"]
        cell_h = grid["height"] / grid["rows"]
        x = grid["x"] + int(cell_w * col + cell_w / 2)
        y = grid["y"] + int(cell_h * row + cell_h / 2)
        tap(x, y)

    def tap_button(self, name: str) -> None:
        """Tap a named button."""
        if self.dry_run:
            print(f"  [DRY RUN] Would tap '{name}' button")
            return
        btn = self.config["buttons"].get(name, {})
        if btn and btn["x"]:
            tap(btn["x"], btn["y"])

    def solve_word(self, word: str, start_row: int, start_col: int, direction: str = "across") -> None:
        """Type a word into the grid starting at (row, col)."""
        if self.dry_run:
            print(f"  [DRY RUN] Would type '{word}' at ({start_row},{start_col})")
            return
        # Tap first cell
        self.tap_cell(start_row, start_col)
        time.sleep(0.3)
        # Type the word
        type_text(word)

    def play_level(self, logger: WordLogger) -> list:
        """
        Play one level: read clues, solve words, check answers.
        Returns list of words found this level.
        """
        print(f"\n  ── Level {self.level} ──")
        found_words = []

        # Take screenshot and read screen
        words_on_screen = self.read_screen()
        print(f"  Words detected on screen: {words_on_screen[:20]}...")

        # Add to logger
        new_words = logger.add(words_on_screen)
        if new_words:
            print(f"  ✦ New words: {new_words}")
            found_words.extend(new_words)

        # Try to detect and solve crossword
        detailed = self.read_screen_detailed()
        self._try_solve_crossword(detailed, logger, found_words)

        # Check answers
        self.tap_button("check")
        time.sleep(1)

        # Check if level is complete (look for "Level X solved" or next level button)
        if self._is_level_complete():
            print(f"  ✓ Level {self.level} solved!")
            self.level += 1
            time.sleep(self.config["delays"]["between_levels"])
            # Go to next level
            self.tap_button("next_level")
            time.sleep(2)
        else:
            # Try hints if stuck
            print(f"  Level not complete, trying hints...")
            self._try_hints(logger, found_words)

        return found_words

    def _try_solve_crossword(self, detailed: list, logger: WordLogger, found_words: list) -> None:
        """Try to identify and fill in crossword words."""
        # Look for clue numbers and text
        clues = self._extract_clues(detailed)
        for clue_num, clue_text in clues.items():
            print(f"  Clue {clue_num}: {clue_text}")
            # Add clue words to logger
            clue_words = [w for w in clue_text.split() if len(w) >= 2]
            new = logger.add(clue_words)
            if new:
                print(f"    → New words from clue: {new}")
                found_words.extend(new)

    def _extract_clues(self, detailed: list) -> dict:
        """Extract numbered clues from OCR data."""
        clues = {}
        for word, conf, bbox in detailed:
            # Look for clue numbers (1, 2, 3...)
            if word.isdigit() and int(word) <= 20:
                clues[int(word)] = ""
        return clues

    def _is_level_complete(self) -> bool:
        """Check if the current level is solved."""
        words = self.read_screen()
        combined = " ".join(words).lower()
        indicators = ["solved", "complete", "congratulations", "well done", "next"]
        return any(ind in combined for ind in indicators)

    def _try_hints(self, logger: WordLogger, found_words: list) -> None:
        """Request hints and re-read the screen."""
        for attempt in range(3):
            print(f"  Hint attempt {attempt + 1}...")
            self.tap_button("hint")
            time.sleep(1)
            words = self.read_screen()
            new = logger.add(words)
            if new:
                print(f"    → New words from hint: {new}")
                found_words.extend(new)
                break

    def run(self, max_levels: int = 0, logger: WordLogger = None) -> WordLogger:
        """
        Main loop: play levels continuously.
        Set max_levels > 0 to limit.
        """
        if logger is None:
            logger = WordLogger("collected_words.txt")

        print(f"\n{'=' * 60}")
        print(f"  LEX HOPPER AUTO-PLAYER")
        print(f"{'=' * 60}")
        print(f"  Device: {' + '.join(adb_device_list())}")
        print(f"  OCR language: {self.ocr_lang}")
        print(f"  Dry run: {self.dry_run}")
        print(f"  Output: {logger.filepath}")
        print(f"{'=' * 60}")

        level = 0
        while True:
            level += 1
            if max_levels and level > max_levels:
                break

            try:
                words = self.play_level(logger)
                logger.flush()
                print(f"\n  📊 {logger.summary()}")
            except KeyboardInterrupt:
                print("\n\n  Stopping...")
                logger.flush()
                print(f"  📊 Final: {logger.summary()}")
                print(f"  Words saved to: {logger.filepath}")
                break
            except Exception as e:
                print(f"  [ERROR] {e}")
                logger.flush()
                time.sleep(2)


# ── Screenshot-only mode (no automation, just collect words) ────────────────────
def screenshot_mode(interval: float = 2.0, max_screenshots: int = 0,
                    ocr_lang: str = "eng", output: str = "collected_words.txt"):
    """Continuously take screenshots and extract words."""
    logger = WordLogger(output)
    tmp = "/tmp/lex_hopper_ss.png"

    print(f"\n{'=' * 60}")
    print(f"  SCREENSHOT MODE — taking screenshots every {interval}s")
    print(f"{'=' * 60}")

    count = 0
    while True:
        count += 1
        if max_screenshots and count > max_screenshots:
            break

        if take_screenshot(tmp):
            words = ocr_image(tmp, lang=ocr_lang)
            new = logger.add(words)
            if new:
                print(f"  [{count}] New words: {new}")
            else:
                print(f"  [{count}] No new words")
            logger.flush()
        else:
            print(f"  [{count}] Screenshot failed")

        time.sleep(interval)


# ── Main ─────────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="Lex Hopper Auto-Player")
    parser.add_argument("--output", default="collected_words.txt",
                        help="Output file for collected words")
    parser.add_argument("--ocr-lang", default="eng",
                        help="Tesseract OCR language (default: eng)")
    parser.add_argument("--max-levels", type=int, default=0,
                        help="Max levels to play (0 = unlimited)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Preview without sending taps")
    parser.add_argument("--calibrate", action="store_true",
                        help="Interactive calibration mode")
    parser.add_argument("--screenshot", action="store_true",
                        help="Screenshot-only mode (no automation)")
    parser.add_argument("--interval", type=float, default=2.0,
                        help="Screenshot interval in seconds (screenshot mode)")
    parser.add_argument("--max-screenshots", type=int, default=0,
                        help="Max screenshots (0 = unlimited)")
    args = parser.parse_args()

    # Calibration mode
    if args.calibrate:
        config = calibrate()
        return

    # Load config
    config_path = "auto_player_config.json"
    if os.path.isfile(config_path):
        with open(config_path) as f:
            config = json.load(f)
        print(f"  Loaded config from {config_path}")
    else:
        config = DEFAULT_CONFIG.copy()
        print("  Using default config (run --calibrate to set coordinates)")

    # Screenshot mode
    if args.screenshot:
        screenshot_mode(
            interval=args.interval,
            max_screenshots=args.max_screenshots,
            ocr_lang=args.ocr_lang,
            output=args.output,
        )
        return

    # Check ADB connection
    devices = adb_device_list()
    if not devices:
        print("\nERROR: No ADB devices found.")
        print("\n  To connect your device:")
        print("    1. Enable Developer Options on your Android device")
        print("    2. Enable USB Debugging")
        print("    3. Connect via USB")
        print("    4. Or use wireless:  adb pair IP:PORT  then  adb connect IP:PORT")
        print("\n  For an emulator, start it and retry.")
        sys.exit(1)

    print(f"  Connected device(s): {', '.join(devices)}")

    # Run the auto-player
    automator = GameAutomator(
        config=config,
        ocr_lang=args.ocr_lang,
        dry_run=args.dry_run,
    )
    automator.run(max_levels=args.max_levels, logger=WordLogger(args.output))


if __name__ == "__main__":
    main()
