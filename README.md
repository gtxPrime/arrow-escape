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

## <img src="https://img.shields.io/badge/-About-FF5500?style=flat-square&logo=info&logoColor=white" align="center" /> About Arrow Out

> [!NOTE]
> **Arrow Out** is a beautifully designed, highly interactive grid-based puzzle game. Players navigate challenges by sliding arrows out of the grid, encountering progressively harder difficulties (from Easy up to Boss & Super Hard levels). Developed using the powerful Flame game engine for Flutter, it offers responsive animations, particle effects, and dynamic transitions.

---

## <a id="-features"></a><img src="https://img.shields.io/badge/-Features-9C27B0?style=flat-square&logo=sparkles&logoColor=white" align="center" /> Core Features

### <img src="https://img.shields.io/badge/-Gameplay-43A047?style=flat-square&logo=gamepad&logoColor=white" align="center" /> Engaging Gameplay
* ✦ **Slide Mechanics:** Smooth grid movements with intuitive touch controls.
* ✦ **Progressive Difficulty:** Levels ranging from simple tutorial-like grids to mind-bending Boss and Super Hard configurations (up to 500 levels).
* ✦ **Deflector Dots (Orphan Dots):** Isolated cells remaining after generation are converted to deflectors. 
  * Starting levels ($\le 20$) feature neutral (grey) dots that arrows pass straight through.
  * Higher levels introduce red (clockwise/right) and blue (counter-clockwise/left) deflector dots.
* ✦ **Daily Streaks:** Tracks user gameplay consistency and records daily play sessions.
* ✦ **Lives System:** Keep track of remaining lives with custom visual meters and animated, synchronized heart icons.
* ✦ **Timed Challenges:** God levels (after level 100) and Boss levels (after level 200) feature dynamic countdown timers. The duration scales with the difficulty and quantity of arrows. Resuming from a timeout via rewarded ads grants a dynamic extra time buffer matching the quantity of remaining arrows, coupled with an observer-driven auto-pause system for background/foreground transitions.

### <img src="https://img.shields.io/badge/-Juice-E040FB?style=flat-square&logo=sparkles&logoColor=white" align="center" /> Visual & Sound Effects
* ✦ **Juicy Animations:** Utilizes `flutter_animate`, Confetti, and custom Lottie integrations for satisfying level-complete feedback.
* ✦ **Soundtracks & SFX:** Rich audio feedback powered by `flame_audio` and `audioplayers` for sliding, matching, winning, and losing states.
* ✦ **Premium UI:** Designed with HSL-tailored colors, smooth gradients, and custom Nunito typography.

---

## <a id="-tech-stack"></a><img src="https://img.shields.io/badge/-Stack-007ACC?style=flat-square&logo=layers&logoColor=white" align="center" /> Tech Stack

- **Framework:** [Flutter](https://flutter.dev/) (SDK `>=3.0.0 <4.0.0`)
- **Game Engine:** [Flame Engine](https://flame-engine.org/) & [Flame Audio](https://github.com/flame-engine/flame/tree/main/packages/flame_audio)
- **State Management:** [Provider](https://pub.dev/packages/provider)
- **Animations:** [Flutter Animate](https://pub.dev/packages/flutter_animate), [Lottie](https://pub.dev/packages/lottie), [Confetti](https://pub.dev/packages/confetti)
- **Local Storage:** [Shared Preferences](https://pub.dev/packages/shared_preferences)
- **Typography & Icons:** [Google Fonts](https://pub.dev/packages/google_fonts), [Lucide Icons](https://pub.dev/packages/lucide_icons_flutter)

## <a id="-game-engine"></a><img src="https://img.shields.io/badge/-Engine-4CAF50?style=flat-square&logo=cpu&logoColor=white" align="center" /> Game Engine & Level Generation

The game leverages the **Flame Engine** (a modular Flutter game engine library) to manage high-frequency rendering ticks, touch gestures, physics simulation, and particles.

### <img src="https://img.shields.io/badge/-Loop-607D8B?style=flat-square&logo=settings&logoColor=white" align="center" /> Game Loop & Engine Flow
The game loop runs on a dual-phase execution tick:
1. **Update Phase (`update(double dt)`)**: Evaluates real-time animations (e.g. arrow slide offsets, rotation angles, particle decay times) and updates the logical coordinate grid in `GameState`.
2. **Render Phase (`render(Canvas canvas)`)**: Draws grid cells, deflector plates, standard arrows, and particle effects directly onto the double-buffered screen canvas.

### <img src="https://img.shields.io/badge/-Pipeline-E91E63?style=flat-square&logo=git-commit&logoColor=white" align="center" /> The Level Generation Pipeline
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

### <img src="https://img.shields.io/badge/-Level_Data-1565C0?style=flat-square&logo=database&logoColor=white" align="center" /> Level Data Asset (`assets/levels.bin`)

Boss and God levels use large 30×30 grids with up to 200 arrows — generating them on-device causes freezes. All 500 levels are pre-generated on PC and shipped as a single compact binary file (`assets/levels.bin`, **791 KB**).

The binary format uses:
- **Bitmask grid masks** — 113 bytes per 30×30 grid instead of hundreds of coordinate strings
- **Delta-encoded arrow paths** — 1 byte per step instead of full `[row, col]` pairs
- **Index table** — O(1) seek to any level by number, no scanning

```
[HEADER]       8 bytes   magic 'LVLB' + version + level count
[INDEX TABLE]  N × 4 bytes  byte offset of each level record
[DATA]         per level: gridSize, maskShape, difficulty, patternName,
               arrows (direction/mechanic/path as delta steps),
               mask bitmask, orphan dots
```

`LevelRepository` loads only the header on startup and seeks directly to whichever level is needed — the rest of the file is untouched.

#### Regenerating & Verifying `levels.bin`

To verify all 500 levels and regenerate any unsolvable ones, run the parallel check-and-fix pipeline. This splits the work across 5 parallel processes on multiple CPU cores:
```bash
powershell -ExecutionPolicy Bypass -File .\run_parallel.ps1
```
This script will spawn the concurrent jobs, optimize their priorities to High, display live progress logs, and automatically merge and spot-verify the final output file `assets/levels.bin`.


#### Scaling to more levels
1. Change `const totalLevels = 500` → your new count in `test/generate_and_verify_test.dart`
2. Update `static int get totalLevels => 500` in `lib/data/repositories/level_repository.dart`
3. Re-run the generator — the index table grows automatically



### <img src="https://img.shields.io/badge/-Components-3F51B5?style=flat-square&logo=navigation&logoColor=white" align="center" /> Arrow Definition & Components
Arrows are modeled in `ArrowModel` and rendered by `ArrowComponent`:
- **Logical Model (`ArrowModel`)**: Defines the ID, head cell coordinate `(row, col)`, exit direction `ArrowDirection` (up, down, left, right), coordinate segment list (`path`), state (idle, sliding, blocked, exited), and color-locked grouping ID.
- **Visual Component (`ArrowComponent`)**: Standard arrows are drawn with a curved head, distinct segment separators, and a flat tail. They automatically compute slide offsets and orientation rotations dynamically during slide transitions.

### <img src="https://img.shields.io/badge/-Math-FF5722?style=flat-square&logo=maths&logoColor=white" align="center" /> Algorithmic Mechanics

The generator models the puzzle constraints mathematically to guarantee solvable and challenging states:

#### 1. Dynamic Grid Scaling
The board dimensions grow dynamically as a function of the level number:
$$\text{Grid Size } (G) = \text{clamp}\Big(10, \,\, 10 + \big\lfloor (L - 3) \times 0.115 \big\rfloor, \,\, 30\Big)$$
where $L$ represents the level number.

#### 2. Deflector Density (Orphan Bounds)
The target quantity of deflector dots is computed as a percentage of the total active mask area ($M$) and is capped:
$$E_{\text{max}} = \text{clamp}\Big(5, \,\, \lceil M \times P \rceil, \,\, 150\Big)$$
where the density coefficient $P$ scales based on grid dimensions:
$$P = \begin{cases} 16\% & \text{if } G > 20 \\ 22\% & \text{if } G \le 20 \end{cases}$$

#### 3. Arrow Type Distributions
The arrow lengths follow a discrete target ratio among standard paths ($\text{Length} \ge 3$):
- **Medium Arrows** ($3 \le \text{Length} \le 5$): $\approx 65\%$
- **Long Arrows** ($\text{Length} \ge 6$): $\approx 35\%$

#### 4. Solvability Constraints
A board state $S = (A, D)$ is solvable if there exists a valid slide sequence $\pi$:
$$\pi = (a_1, a_2, \dots, a_N) \in \text{Permutations}(A) \quad \text{s.t.} \quad \forall i, \,\, a_i \xrightarrow{\text{slide}} \text{Exit}(G, D_{i-1})$$
where $D_{i-1}$ represents the remaining deflector dot configurations on the grid after removing $a_1 \dots a_{i-1}$.

---

## <a id="-project-structure"></a><img src="https://img.shields.io/badge/-Structure-FFC107?style=flat-square&logo=folder-tree&logoColor=white" align="center" /> Project Structure

```
lib/
├── core/                      # App constants, theme colors, helper functions
├── data/
│   ├── level_binary_codec.dart  # Binary encoder/decoder for levels.bin
│   ├── models/                # Game models (Level, Arrow, OrphanDot, etc.)
│   ├── level_generator/       # Procedural generator, solver, mask shapes
│   └── repositories/          # Level access (binary asset) & user progress
├── game/
│   ├── components/            # Flame Components (Grid, Arrows, Particles)
│   ├── arrow_puzzle_game.dart # Main Flame Game Controller
│   └── game_state.dart        # In-game state machine and progression handlers
├── screens/
│   ├── game_over/             # Game Over and retry logic
│   ├── main_menu/             # Main Menu, level selector, daily streak UI
│   └── play_screen/           # Main gameplay viewport wrapping the Flame widget
└── widgets/                   # Reusable UI controls (LivesBar, ActionButton…)

assets/
└── levels.bin                 # Pre-generated binary level data (791 KB, 500 levels)

test/
├── generate_levels_bin_test.dart  # PC generator → writes assets/levels.bin
└── binary_codec_test.dart         # Round-trip encode/decode verification
```

---

## <a id="-installation"></a><img src="https://img.shields.io/badge/-Install-E91E63?style=flat-square&logo=download&logoColor=white" align="center" /> Installation

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

## <a id="-monetization"></a><img src="https://img.shields.io/badge/-Revenue-009688?style=flat-square&logo=dollar-sign&logoColor=white" align="center" /> Monetization & Configuration

The game features an integrated 3-level waterfall fallback ad system: **Google AdMob (Priority 1) -> AppLovin MAX (Priority 2) -> Unity Ads (Priority 3)**.

By default, only **AppLovin MAX** is enabled, and other networks are disabled via developer-friendly feature toggles in `lib/core/constants.dart`.

### Feature Toggles
You can dynamically toggle any of the integrated ad networks on/off using the following constants in `AppConstants`:
- `enableAppLovin` (default: `true`): Set to `true` to active AppLovin MAX ads.
- `enableAdMob` (default: `false`): Set to `true` to active Google AdMob ads.
- `enableUnityAds` (default: `false`): Set to `true` to active Unity Ads.

### Ad Unit Configuration
Update the corresponding unit and app identifiers in `lib/core/constants.dart` for your production ad units:

#### 1. AppLovin MAX Setup
- `applovinSdkKey`: Your unique AppLovin SDK key.
- `applovinBannerAdId`: AppLovin Banner Ad Unit ID.
- `applovinInterstitialAdId`: AppLovin Interstitial Ad Unit ID.
- `applovinRewardedAdId`: AppLovin Rewarded Ad Unit ID.
*Note: Make sure to add your AppLovin SDK key in your `<meta-data>` inside your `AndroidManifest.xml` if compiling for Android.*

#### 2. Google AdMob Setup
- `admobAppIdAndroid`: Google AdMob App ID.
- `admobBannerUnitId`: AdMob Banner Ad Unit ID.
- `admobInterstitialUnitId`: AdMob Interstitial Ad Unit ID.
- `admobRewardedUnitId`: AdMob Rewarded Ad Unit ID.
*Note: Also update the `<meta-data>` tag in [AndroidManifest.xml](file:///f:/Source%20Codes/Arrow%20game/android/app/src/main/AndroidManifest.xml) with your live AdMob App ID.*

#### 3. Unity Ads Setup
- `unityGameId`: Your Unity Game ID.
- `unityBannerAdId`: Unity Banner Placement ID (default: `'Banner_Android'`).
- `unityInterstitialAdId`: Unity Interstitial Placement ID (default: `'Interstitial_Android'`).
- `unityRewardedAdId`: Unity Rewarded Placement ID (default: `'Rewarded_Android'`).
- `unityTestMode`: Set to `false` for live production ads.

---

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=gtxPrime/arrow-out&type=Date)](https://star-history.com/#gtxPrime/arrow-out&Date)

