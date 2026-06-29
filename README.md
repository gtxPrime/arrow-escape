<div align="center">

  <img src="assets/images/logo.png" alt="Arrow Out Logo" width="120" height="120" onerror="this.src='https://raw.githubusercontent.com/gtxPrime/arrow-out/main/assets/images/logo.png'; this.onerror=null;" />

# Arrow Out

**A modern, casual grid puzzle game where you slide arrows out of the grid. Built with Flutter & Flame.**

  <p>
    <a href="https://github.com/gtxPrime/arrow-out/stargazers">
      <img src="https://img.shields.io/github/stars/gtxPrime/arrow-out?style=for-the-badge&color=yellow" alt="Stars" />
    </a>
    <a href="https://github.com/gtxPrime/arrow-out/network/members">
      <img src="https://img.shields.io/github/forks/gtxPrime/arrow-out?style=for-the-badge&color=orange" alt="Forks" />
    </a>
    <a href="https://github.com/gtxPrime/arrow-out/issues">
      <img src="https://img.shields.io/github/issues/gtxPrime/arrow-out?style=for-the-badge&color=blue" alt="Issues" />
    </a>
    <a href="https://github.com/gtxPrime/arrow-out/blob/main/LICENSE">
      <img src="https://img.shields.io/badge/License-MIT-brightgreen?style=for-the-badge" alt="License" />
    </a>
    <a href="#">
      <img src="https://img.shields.io/badge/Platform-Flutter_|_Android_|_iOS-3DDC84?logo=flutter&logoColor=white&style=for-the-badge" alt="Platform" />
    </a>
    <a href="https://github.com/gtxPrime/arrow-out/releases/latest">
      <img src="https://img.shields.io/github/downloads/gtxPrime/arrow-out/total?label=Downloads&logo=github&style=for-the-badge&color=brightgreen" alt="GitHub Downloads" />
    </a>
  </p>

  <a href="https://github.com/gtxPrime/arrow-out/releases/latest">
    <img src="https://raw.githubusercontent.com/gtxprime/mind-mint/main/docs/assets/github_badge.png" height="96" alt="Get it on GitHub" />
  </a>

  <h3>
    <a href="#-features">Features</a>
    <span> | </span>
    <a href="#-tech-stack">Tech Stack</a>
    <span> | </span>
    <a href="#-project-structure">Project Structure</a>
    <span> | </span>
    <a href="#-installation">Installation</a>
    <span> | </span>
    <a href="#-monetization">Monetization</a>
  </h3>

</div>

---

## 🎮 About Arrow Out

> [!NOTE]
> **Arrow Out** is a beautifully designed, highly interactive grid-based puzzle game. Players navigate challenges by sliding arrows out of the grid, encountering progressively harder difficulties (from Easy up to Boss & Super Hard levels). Developed using the powerful Flame game engine for Flutter, it offers responsive animations, particle effects, and dynamic transitions.

---

## <a id="-features"></a>🚀 Core Features

### 🧩 Engaging Gameplay
* 🔄 **Slide Mechanics:** Smooth grid movements with intuitive touch controls.
* 📈 **Progressive Difficulty:** Levels ranging from simple tutorial-like grids to mind-bending Boss and Super Hard configurations (up to 500 levels).
* 🟢🔴🔵 **Deflector Dots (Orphan Dots):** Isolated cells remaining after generation are converted to deflectors. 
  * Starting levels ($\le 20$) feature neutral (grey) dots that arrows pass straight through.
  * Higher levels introduce red (clockwise/right) and blue (counter-clockwise/left) deflector dots.
* 🏆 **Daily Streaks:** Tracks user gameplay consistency and records daily play sessions.
* 💖 **Lives System:** Keep track of remaining lives with custom visual meters and animated indicators.

### 🎨 Visual & Sound Effects
* ✨ **Juicy Animations:** Utilizes `flutter_animate`, Confetti, and custom Lottie integrations for satisfying level-complete feedback.
* 🎵 **Soundtracks & SFX:** Rich audio feedback powered by `flame_audio` and `audioplayers` for sliding, matching, winning, and losing states.
* 💅 **Premium UI:** Designed with HSL-tailored colors, smooth gradients, and custom Nunito typography.

---

## <a id="-tech-stack"></a>🛠️ Tech Stack

- **Framework:** [Flutter](https://flutter.dev/) (SDK `>=3.0.0 <4.0.0`)
- **Game Engine:** [Flame Engine](https://flame-engine.org/) & [Flame Audio](https://github.com/flame-engine/flame/tree/main/packages/flame_audio)
- **State Management:** [Provider](https://pub.dev/packages/provider)
- **Animations:** [Flutter Animate](https://pub.dev/packages/flutter_animate), [Lottie](https://pub.dev/packages/lottie), [Confetti](https://pub.dev/packages/confetti)
- **Local Storage:** [Shared Preferences](https://pub.dev/packages/shared_preferences)
- **Typography & Icons:** [Google Fonts](https://pub.dev/packages/google_fonts), [Lucide Icons](https://pub.dev/packages/lucide_icons_flutter)

---

## <a id="-project-structure"></a>📂 Project Structure

```
lib/
├── core/                   # Application constants, theme colors, and helper functions
├── data/
│   ├── models/             # Game models (Level, Arrow, Grid cell representations)
│   └── repositories/       # Level state and user progress persistence
├── game/
│   ├── components/         # Flame Components (Grid, Arrows, Particle systems)
│   ├── arrow_puzzle_game.dart # Main Flame Game Controller
│   └── game_state.dart     # In-game state machine and progression handlers
├── screens/
│   ├── game_over/          # Game Over and retry logic
│   ├── main_menu/          # Main Menu, levels selector, and daily streak UI
│   └── play_screen/        # Main gameplay viewport wrapping the Flame widget
└── widgets/                # Reusable UI controls (e.g. LivesBar, ActionButton)
```

---

## <a id="-installation"></a>📥 Installation

Follow these instructions to run the game locally:

### 1. Prerequisites
- Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) (Ensure it is in your system `PATH`).
- Run `flutter doctor` to verify correct environment setup.

### 2. Setup Codebase
Clone this repository and fetch the dependencies:
```bash
git clone https://github.com/gtxPrime/arrow-out.git
cd arrow-out
flutter pub get
```

### 3. Run the Game
Ensure you have an active emulator or real device connected:
```bash
flutter run
```

### 4. Build Executables
* **Android APK:**
  ```bash
  flutter build apk --release
  ```
* **Android App Bundle (for Play Store publishing):**
  ```bash
  flutter build appbundle --release
  ```

---

## <a id="-monetization"></a>💰 Monetization & Configuration

### AdMob Integration
To configure your live ads, update `lib/core/constants.dart`:
- `admobAppIdAndroid` → Your Google AdMob App ID
- `admobBannerUnitId` → Your Banner Ad Unit ID
- `admobInterstitialUnitId` → Your Interstitial Ad Unit ID
- `admobRewardedUnitId` → Your Rewarded Video Ad Unit ID

Also update the `<meta-data>` in [AndroidManifest.xml](file:///f:/Source%20Codes/Arrow%20game/android/app/src/main/AndroidManifest.xml) with your AdMob App ID.

### Unity & Facebook Ads Mediation
- **Facebook Audience Network:** Set up your adapter through your AdMob Mediation setup. No extra code changes needed.
- **Unity Ads:** Get your Game ID from the Unity Dashboard, then update `AppConstants.unityGameId` and set `unityTestMode = false`.
