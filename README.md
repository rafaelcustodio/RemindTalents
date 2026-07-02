# RemindTalents

**Never enter a dungeon or pull a boss with the wrong talents again.**

RemindTalents stores your talent loadouts **per dungeon and per raid boss** and shows an
on‑screen reminder when your active build doesn't match where you are — click it to swap
instantly. It's a lighter, friendlier alternative to juggling loadouts by hand.

> Standalone — no dependencies. **Incompatible with TalentLoadoutsEx** (you can't run both;
> RemindTalents will offer to import your loadouts from it).

## Features

- **Reminder by location.** In a Mythic+ dungeon, or when you target a raid boss (out of combat),
  a clickable icon appears if your current talents aren't one of the builds you saved for that
  encounter. Click to apply the right one.
- **Automatic season catalog.** The dungeon list (current M+ pool) and raid bosses are pulled
  automatically from the game with their real icons and names, and update every season. No manual
  list to maintain.
- **Multiple loadouts per dungeon/boss.** Save as many builds as you want for each encounter.
- **Raid difficulty aware.** Tag a raid loadout as **Normal / Heroic / Mythic** (or **All**). The
  reminder respects the difficulty you're actually in.
- **Docked, master–detail UI.** The manager opens alongside the Blizzard talent tree (which is now
  movable). Pick a dungeon/boss on the left, manage its loadouts on the right.
- **Easy import & save.** Paste a talent export string, or just save your current build. Every
  loadout gets a **custom name and icon** (icon picker searchable by name or by file id).
- **Duplicate & move.** Copy a loadout, or move it to another dungeon/boss in a couple of clicks.
- **Active build indicator.** The loadout that matches your current talents is clearly marked, and
  its Apply button hides — updated live as you change talents.
- **One‑click migration from TalentLoadoutsEx.** Bring your existing loadouts over with a single
  button (or `/rt migrate`).
- **Localized.** English and Português (Brasil).

## Usage

- Open your talent tree — the RemindTalents panel opens next to it.
- Select a dungeon or boss, then **Import** a code or **Save current** build (you'll be asked for a
  name and icon).
- Slash commands:
  - `/rt` — open the talent tree (and the panel)
  - `/rt save` — help for saving the current build
  - `/rt migrate` — import your loadouts from TalentLoadoutsEx (while it's still enabled)

## Notes

- Talent swapping is only possible **out of combat** and where the game allows it. The reminder
  still warns you even where you can't swap, so you know before the pull.
- Boss reminders trigger when you **target** the boss out of combat.

## License

MIT. Contributions welcome.
