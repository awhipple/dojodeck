# dojodeck (Steam Deck)

One LÖVE app you add to Steam **once**. **On launch** it self-updates and pulls
every game in `games.txt` (the slow part — done once, not on every menu return),
then shows a controller menu and launches the one you pick — back to the menu when
it exits. New games added on the dev box (via `tools/publish`) appear on the next
launch. **It updates itself too** — pushing a new dojodeck feature ships like a new
game, and the launcher re-execs if its own file changed.

To refresh a single game without restarting, highlight it and press **Y (re-sync
this)**: the hub pulls just that game **in-place** — the menu stays on screen with a
spinner (no blackout), and launching is disabled until the pull finishes. You never
touch Desktop Mode after setup.

```
dojodeck        ← the launcher (this is the Steam shortcut target; a host script)
hub/            ← the LÖVE menu UI (main.lua, conf.lua)
games.txt       ← manifest: "<slug> <git-url>" per line (the dev box pushes to this)
runtime/        ← LÖVE AppImage, fetched+extracted on first run (gitignored)
games/          ← game repos, cloned here at runtime (gitignored)
```

## One-time Deck setup (Desktop Mode, ~5 min)

1. **Switch to Desktop Mode** (Steam ▸ Power ▸ Switch to Desktop).
2. **Clone dojodeck** (public repos pull over HTTPS — no SSH key or login needed):
   ```sh
   git clone https://github.com/awhipple/dojodeck.git ~/dojodeck
   chmod +x ~/dojodeck/dojodeck
   ```
3. **First run from the terminal** (downloads LÖVE, syncs games, shows the menu):
   ```sh
   ~/dojodeck/dojodeck
   ```
   Confirm the menu appears and a game launches. `Esc`/`B` quits.
4. **Add to Steam:** in Steam (Desktop), *Games ▸ Add a Non-Steam Game to My
   Library ▸ Browse* → pick `~/dojodeck/dojodeck`. Rename it "dojodeck".
   Optional: set a custom icon/artwork.
5. **Back to Gaming Mode.** Launch "dojodeck" from your library — it runs
   fullscreen with the controller. That's the steady state.

> Games are published public too, so the Deck pulls everything anonymously. If you
> ever make a game repo private, you'll then need an SSH key or `gh auth login` on
> the Deck for that repo.

## Controls
`A`/Enter play · D-pad or stick select · `Y`/`R` re-sync the highlighted game
(in-place, with a spinner) · `B`/Esc quit

## Dev channel (optional): play the working tree, no commits

Git is dojodeck's *release* channel — every update normally needs a commit +
push. The dev channel skips that for playtesting: the dojo serves the **live
working tree** of every game in `~/projects/gamelab/games/` as a ready-to-run
`.love`, and the Deck pulls straight from it. Save a file on the dev box,
press `Y` on the Deck, play it.

One-time setup (Desktop Mode terminal): grab the deck token from the dojo's
`/admin/apps` page (the "dojodeck" card at the bottom — tap to copy) and

```sh
echo xxxx-xxxx > ~/dojodeck/devtoken
```

That's it. On the next launch every gamelab game appears twice: the published
git copy (`bouncer`) and the live one (`bouncer (dev)`). Dev copies re-download
on every launch, and `Y` on a dev row re-pulls just that game in place —
whatever is on disk on the dev box at that moment, committed or not. Offline
(or with a wrong token) the dev rows just keep their last-downloaded copies.

The token is read-only and only reaches these game zips; rotate it by deleting
`home-control/deck.json` on the dev box and restarting home-control. Point the
Deck at a different server with `DOJODECK_DEV_URL=…` (default
`https://api.whipple.ninja`).

## Notes / things to verify on real hardware
- **Steam Input**: non-Steam games get a virtual gamepad by default; LÖVE reads it
  via `love.joystick`. If the menu doesn't respond to the sticks/buttons, set the
  shortcut's controller layout to "Gamepad" in Steam.
- **AppImage**: extracted once (no FUSE needed). If `runtime/AppRun` is missing,
  delete `runtime/` and relaunch to re-fetch.
- **Steam overlay preload**: Steam injects both 32- and 64-bit `gameoverlayrenderer.so`
  via `LD_PRELOAD`; our 64-bit LÖVE can't load the 32-bit one, so `ld.so` would print
  a `wrong ELF class: ELFCLASS32` warning (gamescope drew it over the screen). The
  launcher strips the 32-bit preload entry up front (`sanitize_preload`) so it's gone.
- The dev box never needs to be online when you play — games live on GitHub; the
  dojo pulls from there over HTTPS.
