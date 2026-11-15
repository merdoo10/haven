

# HYPER 2093

**A cyberpunk type 3D action game**

![Cover](docs/cover.png)

</div>

## About

A cyberpunk action game set in a neon-lit city in the year 2093. This repository contains the game's 3D assets: models, animations, level environments, and textures.

## Repository Contents

```
haven/
├── lvl 1 mekan/     # Level 1 environment files
├── lvl 2 mekan/     # Level 2 environment files
├── textures/        # Textures
└── *.fbx            # Character, enemy, and prop models, plus animations
```

### Characters and Enemies

| File | Description |
|---|---|
| `havenmainkollu.fbx` | Main character |
| `havenboss.fbx` | Boss |
| `Hayalet Dusman.fbx` | Ghost enemy |
| `dusman2.fbx` | Enemy 2 |

### Animations

| Group | Files |
|---|---|
| Movement | `Running.fbx`, `Sprint.fbx`, `dusman2walking.fbx` |
| Melee combat | `Punching.fbx`, `Mma Kick.fbx`, `Hurricane Kick.fbx`, `Surprise Uppercut.fbx`, `dusman2punch.fbx` |
| Hit reactions | `Receiving Uppercut.fbx`, `Receiving An Uppercut.fbx` |
| Gunplay | `Gunplay.fbx` |

### Props and Environment

`havenmekan1.fbx`, `laptop.fbx`, `ssd.fbx`, `tubitakbuyukekran.fbx`, `tubitakbuyukekrankirik.fbx`

## Usage

1. Download the repository:
   ```bash
   git clone https://github.com/merdoo10/haven.git
   ```
2. Import the `.fbx` files into your game engine (Unity, Unreal, Godot, etc.).
3. Assign the textures from `textures/` to the materials.




