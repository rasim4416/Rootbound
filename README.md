# Rootbound

Cell defense prototype built with **Godot 4.7** (GL Compatibility).

Nanobots defend the Nucleus against pathogen waves on a shared grid map. Meta progression uses CHONS research, Fabricator placement, and level unlocks.

## Requirements

- [Godot 4.7+](https://godotengine.org/download) (project uses **GL Compatibility** renderer)

## Run in Godot

1. Clone this repository.
2. Open Godot → **Import** → select `project.godot` (or open the folder).
3. Press **F5** or click **Run** — main scene is `scenes/menu/main_menu.tscn`.

## Project layout

| Path | Purpose |
|------|---------|
| `scenes/` | Main menu, gameplay, UI, units |
| `scripts/` | Game logic, managers, progression |
| `data/` | Levels, nanobots, pathogens, research, shop |
| `assets/` | Textures (research portraits, gameplay sprites) |
| `resources/` | UI StyleBoxes |

## Notes

- `.godot/` is local editor cache — not in repo (regenerated on import).
- Save data: `user://rootbound_save.json` and `user://display.cfg` (local only).

## License

Not specified yet.
