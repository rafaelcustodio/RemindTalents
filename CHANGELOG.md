# Changelog

## 1.2.0
- New fixed "Others" section at the end of the catalog: a free bucket to store loadouts not tied to a dungeon/boss.
- Double-click to apply: double-click a loadout to apply it, or double-click a catalog group to apply its first loadout.
- Fixed the world-boss group (e.g. "Midnight") wrongly showing as a raid (`shouldDisplayDifficulty` was read from the wrong return position).
- Slash command changed from `/rt` to `/rtl` to avoid the conflict with Method Raid Tools (`/remindtalents` still works).
- Custom addon icon.
- Guard against a taint error when `UnitName()` of a non-player unit returns a secret value (WoW 12.0+).

## 1.1.0
- On-screen reminder icons now glow (pulsing proc-style highlight) when they appear, making the "wrong build" alert easier to notice.

## 1.0.1
- Publishing to CurseForge enabled (no functional changes).

## 1.0.0
- First public release.
- Per dungeon/boss talent loadouts with on-screen reminder and one-click apply.
- Automatic season catalog (M+ dungeons + raid bosses) with icons.
- Multiple loadouts per encounter; raid difficulty tags (Normal/Heroic/Mythic/All).
- Master-detail UI docked to the talent tree; movable talent window.
- Import from export strings or save current build; custom name + searchable icon picker.
- Duplicate / move loadouts; active-build indicator.
- One-click migration from TalentLoadoutsEx.
- Localization: enUS, ptBR.
