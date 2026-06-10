# dojodeck artwork

Steam library assets for the dojodeck non-Steam shortcut, rendered with LÖVE.

| file          | size      | Steam slot                        |
|---------------|-----------|-----------------------------------|
| `capsule.png` | 600×900   | Grid / library tile (portrait)    |
| `hero.png`    | 1920×620  | Hero banner (shown when selected) |
| `icon.png`    | 256×256   | Shortcut icon                     |

Regenerate after a tweak: `love dojodeck/art --out dojodeck/art`

## Apply on the Deck (Desktop Mode)
After adding `dojodeck` as a non-Steam game:
1. Right-click it in the library → **Manage ▸ Set custom artwork** → pick
   `~/dojodeck/art/capsule.png` (the grid tile).
2. Open the game's page; right-click the **banner** area → set `hero.png`.
   (Optional: set a transparent logo the same way if you make one.)
3. Icon: right-click → **Properties** → click the icon → choose `icon.png`.
