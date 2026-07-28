# Arrow Escape — Complete Level Generation System Prompt

Paste this entire prompt to any AI coding assistant. It is fully self-contained.

> **Platform context**: The game client is built with **Flutter / Dart**. The level generator itself (this file) is a Python build-time tool — it runs offline and produces `.bin` batch files. The Dart game client reads those `.bin` files directly at runtime. No Python runs on-device. When the AI implementing this prompt writes the Dart-side binary reader, it must match the encoder in Section 8 exactly (little-endian, `u16` for `num_cells`, etc.).

---

## THE PROMPT

---

You are building the complete, production-ready level generation system for a mobile puzzle game called **Arrow Escape**. Read every section before writing any code. Implement exactly what is specified — do not summarise, skip, or assume.

---

### 1. GAME RULES

#### 1.1 The Grid

A level is a set of valid cells forming a specific shape (see Section 3). Each cell is either empty or occupied by part of an arrow. Cells outside the shape do not exist — arrows cannot enter or exit through them.

#### 1.2 Arrows

- An arrow occupies a **self-avoiding path** of cells (its *body*). The path may bend freely — changing direction (UP/DOWN/LEFT/RIGHT) at any cell. There is no limit on the number of bends.
- The body has a **tail** (start) and a **head** (end). The **head determines the arrow's exit direction**: the direction of the last step taken to reach the head cell.
- **Self-avoiding rule**: no cell may appear twice in a body, and the path may never reverse 180° into itself at any step (i.e. no U-turn back along the same segment). This prevents the arrow's body from looping into its own cells.
- An arrow **fires** when every cell between its head and the nearest valid shape boundary (in the head's exit direction) is empty. "Between" = cells in front of the head, not including the head cell itself, stopping at the first cell that is outside the shape.
- When an arrow fires it leaves the grid entirely. All its cells become empty.
- The player taps an arrow to fire it.
- **If the player taps an arrow whose exit path is blocked: one life is lost.** The arrow does not move. The player starts each level with **3 lives**. Losing all 3 lives = level failed, restart.

#### 1.3 Color Pair Arrows

- Two arrows share a color. Tapping either fires both simultaneously — only if BOTH have clear exits at that moment.
- If either partner is blocked, tapping costs one life and neither fires.

#### 1.4 Direction-Changing Dots

- A dot occupies one cell, has a rotation: 90° or 270° clockwise.
- When a firing arrow's head enters a dot cell, the arrow's direction rotates by that amount.
- The dot is consumed after one use.
- After turning, the arrow immediately attempts to exit in the new direction. If the new exit is clear, it fires. If not, the arrow halts mid-grid in its new orientation (valid stuck state).

#### 1.5 Level Types — Three Distinct Types

There are exactly three level types. They differ in grid shape, difficulty, and timing rules.

**NORMAL levels**
- Grid shape: rectangle or square (mostly square).
- Standard rules, no time limit at any level number.
- Difficulty scales through arrow count, length, and tangle depth.

**BOSS levels**
- Grid shape: always non-rectangular, never square/rectangle (see Section 3.2). Chosen from a library of **25 geometric/angular shapes** — plus-sign, diamond, T, L, H, U, Z, X-cross, arrows (all 4 directions), pentagon, octagon, hexagon, trapezoid, parallelogram, staircase, chevron, zigzag, lightning bolt, star (4-point), pinwheel, windmill, gear, and more.
- Significantly harder than normal: more arrows, longer arrows, deeper tangle chains, more dots.
- Level number ≤ 100: no time limit.
- Level number > 100: time limit applies (see Section 4 config).
- Appear at fixed intervals (every 10 levels starting at level 10: 10, 20, 30 … or as configured).
- **No-repeat rule**: the same shape must not be reused within the last 5 Boss levels, unless the entire pool has been exhausted (see Section 3.4).

**GOD levels**
- Grid shape: always a complex decorative/pictorial shape, never square/rectangle (see Section 3.3). Chosen from a library of **24 decorative shapes** — globe, star (5-point), teddy bear, butterfly, heart, crown, tree, flower, spinning top, candy/lollipop, ice-cream cone, crescent moon, gift box, anchor, shield, rocket, sun, cloud, umbrella, key, bowtie, gem, snowflake, fish, and more.
- Hardest levels. Deeper tangle, more features, tightest time pressure.
- Level number ≤ 200: no time limit.
- Level number > 200: time limit applies (see Section 4 config).
- Appear at fixed intervals (every 25 levels starting at level 25: 25, 50, 75 … or as configured).
- **No-repeat rule**: the same shape must not be reused within the last 5 God levels, unless the entire pool has been exhausted (see Section 3.4).
- God level ALL arrows on grid move simultaneously when any arrow is tapped (whether it fires or not). Every currently-fireable arrow fires. Non-fireable arrows stay (and cost a life if tapped directly in some variants — implement the simultaneous-move rule only).

#### 1.6 Win / Lose

- **Win**: all arrows have left the grid.
- **Lose**: all 3 lives lost, OR time limit reached (where applicable).
- **Invalid state** (must never occur in generated levels): a configuration where no arrow can ever fire regardless of tap order (full deadlock).

#### 1.7 Tutorial Levels & Mechanic-Introduction Schedule

Levels 1–3 are **hand-authored tutorial levels**, not randomly generated. Each teaches exactly one mechanic and contains **2–3 arrows only** (no more), all of the type being taught — never mix in a mechanic that hasn't been introduced yet.

- **Level 1 — Tap to fire.** 2–3 solo arrows, no pairs, no dots. Layout must be forgiving: at least one arrow is immediately fireable the moment the level opens, and if there's a second/third arrow it should become fireable right after (a very shallow, obvious tangle at most — this is about teaching the tap gesture and the "blocked = life lost" consequence, not about puzzle depth).
- **Level 2 — Color pairs.** 2–3 arrows: exactly one color pair (2 arrows sharing a color), plus optionally one solo arrow for contrast. Teaches that tapping either partner fires both, and that both must be clear.
- **Level 3 — Direction-changing dots.** 2–3 arrows: exactly one arrow that passes through a direction-changing dot, plus optionally 1–2 plain arrows. Teaches the turn mechanic in isolation (no pairs here).

**Levels 4–15 (NORMAL type): arrows only.** No color pairs, no direction-changing dots (`num_pairs=0`, `num_dots=0`) for every level in this range, regardless of level type overrides. Difficulty ramps purely through arrow count, arrow length, and tangle depth (how many arrows must fire before a given arrow clears). This holds even for a Boss level that happens to fall at level 10 — see the override in Section 4.

**Level 16 onward: mechanics unlock gradually.** Color pairs and direction-changing dots start appearing from level 16, beginning at low counts (e.g. a single pair or dot every few levels) and increasing in frequency/count as level number grows, per the scaling formulas in Section 4. Boss (from level 20 onward, see 4's override) and God levels layer in more of both, faster.

---

### 2. DATA STRUCTURES

Use these exact structures. Do not alter field names.

```python
from dataclasses import dataclass, field
from typing import List, Tuple, Optional, Dict, Set
from enum import Enum
import json, hashlib, random, struct, os, math
from collections import deque

class Direction(Enum):
    UP    = (0, -1)
    DOWN  = (0,  1)
    LEFT  = (-1, 0)
    RIGHT = (1,  0)

class LevelType(Enum):
    NORMAL = "normal"
    BOSS   = "boss"
    GOD    = "god"

@dataclass
class Dot:
    col: int
    row: int
    rotation: int          # 90 or 270

@dataclass
class Arrow:
    id: str                          # "arr_001"
    cells: List[Tuple[int,int]]      # ordered tail→head, each (col, row)
                                     # cells form a SELF-AVOIDING PATH — bends allowed,
                                     # no cell may repeat, no 180° reversal (U-turn into self).
                                     # The path may change direction (UP/DOWN/LEFT/RIGHT)
                                     # at any cell; there is no limit on number of bends.
    direction: Direction             # direction of the FINAL segment (head's facing direction)
                                     # this is what determines the arrow's exit corridor.
    color: Optional[str] = None      # None = solo; string = pair group id
    layer: int = 0                   # placement order index (internal, not saved)

    @property
    def head(self) -> Tuple[int,int]:
        return self.cells[-1]

    @property
    def tail(self) -> Tuple[int,int]:
        return self.cells[0]

    @property
    def length(self) -> int:
        return len(self.cells)

@dataclass
class Level:
    level_number: int
    level_type: LevelType
    shape_name: str                  # e.g. "square_7x7", "star_9", "butterfly_11"
    valid_cells: List[Tuple[int,int]]  # all cells that belong to this shape
    bounding_cols: int               # width of bounding box
    bounding_rows: int               # height of bounding box
    arrows: List[Arrow]
    dots: List[Dot]
    solution_order: List[str]        # arrow ids in exact firing order
    time_limit_seconds: Optional[int] = None
    is_god_level: bool = False       # convenience flag
    is_boss_level: bool = False      # convenience flag
    is_tutorial_level: bool = False  # convenience flag, True for level_number 1-3
    difficulty_score: int = 0
    seed: int = 0
    lives: int = 3
```

---

### 3. SHAPE LIBRARY

Shapes are defined as sets of (col, row) cells within a bounding box, same as before. **What changed from the prior version of this prompt: Boss and God shapes are no longer hand-coded math formulas. They are rasterized from real SVG artwork files (yours and open-source/CC0 icon assets) onto the dot grid.** Normal levels stay plain rectangles/squares — no SVG needed there.

#### 3.1 Normal Level Shapes (rectangles / squares — unchanged)

```python
def shape_square(size: int) -> List[Tuple[int,int]]:
    return [(c, r) for r in range(size) for c in range(size)]

def shape_rectangle(cols: int, rows: int) -> List[Tuple[int,int]]:
    return [(c, r) for r in range(rows) for c in range(cols)]
```

#### 3.2 SVG Asset Pipeline (Boss & God shapes)

**Where files live**: `assets/shapes/boss/*.svg` and `assets/shapes/god/*.svg` — one SVG per shape, filename (minus extension) = shape's base name, e.g. `assets/shapes/god/butterfly.svg` → `"butterfly"`.

Populate `boss/` with ~25 clean geometric silhouettes (plus, diamond, T, L, H, U, Z, X-cross, star4, pentagon, hexagon, octagon, trapezoid, parallelogram, staircase, chevron, zigzag, lightning, pinwheel, windmill, gear, arrow-up/down/left/right) and `god/` with ~24 decorative silhouettes (butterfly, heart, teddy bear, crown, tree, flower, globe, star5, spinning top, lollipop, ice-cream cone, crescent moon, gift box, anchor, shield, rocket, sun, cloud, umbrella, key, bowtie, gem, snowflake, fish) — a mix of your own SVGs plus single-path, single-color, open-license icon assets (e.g. from a CC0/open-source icon set). **Requirement for every source SVG**: one solid filled silhouette, no stroke-only outlines, no multi-layer/multi-color art — a black shape on a transparent or white background. The pipeline only needs "inside vs. outside" the silhouette; anything fancier just adds noise when downsampled onto a sparse dot grid.

**Rasterization** happens at build time only — it is never shipped inside the game (see the updated Section 11 exception for offline-only libraries):

```python
# Build-time dependency, offline only.
# pip install cairosvg pillow
import cairosvg
from PIL import Image
import io

SHAPE_ASSET_DIRS = {
    LevelType.BOSS: "assets/shapes/boss",
    LevelType.GOD:  "assets/shapes/god",
}

def _load_svg_mask(svg_path: str, supersample: int = 512) -> Image.Image:
    """Render an SVG to a square grayscale bitmap. Bright pixel = inside silhouette."""
    png_bytes = cairosvg.svg2png(url=svg_path,
                                  output_width=supersample,
                                  output_height=supersample,
                                  background_color="black")
    return Image.open(io.BytesIO(png_bytes)).convert("L")

def rasterize_svg_to_grid(svg_path: str, size: int, threshold: int = 60) -> List[Tuple[int,int]]:
    """
    Sample the SVG silhouette onto a size×size dot grid. Each grid dot (c, r)
    samples the pixel at the centre of its cell in the supersampled bitmap;
    the dot counts as part of the shape if that pixel is brighter than
    `threshold` (i.e. inside the filled silhouette).
    """
    img = _load_svg_mask(svg_path)
    w, h = img.size
    pixels = img.load()
    cells = []
    for r in range(size):
        for c in range(size):
            px = int((c + 0.5) / size * w)
            py = int((r + 0.5) / size * h)
            if pixels[px, py] > threshold:
                cells.append((c, r))
    return cells
```

**Trim + fill-maximize** (this is the "no empty space" requirement — apply to every rasterized shape):

```python
def trim_and_maximize(cells: List[Tuple[int,int]]) -> Tuple[List[Tuple[int,int]], int, int]:
    """
    Crop the shape's bounding box tightly to its own silhouette so there's no
    wasted border of empty rows/cols — this maximises the filled-cell ratio
    inside the bounding box. It does NOT force zero empty cells inside the
    box: decorative silhouettes (a butterfly's waist, a star's inner points)
    have genuine concave gaps by nature of the artwork. Trim as hard as
    possible; accept the shape's natural gaps rather than distorting the
    silhouette to remove them. If, after trimming, filled-ratio is still
    unusually low (<35%), that's acceptable — the "fill the board" goal is a
    best-effort, not a hard requirement (see Section 1.7 / hard prohibitions).
    """
    if not cells:
        return cells, 0, 0
    min_c = min(c for c, r in cells); max_c = max(c for c, r in cells)
    min_r = min(r for c, r in cells); max_r = max(r for c, r in cells)
    trimmed = [(c - min_c, r - min_r) for c, r in cells]
    return trimmed, max_c - min_c + 1, max_r - min_r + 1
```

#### 3.3 Shape Manifest & Selector

```python
import os

def _discover_shapes(level_type: LevelType) -> Dict[str, str]:
    """{'butterfly': 'assets/shapes/god/butterfly.svg', ...} sorted by filename."""
    folder = SHAPE_ASSET_DIRS[level_type]
    out = {}
    for fname in sorted(os.listdir(folder)):
        if fname.lower().endswith(".svg"):
            out[fname[:-4]] = os.path.join(folder, fname)
    return out

BOSS_SHAPE_FILES = _discover_shapes(LevelType.BOSS)   # populate with >=20 .svg files
GOD_SHAPE_FILES  = _discover_shapes(LevelType.GOD)    # populate with >=20 .svg files

def select_shape(level_number: int, level_type: LevelType,
                 rng: random.Random,
                 recent_shape_names: Optional[List[str]] = None
                 ) -> Tuple[List[Tuple[int,int]], str, int, int]:
    """
    Returns (valid_cells, shape_name, bounding_cols, bounding_rows).
    Grid size scales with level number via canvas_size_for() (Section 4).
    Boss/God shapes are rasterized from SVG files; Normal stays a plain
    rectangle/square.
    """
    recent_shape_names = recent_shape_names or []
    size = canvas_size_for(level_number, level_type)

    if level_type == LevelType.NORMAL:
        if rng.random() < 0.2:
            cols = size; rows = size + rng.choice([-1, 1])
            return shape_rectangle(cols, rows), f"rect_{cols}x{rows}", cols, rows
        return shape_square(size), f"square_{size}x{size}", size, size

    files = BOSS_SHAPE_FILES if level_type == LevelType.BOSS else GOD_SHAPE_FILES
    pool = {name: path for name, path in files.items() if name not in recent_shape_names}
    if not pool:
        pool = files  # pool exhausted — allow a repeat this one pick only
    name = rng.choice(list(pool.keys()))
    raw_cells = rasterize_svg_to_grid(pool[name], size)
    cells, bcols, brows = trim_and_maximize(raw_cells)
    return cells, f"{name}_{size}", bcols, brows
```

**No-repeat rule** works exactly as before: `shape_history` (Section 9) tracks the last 5 base names per level type. Names are now `"{filename}_{size}"`, so the existing `shape_name.rsplit("_", 1)[0]` strip still works correctly.

**Fallback with no rasterization library available**: if `cairosvg`/`Pillow` truly can't be installed in the build environment, fall back to a small set of pure-stdlib parametric shape functions (simple polygons via the ray-casting `point_in_polygon` helper below) rather than blocking the generator entirely. This is a degraded fallback, not the primary path.

```python
def point_in_polygon(x: float, y: float, poly: list) -> bool:
    """Ray-casting algorithm — only needed by the stdlib fallback shapes."""
    n = len(poly)
    inside = False
    px, py = poly[-1]
    for qx, qy in poly:
        if ((qy > y) != (py > y)) and (x < (px - qx) * (y - qy) / (py - qy + 1e-12) + qx):
            inside = not inside
        px, py = qx, qy
    return inside
```

---

### 4. LEVEL CONFIGURATION

**What changed from the prior version of this prompt:**
1. Levels 1–3 are tutorial levels with fixed, hand-authored configs (Section 1.7).
2. Levels 4–15 are forced arrows-only (`num_pairs=0`, `num_dots=0`) regardless of level type, even if a Boss level falls in that range (level 10 does — it becomes a "plain" Boss: bigger/harder shape, but no pairs or dots).
3. From level 16 onward, pairs/dots ramp up gradually rather than being present at full strength immediately.
4. Canvas size starts small and grows faster than before, reaching large boards by level 500+, with Boss bigger than Normal at the same level bracket and God bigger still.

```python
def is_tutorial_level(n: int) -> bool:
    return 1 <= n <= 3

def is_boss_level(n: int) -> bool:
    return n % 10 == 0   # every 10th level

def is_god_level(n: int) -> bool:
    return n % 25 == 0   # every 25th level (also divisible by 10, god takes priority)

def get_level_type(n: int) -> LevelType:
    # Tutorial levels (1-3) are LevelType.NORMAL under the hood — is_tutorial_level()
    # is the flag that actually matters for both config and construction (Section 5,
    # Phase 0). No new enum value, so the binary format (Section 8) needs no changes.
    if is_god_level(n):
        return LevelType.GOD
    if is_boss_level(n):
        return LevelType.BOSS
    return LevelType.NORMAL
```

#### 4.1 Canvas Size — small start, faster growth, bigger by type

```python
def canvas_size_for(level_number: int, level_type: LevelType) -> int:
    """
    Dot-grid side length for this level. Brackets chosen so boards grow
    noticeably faster than a linear crawl, reaching sizeable boards well
    before level 500, and so that at any given level number Boss > Normal
    and God > Boss.
    """
    n = level_number

    if is_tutorial_level(n):
        return 5  # small, fixed — tutorials are about the mechanic, not the board

    if level_type == LevelType.NORMAL:
        brackets = [(15, 5), (50, 6), (100, 7), (200, 8), (350, 9),
                    (500, 10), (700, 11), (900, 12)]
        default = 13
    elif level_type == LevelType.BOSS:
        # First Boss level is n=10, still inside the arrows-only window.
        brackets = [(15, 6), (50, 8), (100, 9), (200, 10), (350, 12),
                    (500, 14), (700, 16), (900, 18)]
        default = 20
    else:  # GOD
        # First God level is n=25.
        brackets = [(50, 9), (100, 11), (200, 13), (350, 15),
                    (500, 18), (700, 20), (900, 22)]
        default = 24

    for ceiling, size in brackets:
        if n <= ceiling:
            return size
    return default
```

#### 4.2 Arrow / Pair / Dot Config

```python
def get_level_config(level_number: int, level_type: LevelType) -> dict:
    n = level_number

    if is_tutorial_level(n):
        # Hand-authored, not randomly scaled — see build_tutorial_level() in Section 5.
        return dict(min_arrows=2, max_arrows=3, min_length=2, max_length=3,
                     num_pairs=(1 if n == 2 else 0),
                     num_dots=(1 if n == 3 else 0),
                     time_limit=None)

    base = {
        LevelType.NORMAL: dict(min_arrows=3, max_arrows=5, min_length=2, max_length=4,
                                target_pairs=1, target_dots=1),
        LevelType.BOSS:   dict(min_arrows=5, max_arrows=8, min_length=3, max_length=6,
                                target_pairs=2, target_dots=2),
        LevelType.GOD:    dict(min_arrows=8, max_arrows=13, min_length=3, max_length=8,
                                target_pairs=3, target_dots=3),
    }[level_type]
    # max_length above is the BASE cap; the actual per-level cap is computed by
    # pick_arrow_length() (Section 5, Phase 2) using the tiered distribution below.
    # These base values are still used for scaling calculations past level 100.

    config = dict(base)  # copy
    config['time_limit'] = None

    # --- Mechanic gate: arrows only through level 15, for every level type ---
    if n <= 15:
        config['num_pairs'] = 0
        config['num_dots'] = 0
    else:
        # Ramp target pairs/dots from 0 up to the type's target over levels 16-100.
        progress = min(1.0, (n - 16) / 84.0)
        config['num_pairs'] = round(config.pop('target_pairs') * progress)
        config['num_dots']  = round(config.pop('target_dots') * progress)

        # Continue scaling everything (including pairs/dots) past level 100,
        # same shape as the original formula.
        scale = min(n // 100, 5)
        config['max_arrows'] += scale
        config['max_length'] += scale // 2
        config['num_pairs']  += scale // 2
        config['num_dots']   += scale // 2

    config.pop('target_pairs', None)
    config.pop('target_dots', None)

    # HARD RULE: no arrow is ever a 1-dot arrow. min_length is never < 2 anywhere
    # in the system — enforced again here as a safety net regardless of the
    # values above.
    config['min_length'] = max(2, config['min_length'])

    # Time limits kick in at specific thresholds (unchanged from before)
    if level_type == LevelType.BOSS and n > 100:
        config['time_limit'] = max(60, 180 - (n - 100) // 5)
    if level_type == LevelType.GOD and n > 200:
        config['time_limit'] = max(45, 150 - (n - 200) // 5)

    return config
```

---

### 5. THE GENERATION ALGORITHM

#### Phase 0 — Tutorial Levels (1–3, hand-authored)

Tutorial levels are **not** produced by the random backwards-construction pipeline below — that pipeline is for procedurally-generated puzzle depth, which a tutorial deliberately avoids. Instead, each of the 3 tutorial levels is built directly from a small fixed layout that is guaranteed solvable and teaches exactly one mechanic (Section 1.7). `build_level()` checks for this case first and returns early.

**Tutorial arrows are straight (no bends).** Bent paths add visual complexity that would distract from the mechanic being taught. All hand-authored tutorial arrows have bodies that travel in a single direction from tail to head. This is the only place in the system where straight arrows are intentional; all procedurally generated levels (level 4+) use the bent-path builder.

```python
def build_tutorial_level(level_number: int, seed: int) -> Optional['Level']:
    config = get_level_config(level_number, LevelType.NORMAL)
    size = canvas_size_for(level_number, LevelType.NORMAL)
    valid_cells = shape_square(size)

    if level_number == 1:
        # Two solo arrows, both immediately fireable — pure tap-to-fire teaching.
        arrows = [
            Arrow(id="arr_000", cells=[(1, 2), (2, 2)], direction=Direction.RIGHT),
            Arrow(id="arr_001", cells=[(3, 0), (3, 1)], direction=Direction.DOWN),
        ]
        solution_order = ["arr_000", "arr_001"]
        dots: List[Dot] = []

    elif level_number == 2:
        # One color pair (fires together) plus one solo arrow for contrast.
        arrows = [
            Arrow(id="arr_000", cells=[(0, 4), (1, 4)], direction=Direction.RIGHT, color="red"),
            Arrow(id="arr_001", cells=[(4, 0), (4, 1)], direction=Direction.DOWN, color="red"),
            Arrow(id="arr_002", cells=[(2, 2), (2, 3)], direction=Direction.DOWN),
        ]
        solution_order = ["arr_002", "arr_000"]  # arr_001 fires alongside arr_000 (same color)
        dots = []

    else:  # level_number == 3
        # One arrow that turns through a direction-changing dot, plus one plain arrow.
        arrows = [
            Arrow(id="arr_000", cells=[(0, 2), (1, 2), (2, 2)], direction=Direction.RIGHT),
            Arrow(id="arr_001", cells=[(4, 0), (4, 1)], direction=Direction.DOWN),
        ]
        # Dot sits just past arr_000's head; turns it DOWN (90° CW from RIGHT) to exit south.
        dots = [Dot(col=3, row=2, rotation=90)]
        solution_order = ["arr_001", "arr_000"]

    level = Level(
        level_number=level_number, level_type=LevelType.NORMAL,
        shape_name=f"tutorial_{level_number}", valid_cells=valid_cells,
        bounding_cols=size, bounding_rows=size,
        arrows=arrows, dots=dots, solution_order=solution_order,
        time_limit_seconds=None, is_god_level=False, is_boss_level=False,
        is_tutorial_level=True, seed=seed, lives=3,
    )
    return level
```

**Note on level 2's coordinates**: `arr_001`'s exit corridor (upward off the top edge) is clear from the start, same as `arr_000`'s (rightward). Since they share a color, tapping either fires both — that's the point being taught. Adjust the concrete cells above only if a different `size` is chosen for the tutorial canvas; the *shape* of the teaching moment (which arrow is solo, which two share a color, which one owns the dot) must stay the same.

#### Phase 1 — Setup

```python
def build_level(level_number: int, seed: int,
                recent_shape_names: Optional[List[str]] = None) -> Optional['Level']:
    if is_tutorial_level(level_number):
        return build_tutorial_level(level_number, seed)

    rng = random.Random(seed)
    level_type = get_level_type(level_number)
    config = get_level_config(level_number, level_type)

    valid_cells, shape_name, bcols, brows = select_shape(
        level_number, level_type, rng, recent_shape_names=recent_shape_names)
    valid_set = set(valid_cells)

    if len(valid_cells) < config['min_arrows'] * config['min_length']:
        return None  # shape too small for requested arrows
```

#### Phase 2 — Backwards Construction

**The rule: build in reverse firing order. Arrow placed first = last to fire. This guarantees solvability. Never generate randomly and check solvability.**

##### 2A — Arrow Length Tiers

Each arrow's cell-count is sampled from a tiered distribution. The tiers are defined relative to the grid's side length (`G = canvas_size_for(level_number, level_type)`):

| Tier        | Cell count range          | Target share |
|-------------|---------------------------|--------------|
| Very long   | `G + 1` … `2 × G`        | ~35 %        |
| Long        | `G // 2 + 1` … `G`       | ~30 %        |
| Medium      | `3` … `G // 2`            | ~25 %        |
| Short       | `2` … `2`                 | ~10 %        |

**Important notes on the tiers:**
- "Target share" is a soft probability weight, not a hard cap. The generator should aim for this mix across a level's arrows but must never fail a placement attempt purely because it would upset the ratio — satisfying the self-avoiding path and blocking constraints always takes priority.
- Very long arrows (length > G) can only exist if the grid has enough free, connected cells for a bent path of that length. On small early grids this tier will naturally be underrepresented; that is expected and acceptable.
- Only 1–2 very-long arrows per level are attempted. If a very-long arrow cannot be placed after a reasonable number of attempts, fall back to the next tier rather than failing the whole level.
- `min_length` is always 2 (no 1-cell arrows anywhere).

```python
def pick_arrow_length(rng: random.Random, G: int) -> int:
    """
    Sample a length from the four-tier distribution.
    G = grid side length (canvas_size_for result).
    """
    tier = rng.choices(
        ["very_long", "long", "medium", "short"],
        weights=[35, 30, 25, 10]
    )[0]
    if tier == "very_long":
        lo = G + 1
        hi = 2 * G
        return rng.randint(lo, hi)
    elif tier == "long":
        lo = G // 2 + 1
        hi = G
        return rng.randint(max(2, lo), hi)
    elif tier == "medium":
        lo = 3
        hi = max(3, G // 2)
        return rng.randint(lo, hi)
    else:  # short
        return 2
```

##### 2B — Bent Self-Avoiding Path Builder

Arrow bodies are **self-avoiding paths**: they may change direction at any cell (UP/DOWN/LEFT/RIGHT), but:
1. No cell may appear more than once in the body.
2. No step may be the exact 180° reverse of the immediately preceding step (no U-turn back into the cell just left — this would place the path into a cell it already occupies, violating rule 1, and is explicitly forbidden).
3. The path stays entirely within `valid_cells` and may not enter any cell already in `occupancy`.

The `direction` field of the finished `Arrow` is the direction of the **last step** (i.e. the direction from `cells[-2]` to `cells[-1]`). This is the head's exit direction and defines its firing corridor.

```python
ALL_DIRS = list(Direction)
OPPOSITE = {
    Direction.UP:    Direction.DOWN,
    Direction.DOWN:  Direction.UP,
    Direction.LEFT:  Direction.RIGHT,
    Direction.RIGHT: Direction.LEFT,
}

def build_bent_path(start: Tuple[int,int],
                    target_length: int,
                    valid_set: Set[Tuple[int,int]],
                    occupancy: Dict[Tuple[int,int], str],
                    rng: random.Random) -> Optional[List[Tuple[int,int]]]:
    """
    Grow a self-avoiding path from `start` to exactly `target_length` cells.
    Returns the cell list (tail→head) or None if the path gets stuck before
    reaching the target length.

    Strategy: random walk with look-ahead. At each step, prefer directions
    that keep future options open (don't immediately dead-end). If all
    continuations are blocked, return None (caller will retry with a new start
    or a different length tier).
    """
    if start not in valid_set or start in occupancy:
        return None

    path = [start]
    visited = {start}
    last_dir: Optional[Direction] = None

    while len(path) < target_length:
        c, r = path[-1]
        # Candidate directions: all except 180° reverse of last step
        candidates = [d for d in ALL_DIRS
                      if last_dir is None or d != OPPOSITE[last_dir]]
        rng.shuffle(candidates)

        # Prefer directions that don't immediately trap us (look-ahead = 1)
        def free_neighbors(cell, excl_dir):
            nc, nr = cell
            count = 0
            for d in ALL_DIRS:
                if d == excl_dir:
                    continue
                dc2, dr2 = d.value
                nb = (nc + dc2, nr + dr2)
                if nb in valid_set and nb not in visited and nb not in occupancy:
                    count += 1
            return count

        candidates.sort(
            key=lambda d: free_neighbors(
                (c + d.value[0], r + d.value[1]),
                OPPOSITE[d]
            ),
            reverse=True  # most open neighbors first
        )

        placed = False
        for d in candidates:
            dc, dr = d.value
            nxt = (c + dc, r + dr)
            if nxt in valid_set and nxt not in visited and nxt not in occupancy:
                path.append(nxt)
                visited.add(nxt)
                last_dir = d
                placed = True
                break

        if not placed:
            return None  # path is stuck; caller retries

    return path
```

##### 2C — Arrow Placement Loop

```python
    occupancy: Dict[Tuple[int,int], str] = {}
    arrows: List[Arrow] = []
    placement_order: List[str] = []
    arrow_counter = 0
    G = canvas_size_for(level_number, level_type)

    def exit_corridor(arrow: Arrow) -> List[Tuple[int,int]]:
        """Cells from head+1 in arrow's head direction, stopping at shape boundary."""
        dc, dr = arrow.direction.value
        corridor = []
        c, r = arrow.head
        c += dc; r += dr
        while (c, r) in valid_set:
            corridor.append((c, r))
            c += dc; r += dr
        return corridor

    def is_fireable(arrow: Arrow) -> bool:
        return all(cell not in occupancy for cell in exit_corridor(arrow))

    very_long_placed = 0  # track how many very-long arrows have been placed this level

    def try_place_arrow(attempt_limit=400) -> bool:
        nonlocal arrow_counter, very_long_placed
        for _ in range(attempt_limit):
            # Sample length tier; suppress very-long after 2 are already placed
            # (soft limit — keeps levels playable on smaller grids)
            raw_tier_roll = rng.choices(
                ["very_long", "long", "medium", "short"],
                weights=[35, 30, 25, 10]
            )[0]
            if raw_tier_roll == "very_long" and very_long_placed >= 2:
                raw_tier_roll = "long"  # downgrade gracefully

            if raw_tier_roll == "very_long":
                target_len = rng.randint(G + 1, 2 * G)
            elif raw_tier_roll == "long":
                target_len = rng.randint(max(2, G // 2 + 1), G)
            elif raw_tier_roll == "medium":
                target_len = rng.randint(3, max(3, G // 2))
            else:
                target_len = 2

            target_len = max(2, target_len)  # hard floor

            start = rng.choice(valid_cells)
            cells = build_bent_path(start, target_len, valid_set, occupancy, rng)
            if cells is None or len(cells) < 2:
                continue

            # Direction = direction of the last step (cells[-2] → cells[-1])
            lc, lr = cells[-2]
            hc, hr = cells[-1]
            dc, dr = hc - lc, hr - lr
            head_dir = next(d for d in ALL_DIRS if d.value == (dc, dr))

            arrow_id = f"arr_{arrow_counter:03d}"
            candidate = Arrow(id=arrow_id, cells=cells, direction=head_dir)

            # Must be fireable NOW (exit corridor clear before future arrows block it)
            if not is_fireable(candidate):
                continue

            # For all arrows after the first: body must block at least one existing arrow
            if len(arrows) > 0:
                corridor_sets = {a.id: set(exit_corridor(a)) for a in arrows}
                body_set = set(cells)
                blocks_any = any(body_set & cs for cs in corridor_sets.values())
                if not blocks_any:
                    continue

            # Place it
            for cell in cells:
                occupancy[cell] = arrow_id
            arrows.append(candidate)
            placement_order.append(arrow_id)
            arrow_counter += 1
            if raw_tier_roll == "very_long":
                very_long_placed += 1
            return True
        return False

    num_arrows = rng.randint(config['min_arrows'], config['max_arrows'])
    for _ in range(num_arrows):
        if not try_place_arrow():
            return None  # construction failed

    solution_order = list(reversed(placement_order))
```

#### Phase 3 — Apply Features

```python
    # Pairs
    arrows = apply_pairs(arrows, config['num_pairs'], rng,
                         solution_order, valid_cells)

    # Dots
    dots = apply_dots(arrows, config['num_dots'], rng,
                      occupancy, solution_order, valid_set)

    level = Level(
        level_number=level_number,
        level_type=level_type,
        shape_name=shape_name,
        valid_cells=valid_cells,
        bounding_cols=bcols,
        bounding_rows=brows,
        arrows=arrows,
        dots=dots,
        solution_order=solution_order,
        time_limit_seconds=config['time_limit'],
        is_god_level=(level_type == LevelType.GOD),
        is_boss_level=(level_type == LevelType.BOSS),
        seed=seed,
        lives=3
    )

    return level
```

---

### 6. FEATURE HELPERS

```python
def apply_pairs(arrows, num_pairs, rng, solution_order, valid_cells):
    colors = ["red","blue","green","orange","pink","yellow","purple","cyan","lime","magenta"]
    arrow_map = {a.id: a for a in arrows}
    valid_set = set(valid_cells)
    used = 0
    # Pair consecutive arrows in solution_order (they fire at the same step)
    candidates = list(range(0, len(solution_order) - 1, 2))
    rng.shuffle(candidates)
    for idx in candidates:
        if used >= num_pairs:
            break
        a = arrow_map[solution_order[idx]]
        b = arrow_map[solution_order[idx + 1]]
        if zones_far_enough(a, b, valid_cells):
            color = colors[used % len(colors)]
            a.color = color
            b.color = color
            used += 1
    return list(arrow_map.values())


def apply_dots(arrows, num_dots, rng, occupancy, solution_order, valid_set):
    arrow_map = {a.id: a for a in arrows}
    dots = []
    placed = 0
    for arrow_id in solution_order:
        if placed >= num_dots:
            break
        arrow = arrow_map[arrow_id]
        dc, dr = arrow.direction.value
        corridor = []
        c, r = arrow.head
        c += dc; r += dr
        while (c, r) in valid_set:
            if (c, r) not in occupancy:
                corridor.append((c, r))
            c += dc; r += dr
        if len(corridor) < 2:
            continue
        dot_cell = rng.choice(corridor[:-1])
        rotation = rng.choice([90, 270])
        new_dir = rotate_direction(arrow.direction, rotation)
        ndc, ndr = new_dir.value
        nc, nr = dot_cell[0] + ndc, dot_cell[1] + ndr
        exit_clear = True
        while (nc, nr) in valid_set:
            if (nc, nr) in occupancy:
                exit_clear = False
                break
            nc += ndc; nr += ndr
        if exit_clear:
            dots.append(Dot(col=dot_cell[0], row=dot_cell[1], rotation=rotation))
            placed += 1
    return dots


def rotate_direction(d: Direction, degrees: int) -> Direction:
    order = [Direction.UP, Direction.RIGHT, Direction.DOWN, Direction.LEFT]
    return order[(order.index(d) + degrees // 90) % 4]


def zones_far_enough(a: Arrow, b: Arrow, valid_cells) -> bool:
    all_cols = [c for c, r in valid_cells]
    all_rows = [r for c, r in valid_cells]
    span_c = max(all_cols) - min(all_cols) + 1
    span_r = max(all_rows) - min(all_rows) + 1
    za = (a.head[0] * 3 // span_c, a.head[1] * 3 // span_r)
    zb = (b.head[0] * 3 // span_c, b.head[1] * 3 // span_r)
    dist = abs(a.head[0] - b.head[0]) + abs(a.head[1] - b.head[1])
    return za != zb and dist >= 2
```

---

### 7. VERIFICATION

```python
def verify_solution(level: Level) -> bool:
    """
    Simulate firing every arrow in solution_order and confirm all leave the grid.

    Bent-arrow note: `a.direction` is the direction of the last body segment
    (cells[-2] → cells[-1]). The exit corridor always extends from `a.head`
    in `a.direction` — identical to the straight-arrow case. The bent body
    itself does NOT need to be re-traced during simulation; only the head's
    exit corridor matters for the fireability check.
    """
    valid_set = set(level.valid_cells)
    occupancy: Dict[Tuple[int,int], str] = {}
    arrow_map: Dict[str, Arrow] = {}
    dot_map: Dict[Tuple[int,int], Dot] = {}

    for a in level.arrows:
        # Validate that `direction` matches the actual last step of the body
        if len(a.cells) >= 2:
            lc, lr = a.cells[-2]
            hc, hr = a.cells[-1]
            expected_dc, expected_dr = hc - lc, hr - lr
            assert a.direction.value == (expected_dc, expected_dr), (
                f"Arrow {a.id}: stored direction {a.direction} does not match "
                f"last body step ({expected_dc},{expected_dr})"
            )
        arrow_map[a.id] = a
        for cell in a.cells:
            occupancy[cell] = a.id
    for d in level.dots:
        dot_map[(d.col, d.row)] = d

    fired: Set[str] = set()

    def corridor(arrow_id: str) -> List[Tuple[int,int]]:
        """Exit corridor: cells in front of the head in its exit direction."""
        a = arrow_map[arrow_id]
        dc, dr = a.direction.value
        result = []
        c, r = a.head
        c += dc; r += dr
        while (c, r) in valid_set:
            result.append((c, r))
            c += dc; r += dr
        return result

    def fire(arrow_id: str) -> bool:
        if any(cell in occupancy for cell in corridor(arrow_id)):
            return False
        a = arrow_map[arrow_id]
        for cell in a.cells:
            del occupancy[cell]
        fired.add(arrow_id)
        return True

    for arrow_id in level.solution_order:
        a = arrow_map[arrow_id]
        if a.color:
            partners = [x.id for x in level.arrows
                        if x.color == a.color and x.id != arrow_id and x.id not in fired]
            for aid in [arrow_id] + partners:
                if not fire(aid):
                    return False
        else:
            if not fire(arrow_id):
                return False

    return len(fired) == len(level.arrows)


def score_level(level: Level) -> int:
    G = canvas_size_for(level.level_number, level.level_type)
    s = len(level.arrows) * 8
    for a in level.arrows:
        # Very long bent arrows (> G cells) score extra — they create deeper tangles
        if a.length > G:
            s += a.length * 5   # higher weight for very-long tier
        elif a.length > G // 2:
            s += a.length * 4   # long tier
        else:
            s += a.length * 3   # medium / short tier
    s += len(level.dots) * 15
    s += sum(1 for a in level.arrows if a.color) * 10
    s += len(level.solution_order) * 5
    s += (30 if level.is_god_level else 15 if level.is_boss_level else 0)
    return s


def fingerprint_level(level: Level) -> str:
    canonical = sorted([tuple(sorted(a.cells)) for a in level.arrows])
    return hashlib.md5(str(canonical).encode()).hexdigest()
```

---

### 8. BINARY OUTPUT FORMAT

**Do NOT store levels as JSON files. JSON is too large for 500–1000+ levels. Use a compact binary `.bin` file per batch. The game reads the binary directly. JSON is only for debugging.**

#### 8.1 Binary Encoding

```python
def encode_level_binary(level: Level) -> bytes:
    """
    Compact binary encoding. All integers little-endian.

    Header per level (fixed 16 bytes):
      u32  level_number
      u8   level_type  (0=normal, 1=boss, 2=god)
      u8   bounding_cols
      u8   bounding_rows
      u8   lives (always 3)
      u16  time_limit  (0 = no limit, else seconds)
      u16  num_valid_cells
      u8   num_arrows
      u8   num_dots
      u8   flags  bit0=is_god, bit1=is_boss
      u8   shape_name_len
      u32  difficulty_score

    shape_name: shape_name_len bytes UTF-8

    valid_cells: num_valid_cells × 2 bytes  (u8 col, u8 row)

    Per arrow:
      u8  id_len
      [id_len bytes]  arrow id UTF-8
      u16 num_cells                         ← u16 (not u8): bent arrows on large grids
                                              can have up to 2×G cells, exceeding 255
      [num_cells × 2 bytes]  (u8 col, u8 row)
      u8  direction  (0=UP,1=DOWN,2=LEFT,3=RIGHT)
      u8  color_len  (0 = no color)
      [color_len bytes]  color string UTF-8

    Per dot:
      u8  col
      u8  row
      u8  rotation  (90→1, 270→3)

    solution_order:
      u8  num_steps
      per step: u8 id_len, [id_len bytes]
    """
    buf = bytearray()
    DIR_MAP = {Direction.UP:0, Direction.DOWN:1, Direction.LEFT:2, Direction.RIGHT:3}

    tl = {LevelType.NORMAL:0, LevelType.BOSS:1, LevelType.GOD:2}[level.level_type]
    flags = (1 if level.is_god_level else 0) | (2 if level.is_boss_level else 0)
    tl_sec = level.time_limit_seconds or 0
    sname = level.shape_name.encode('utf-8')

    buf += struct.pack('<IBBBBHHBBBBl',
        level.level_number, tl,
        level.bounding_cols, level.bounding_rows,
        level.lives, tl_sec,
        len(level.valid_cells),
        len(level.arrows), len(level.dots),
        flags, len(sname),
        level.difficulty_score
    )
    buf += sname

    for col, row in level.valid_cells:
        buf += struct.pack('BB', col, row)

    for a in level.arrows:
        aid = a.id.encode('utf-8')
        # num_cells is u16 — bent arrows on large grids can exceed 255 cells
        buf += struct.pack('B', len(aid))
        buf += struct.pack('<H', len(a.cells))
        buf += aid
        for col, row in a.cells:
            buf += struct.pack('BB', col, row)
        color = (a.color or '').encode('utf-8')
        buf += struct.pack('BB', DIR_MAP[a.direction], len(color))
        buf += color

    for d in level.dots:
        rot_byte = 1 if d.rotation == 90 else 3
        buf += struct.pack('BBB', d.col, d.row, rot_byte)

    buf += struct.pack('B', len(level.solution_order))
    for arrow_id in level.solution_order:
        aid = arrow_id.encode('utf-8')
        buf += struct.pack('B', len(aid))
        buf += aid

    return bytes(buf)


def decode_level_binary(data: bytes, offset: int = 0) -> Tuple['Level', int]:
    """Decode one level from binary data starting at offset. Returns (level, new_offset)."""
    DIR_UNMAP = {0:Direction.UP, 1:Direction.DOWN, 2:Direction.LEFT, 3:Direction.RIGHT}
    TYPE_UNMAP = {0:LevelType.NORMAL, 1:LevelType.BOSS, 2:LevelType.GOD}

    o = offset
    (level_number, tl, bcols, brows, lives, tl_sec,
     num_valid, num_arrows, num_dots, flags,
     sname_len, difficulty_score) = struct.unpack_from('<IBBBBHHBBBBl', data, o)
    o += struct.calcsize('<IBBBBHHBBBBl')

    shape_name = data[o:o+sname_len].decode('utf-8'); o += sname_len

    valid_cells = []
    for _ in range(num_valid):
        col, row = struct.unpack_from('BB', data, o); o += 2
        valid_cells.append((col, row))

    arrows = []
    for _ in range(num_arrows):
        id_len = struct.unpack_from('B', data, o)[0]; o += 1
        # num_cells is u16 — matches encoder change for bent arrows
        num_cells = struct.unpack_from('<H', data, o)[0]; o += 2
        arrow_id = data[o:o+id_len].decode('utf-8'); o += id_len
        cells = []
        for _ in range(num_cells):
            col, row = struct.unpack_from('BB', data, o); o += 2
            cells.append((col, row))
        dir_byte, color_len = struct.unpack_from('BB', data, o); o += 2
        color = data[o:o+color_len].decode('utf-8') if color_len else None; o += color_len
        arrows.append(Arrow(id=arrow_id, cells=cells,
                            direction=DIR_UNMAP[dir_byte], color=color or None))

    dots = []
    for _ in range(num_dots):
        col, row, rot_byte = struct.unpack_from('BBB', data, o); o += 3
        dots.append(Dot(col=col, row=row, rotation=90 if rot_byte == 1 else 270))

    num_steps = struct.unpack_from('B', data, o)[0]; o += 1
    solution_order = []
    for _ in range(num_steps):
        id_len = struct.unpack_from('B', data, o)[0]; o += 1
        solution_order.append(data[o:o+id_len].decode('utf-8')); o += id_len

    level = Level(
        level_number=level_number,
        level_type=TYPE_UNMAP[tl],
        shape_name=shape_name,
        valid_cells=valid_cells,
        bounding_cols=bcols,
        bounding_rows=brows,
        arrows=arrows,
        dots=dots,
        solution_order=solution_order,
        time_limit_seconds=tl_sec if tl_sec > 0 else None,
        is_god_level=bool(flags & 1),
        is_boss_level=bool(flags & 2),
        difficulty_score=difficulty_score,
        lives=lives
    )
    return level, o
```

#### 8.2 Batch File Format

```python
def write_batch_bin(levels: List['Level'], filepath: str):
    """
    Batch file layout:
      u32  magic         = 0x4152525A  ("ARRZ")
      u32  version       = 1
      u32  batch_start   (first level_number in file)
      u32  batch_end     (last level_number in file)
      u32  num_levels
      [num_levels × u32]  byte offsets of each level from start of data section
      [encoded level data, concatenated]
    """
    MAGIC = 0x4152525A
    VERSION = 1
    if not levels:
        return

    encoded = [encode_level_binary(l) for l in levels]
    header_size = 5 * 4 + len(levels) * 4   # magic+ver+start+end+count + offsets

    offsets = []
    pos = 0
    for e in encoded:
        offsets.append(pos)
        pos += len(e)

    with open(filepath, 'wb') as f:
        f.write(struct.pack('<IIIII', MAGIC, VERSION,
                            levels[0].level_number, levels[-1].level_number,
                            len(levels)))
        for off in offsets:
            f.write(struct.pack('<I', off))
        for e in encoded:
            f.write(e)


def read_batch_bin(filepath: str) -> List['Level']:
    with open(filepath, 'rb') as f:
        data = f.read()
    magic, version, batch_start, batch_end, num_levels = struct.unpack_from('<IIIII', data, 0)
    assert magic == 0x4152525A, "Invalid batch file"
    header_size = 5 * 4 + num_levels * 4
    offsets = [struct.unpack_from('<I', data, 5*4 + i*4)[0] for i in range(num_levels)]
    levels = []
    for off in offsets:
        level, _ = decode_level_binary(data, header_size + off)
        levels.append(level)
    return levels


def level_to_debug_json(level: Level) -> str:
    """Human-readable JSON for debugging only. Never used in production."""
    d = {
        "level_number": level.level_number,
        "level_type": level.level_type.value,
        "shape_name": level.shape_name,
        "bounding": f"{level.bounding_cols}x{level.bounding_rows}",
        "valid_cell_count": len(level.valid_cells),
        "time_limit_seconds": level.time_limit_seconds,
        "is_god_level": level.is_god_level,
        "is_boss_level": level.is_boss_level,
        "difficulty_score": level.difficulty_score,
        "lives": level.lives,
        "solution_order": level.solution_order,
        "arrows": [{"id": a.id, "cells": a.cells,
                    "direction": a.direction.name,
                    "color": a.color, "length": a.length}
                   for a in level.arrows],
        "dots": [{"col": d.col, "row": d.row,
                  "rotation": d.rotation} for d in level.dots],
    }
    return json.dumps(d, indent=2)
```

---

### 9. BATCH GENERATOR — MAIN ENTRY POINT

```python
def generate_batch(start_level: int, end_level: int,
                   output_dir: str, max_retries: int = 80,
                   debug_json: bool = False):
    """
    Generate levels [start_level, end_level] inclusive.
    Outputs:
      output_dir/batch_{start}_{end}.bin   — binary batch file (production)
      output_dir/manifest.json             — metadata for all levels
      output_dir/debug/level_NNNN.json     — optional, if debug_json=True

    Usage:
      generate_batch(1, 500, "./levels/batch1")
      generate_batch(501, 1000, "./levels/batch2")
    """
    os.makedirs(output_dir, exist_ok=True)
    if debug_json:
        os.makedirs(os.path.join(output_dir, "debug"), exist_ok=True)

    seen_fps: Set[str] = set()
    manifest = []
    failed = []
    generated_levels = []

    # Tracks the base shape name (e.g. "teddy", "plus") of the last 5 Boss
    # levels and the last 5 God levels, independently, to enforce the
    # no-repeat-within-5 rule in select_shape().
    shape_history: Dict[LevelType, deque] = {
        LevelType.BOSS: deque(maxlen=5),
        LevelType.GOD: deque(maxlen=5),
    }

    for n in range(start_level, end_level + 1):
        level = None
        success = False
        level_type = get_level_type(n)
        recent_shape_names = list(shape_history[level_type]) if level_type in shape_history else None

        for attempt in range(max_retries):
            seed = n * 31337 + attempt * 997
            level = build_level(n, seed, recent_shape_names=recent_shape_names)
            if level is None:
                continue
            level.difficulty_score = score_level(level)
            if not verify_solution(level):
                continue
            fp = fingerprint_level(level)
            if fp in seen_fps:
                continue
            seen_fps.add(fp)
            success = True
            break

        if success and level:
            generated_levels.append(level)
            if level.level_type in shape_history:
                # shape_name is "{basename}_{size}" — strip the size suffix
                shape_history[level.level_type].append(level.shape_name.rsplit("_", 1)[0])
            manifest.append({
                "level": n,
                "type": level.level_type.value,
                "shape": level.shape_name,
                "arrows": len(level.arrows),
                "dots": len(level.dots),
                "pairs": len(set(a.color for a in level.arrows if a.color)),
                "difficulty": level.difficulty_score,
                "time_limit": level.time_limit_seconds,
                "seed": level.seed,
                "solution_steps": len(level.solution_order),
            })
            if debug_json:
                path = os.path.join(output_dir, "debug", f"level_{n:04d}.json")
                with open(path, 'w') as f:
                    f.write(level_to_debug_json(level))
            print(f"  {n:5d} {level.level_type.value:6} {level.shape_name:20} "
                  f"arrows={len(level.arrows):2d}  score={level.difficulty_score:4d}  "
                  f"seed={level.seed}")
        else:
            failed.append(n)
            print(f"  {n:5d} FAILED")

    # Write binary batch file
    bin_path = os.path.join(output_dir, f"batch_{start_level}_{end_level}.bin")
    write_batch_bin(generated_levels, bin_path)

    # Write manifest
    with open(os.path.join(output_dir, "manifest.json"), 'w') as f:
        json.dump({
            "batch_start": start_level, "batch_end": end_level,
            "succeeded": len(generated_levels), "failed": failed,
            "bin_file": os.path.basename(bin_path),
            "levels": manifest
        }, f, indent=2)

    print(f"\n✓ {len(generated_levels)}/{end_level-start_level+1} levels → {bin_path}")
    if failed:
        print(f"✗ Failed: {failed}")


if __name__ == "__main__":
    import sys
    if len(sys.argv) < 4:
        print("Usage: python level_generator.py <start> <end> <output_dir> [--debug]")
        sys.exit(1)
    start = int(sys.argv[1])
    end   = int(sys.argv[2])
    out   = sys.argv[3]
    debug = "--debug" in sys.argv
    generate_batch(start, end, out, debug_json=debug)
```

---

### 10. CORRECTNESS CHECKLIST

Write a unit test for each of these before considering the implementation complete:

1. `verify_solution(level)` returns `True` for every generated level, zero exceptions.
2. No two levels in a batch share a fingerprint.
3. Normal levels have only rectangular/square `valid_cells`.
4. Boss levels never have rectangular `valid_cells`.
5. God levels never have rectangular `valid_cells`.
6. Every arrow's body occupies only cells in `level.valid_cells`.
7. No two arrows share any cell.
8. Dots are only in cells that are in `valid_cells` and not occupied by any arrow.
9. Levels numbered > 100 of BOSS type always have a non-None `time_limit_seconds`.
10. Levels numbered > 200 of GOD type always have a non-None `time_limit_seconds`.
11. `decode_level_binary(encode_level_binary(level))` reproduces the level exactly.
12. `read_batch_bin(write_batch_bin(levels))` reproduces every level in the batch.
13. Every arrow in every level (except the first placed, last to fire) has at least one body cell in some other arrow's exit corridor.
14. Difficulty scores strictly increase on average across 50-level windows.
15. `BOSS_SHAPE_FILES` contains at least 20 distinct `.svg` assets; `GOD_SHAPE_FILES` contains at least 20 distinct `.svg` assets.
16. In any batch of 5+ consecutive Boss levels, no base shape name repeats (check `manifest.json`'s `shape` field, stripped of its size suffix) — except when a shorter pool genuinely forces a repeat. Same check independently for God levels.
17. Every Boss shape and every God shape produces a non-empty `valid_cells` list after `trim_and_maximize`, and that list is never identical in outline to the plain `shape_square`/`shape_rectangle` output (i.e. Boss/God shapes never accidentally degrade into a filled rectangle).
18. No arrow in any generated level, at any level number, has `length < 2` (verify by checking `len(a.cells)` for every arrow in every level).
19. Levels 1–3 are flagged `is_tutorial_level=True`, contain exactly the mechanic described in Section 1.7 (level 1: no color, no dots; level 2: exactly one color pair; level 3: exactly one dot) and no more than 3 arrows each.
20. No level numbered 4–15 has any arrow with a non-None `color`, and no level numbered 4–15 has any `dots` — for every level type, including a Boss level that lands at 10.
21. `canvas_size_for()` is non-decreasing in level number within each level type, and at every level number where both exist, Boss's size ≥ Normal's size and God's size ≥ Boss's size.
22. Every arrow body is a **self-avoiding path**: no cell appears twice in `a.cells`, and no consecutive step is the 180° reverse of the previous step. Verify for every arrow in every level.
23. For every arrow, `a.direction.value == (a.cells[-1][0] - a.cells[-2][0], a.cells[-1][1] - a.cells[-2][1])` — the stored direction matches the actual last step of the body.
24. Across any 20-level window of generated levels (levels 4+), the fraction of arrows with `length > G` (very long tier) is between 15 % and 55 % — confirming the soft 35 % target is being broadly hit without becoming degenerate in either direction.
25. `decode_level_binary(encode_level_binary(level))` reproduces every arrow's `cells` list exactly, including bent multi-direction paths (extension of check 11 specifically for bent arrows).

---

### 11. HARD PROHIBITIONS

- **Never** generate a random grid and then check solvability. Always build backwards (except tutorial levels, which are hand-authored per Phase 0 — that's intentional, not a solvability shortcut).
- **Never** use backtracking search. Retry with a new seed instead.
- **Never** output JSON as the production format. Binary only.
- **Never** use any library outside Python's stdlib **inside the shipped game or the binary encode/decode path.** Exception, build-time only: the SVG→grid rasterization step (Section 3.2) may use `cairosvg`/`Pillow` (or an equivalent offline rendering library) since it runs once, offline, to produce the `.bin` files — the game itself never touches SVGs or these libraries at runtime.
- **Never** place arrows outside `valid_cells`.
- **Never** change the seed formula `n * 31337 + attempt * 997`.
- **Never** merge Phase 2 (construction) and Phase 3 (feature application).
- **Never** construct an arrow with `length < 2` anywhere in the system — 1-dot arrows are prohibited at every level number and every level type, tutorial included.
- **Never** place a color pair or a direction-changing dot in a level numbered 4–15, regardless of level type.
- **Never** allow an arrow body to visit the same cell twice (self-intersection). Every body must be a strict self-avoiding path.
- **Never** allow a body step to be the 180° reverse of the immediately preceding step (U-turn into the cell just left). This is the specific case that causes instant self-intersection and is additionally called out because the AI building the path must check for it explicitly at every step.
- **Never** store a `direction` value on an Arrow that does not match `(cells[-1][0] - cells[-2][0], cells[-1][1] - cells[-2][1])`. The direction field must always reflect the actual last step of the body — it is derived, not chosen independently.
- **Never** encode `num_cells` for an arrow as a single `u8` byte. It must be `u16` (little-endian) to accommodate very long bent arrows on large grids (up to 2 × G cells, which exceeds 255 for G ≥ 128).

---

*End of prompt. Implement the complete `level_generator.py` now, including all data structures, the Normal shape functions, the SVG rasterization pipeline and shape manifest (Section 3), the tutorial-level builder (Phase 0), the backwards builder (Phase 1-3), feature application, binary encode/decode, and the batch generator CLI. Populate `assets/shapes/boss/` and `assets/shapes/god/` with the SVG files before running the batch generator — the generator will fail loudly (empty shape pools) if those folders are missing or empty.*
