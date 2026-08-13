# Rootbound

Cell defense prototype built with **Godot 4.7** (GL Compatibility).

## Requirements

- [Godot 4.7+](https://godotengine.org/download) (project uses GL Compatibility renderer)

## Run locally

1. Clone this repository.
2. Open Godot → **Import** → select `project.godot` in the repo folder.
3. Press **F5** or click **Run** (main scene: Main Menu).

## Project layout

| Path | Purpose |
|------|---------|
| `scenes/` | Game and menu scenes |
| `scripts/` | Gameplay, UI, progression systems |
| `data/` | Levels, plants, research, waves |
| `assets/` | Sprites and research art |
| `resources/` | UI styles |

## Notes

- `.godot/` is ignored — Godot regenerates editor cache on import.
- Save data is written locally to `user://rootbound_save.json` at runtime (not in repo).
