# gamelab dojo (Steam Deck)

One LÖVE app you add to Steam **once**. From Gaming Mode it self-updates, syncs
every game in `games.txt`, shows a controller menu, and launches the one you pick
— back to the menu when it exits. New games added on the dev box (via
`tools/publish`) appear here automatically on the next launch. You never touch
Desktop Mode after setup.

```
dojo            ← the launcher (this is the Steam shortcut target; a host script)
hub/            ← the LÖVE menu UI (main.lua, conf.lua)
games.txt       ← manifest: "<slug> <git-url>" per line (the dev box pushes to this)
runtime/        ← LÖVE AppImage, fetched+extracted on first run (gitignored)
games/          ← game repos, cloned here at runtime (gitignored)
```

## One-time Deck setup (Desktop Mode, ~5 min)

1. **Switch to Desktop Mode** (Steam ▸ Power ▸ Switch to Desktop).
2. **SSH key for private game repos** (skip if the repos are public):
   ```sh
   ssh-keygen -t ed25519 -C "steamdeck" -f ~/.ssh/id_ed25519 -N ""
   cat ~/.ssh/id_ed25519.pub
   ```
   Add that key at https://github.com/settings/keys (or as a deploy key per repo).
3. **Clone the dojo:**
   ```sh
   git clone <this-dojo-repo-url> ~/gamelab-dojo
   chmod +x ~/gamelab-dojo/dojo
   ```
4. **First run from the terminal** (downloads LÖVE, syncs games, shows the menu):
   ```sh
   ~/gamelab-dojo/dojo
   ```
   Confirm the menu appears and a game launches. `Esc`/`B` quits.
5. **Add to Steam:** in Steam (Desktop), *Games ▸ Add a Non-Steam Game to My
   Library ▸ Browse* → pick `~/gamelab-dojo/dojo`. Rename it "gamelab dojo".
   Optional: set a custom icon/artwork.
6. **Back to Gaming Mode.** Launch "gamelab dojo" from your library — it runs
   fullscreen with the controller. That's the steady state.

## Controls
`A`/Enter play · D-pad or stick select · `Y`/`R` re-sync · `B`/Esc quit

## Notes / things to verify on real hardware
- **Steam Input**: non-Steam games get a virtual gamepad by default; LÖVE reads it
  via `love.joystick`. If the menu doesn't respond to the sticks/buttons, set the
  shortcut's controller layout to "Gamepad" in Steam.
- **AppImage**: extracted once (no FUSE needed). If `runtime/AppRun` is missing,
  delete `runtime/` and relaunch to re-fetch.
- The dev box never needs to be online when you play — games live on GitHub; the
  dojo pulls from there.
