# F.A.A.T. (No DLC)

F is for Factorio. A daily play timer: when it runs out, the game saves and closes.

This is a base-game fork of [Fish Addicts Anonymous Timer](https://mods.factorio.com/mod/fish-addicts-anonymous-timer)
by **Orbital917** ([original source](https://github.com/lukedupin/fish-addicts-anonymous-timer)), used under the
MIT License. See [`LICENSE`](LICENSE). All credit for the idea and the original code goes to them.

## What's different from the original

- **No Space Age needed.** The original only listed Space Age as a dependency; it doesn't use any DLC content.
- **Carry time over between loads** (setting, on by default). Play time is stored in the save, so saving and
  reloading continues the countdown instead of restarting it.
- **Lockout** (setting, off by default). When time runs out the save is locked. Loading a locked save gives you
  30 seconds, then closes the game again, until you type `/faat-unlock` to start a new day.
- **Customizable warning** (setting, default 5 minutes). Choose how long before closing the chat warning appears.

## Settings

Settings → Mod settings → Map:

| Setting | Default | |
|---|---|---|
| Addiction timer (minutes) | 60 | 15–600 |
| Warning before closing (minutes) | 5 | Chat warning + alert sound. 0 = off |
| Carry time over between loads | On | |
| Lock the save when time runs out | Off | |

## Commands

| Command | |
|---|---|
| `/time-remaining` | Time left in this session |
| `/disable-timer` | Turn the timer off until the next load (admin only) |
| `/faat-unlock` | Unlock a locked save and reset the timer (admin only) |
| `/view-memorial` | Memorial fish placed by past sessions |

## Limits (honor system)

- Factorio mods can't read the real clock or date, so the mod can't know when "tomorrow" is. You decide when to unlock.
- Carryover and the lock are stored per save. Loading an older save from before the timer ran out gets around them.
- Mods have no API to quit the game, so (like the original) the mod closes the game with a deliberate script error.
  The game saves a moment before that, so nothing is lost.

## Install

Download the zip for your Factorio version from Releases and put it in `%APPDATA%\Factorio\mods` (Windows)
without unzipping it. Don't run it together with the original mod.
