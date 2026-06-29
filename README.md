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
    <a href="#-game-engine">Game Engine</a>
    <span> | </span>
    <a href="#-project-structure">Project Structure</a>
    <span> | </span>
    <a href="#-installation">Installation</a>
    <span> | </span>
    <a href="#-monetization">Monetization</a>
  </h3>

</div>

---

## <img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/info.svg" width="20" height="20" align="center" /> About Arrow Out

> [!NOTE]
> **Arrow Out** is a beautifully designed, highly interactive grid-based puzzle game. Players navigate challenges by sliding arrows out of the grid, encountering progressively harder difficulties (from Easy up to Boss & Super Hard levels). Developed using the powerful Flame game engine for Flutter, it offers responsive animations, particle effects, and dynamic transitions.

---

## <a id="-features"></a><img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/sparkles.svg" width="20" height="20" align="center" /> Core Features

### <img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/gamepad-2.svg" width="18" height="18" align="center" /> Engaging Gameplay
* <img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/move-horizontal.svg" width="14" height="14" align="center" /> **Slide Mechanics:** Smooth grid movements with intuitive touch controls.
* <img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/trending-up.svg" width="14" height="14" align="center" /> **Progressive Difficulty:** Levels ranging from simple tutorial-like grids to mind-bending Boss and Super Hard configurations (up to 500 levels).
* <img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/compass.svg" width="14" height="14" align="center" /> **Deflector Dots (Orphan Dots):** Isolated cells remaining after generation are converted to deflectors. 
  * Starting levels ($\le 20$) feature neutral (grey) dots that arrows pass straight through.
  * Higher levels introduce red (clockwise/right) and blue (counter-clockwise/left) deflector dots.
* <img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/calendar-days.svg" width="14" height="14" align="center" /> **Daily Streaks:** Tracks user gameplay consistency and records daily play sessions.
* <img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/heart.svg" width="14" height="14" align="center" /> **Lives System:** Keep track of remaining lives with custom visual meters and animated indicators.

### <img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/palette.svg" width="18" height="18" align="center" /> Visual & Sound Effects
* <img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/sparkles.svg" width="14" height="14" align="center" /> **Juicy Animations:** Utilizes `flutter_animate`, Confetti, and custom Lottie integrations for satisfying level-complete feedback.
* <img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/music.svg" width="14" height="14" align="center" /> **Soundtracks & SFX:** Rich audio feedback powered by `flame_audio` and `audioplayers` for sliding, matching, winning, and losing states.
* <img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/paintbrush.svg" width="14" height="14" align="center" /> **Premium UI:** Designed with HSL-tailored colors, smooth gradients, and custom Nunito typography.

---

## <a id="-tech-stack"></a><img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/layers.svg" width="20" height="20" align="center" /> Tech Stack

- **Framework:** [Flutter](https://flutter.dev/) (SDK `>=3.0.0 <4.0.0`)
- **Game Engine:** [Flame Engine](https://flame-engine.org/) & [Flame Audio](https://github.com/flame-engine/flame/tree/main/packages/flame_audio)
- **State Management:** [Provider](https://pub.dev/packages/provider)
- **Animations:** [Flutter Animate](https://pub.dev/packages/flutter_animate), [Lottie](https://pub.dev/packages/lottie), [Confetti](https://pub.dev/packages/confetti)
- **Local Storage:** [Shared Preferences](https://pub.dev/packages/shared_preferences)
- **Typography & Icons:** [Google Fonts](https://pub.dev/packages/google_fonts), [Lucide Icons](https://pub.dev/packages/lucide_icons_flutter)

## <a id="-game-engine"></a><img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/cpu.svg" width="20" height="20" align="center" /> Game Engine & Level Generation

The game leverages the **Flame Engine** (a modular Flutter game engine library) to manage high-frequency rendering ticks, touch gestures, physics simulation, and particles.

### <img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/settings.svg" width="16" height="16" align="center" /> Game Loop & Engine Flow
The game loop runs on a dual-phase execution tick:
1. **Update Phase (`update(double dt)`)**: Evaluates real-time animations (e.g. arrow slide offsets, rotation angles, particle decay times) and updates the logical coordinate grid in `GameState`.
2. **Render Phase (`render(Canvas canvas)`)**: Draws grid cells, deflector plates, standard arrows, and particle effects directly onto the double-buffered screen canvas.

### <img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/git-commit.svg" width="16" height="16" align="center" /> The Level Generation Pipeline
Every level is fully generated programmatically and deterministically from a level number seed:

```mermaid
graph TD
    A["Seeded Random (levelNumber)"] --> B["Shape Selection & Mask Generation"]
    B --> C["Phase 1 & 2: Grow Long/Medium Arrows (exit inward)"]
    C --> D["Phase 3: Pack Remaining Space (Length-2 pairs)"]
    D --> E["Phase 4: Assign Safe Deflector Directions (reverse-trace)"]
    E --> F["Phase 5: Apply Mechanics (ColorLock groups)"]
    F --> G["Level Verification via Backtracking Solver (DFS)"]
    G -- "Unsolvable / Cap Hit" --> A
    G -- "Verified Solvable" --> H["Accept Level Model"]
```

- **Seeded Randomness**: Uses `Random(levelNumber * 103 + 51)` to produce identical layouts for a given level ID across all player devices.
- **Inward Growth (Phases 1 & 2)**: Starts by finding exit boundary cells and growing arrow paths inward. This guarantees that at least a subset of arrows can exit without obstructions.
- **Length-2 Packing (Phase 3)**: Sweeps remaining isolated tiles using a center-out shuffled search grid, preventing clustering of small arrows.
- **Reverse Exit Deflector Routing (Phase 4)**: Unassigned orphan cells are converted to redirect dots. The generator simulates arrow exits in reverse construction order and configures deflection directions that guarantee a safe path to the grid boundaries.
- **Solver Backtracking DFS Verification**: A custom depth-first search solver parses the generated board. The layout is accepted only if it solves within a dynamic state cap (1000 states for small grids, 2500 states for grids larger than 20x20). Otherwise, it resets the seed and restarts generation.

### <img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/navigation.svg" width="16" height="16" align="center" /> Arrow Definition & Components
Arrows are modeled in `ArrowModel` and rendered by `ArrowComponent`:
- **Logical Model (`ArrowModel`)**: Defines the ID, head cell coordinate `(row, col)`, exit direction `ArrowDirection` (up, down, left, right), coordinate segment list (`path`), state (idle, sliding, blocked, exited), and color-locked grouping ID.
- **Visual Component (`ArrowComponent`)**: Standard arrows are drawn with a curved head, distinct segment separators, and a flat tail. They automatically compute slide offsets and orientation rotations dynamically during slide transitions.

---

## <a id="-project-structure"></a><img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/folder-tree.svg" width="20" height="20" align="center" /> Project Structure

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

## <a id="-installation"></a><img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/download.svg" width="20" height="20" align="center" /> Installation

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

## <a id="-monetization"></a><img src="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/dollar-sign.svg" width="20" height="20" align="center" /> Monetization & Configuration

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
