# Omnemo OS

Omarchy, made easy, made for memory.

Omnemo OS is our edition of [Omarchy](https://github.com/omacom/omarchy): the same Omarchy underneath, a desktop that works the way people expect (a taskbar, plain-words buttons, a "?" guide to every icon, and the flag bar), made to run with [Omnemo](https://github.com/GuyMannDude/omnemo) memory, so the AI helpers on your computer remember you. It doesn't replace Omarchy: one command installs it, and one command puts your computer back exactly as it was.

**Status: v0.9 Public Preview.** It works on today's Omarchy 4.5 test version and will be called 1.0 once Omarchy 4.5 stable is out and the edition has survived a reboot and an `omarchy-update` on a stock machine. Expect rough edges, and tell us about them (see below).

## Two ways to get it

1. **Just the memory.** Already on Omarchy and happy with it? Install [Omnemo](https://github.com/GuyMannDude/omnemo) on its own. Its guide shows you how to use it.
2. **The whole thing: Omnemo OS.** Install Omarchy from its own installer, then run our one command below. It sets up the friendlier desktop and [Omnemo](https://github.com/GuyMannDude/omnemo) memory together. If Omnemo is already on your computer, it is left exactly as it is.

## Install

This preview needs Omarchy's 4.5 test version (release candidate). It never asks for your password, except Omarchy's own snapshot step.

1. Take a snapshot so you can undo: open a Terminal (Super + Enter) and type `omarchy snapshot create` (it asks for your password).
2. Switch to the test version: Omarchy menu → Update → Channel → RC, then Update → Omarchy.
3. Paste the three lines below into the Terminal.

```
git clone https://github.com/GuyMannDude/omnemo-os
cd omnemo-os
bin/omnemo-os install
```

Omarchy 4.5 stable shipped on 2026-11-05; on an older 4.5 test version add `--allow-rc`. The memory part downloads a few hundred MB and the colored bar icons about 33 MB, so it needs the internet and a couple of minutes; if you are offline, the desktop still installs (with one-color icons) and `omnemo-os repair` adds the rest later. When it finishes, start a **new** session of your AI helper (Claude, Codex, ...) and it shares one memory with the others.

Afterwards, in any new Terminal: `omnemo-os status` shows what is installed (memory and icons included) and flags anything an Omarchy update reset; `omnemo-os repair` puts it back; `omnemo-os uninstall` puts everything back exactly as it was. You can delete the downloaded `omnemo-os` folder once it's installed. Want a new background? Tools → Theme & wallpaper now includes our own Hwy 180 at golden hour; your current wallpaper is never changed.

Your memories are yours. Click **?** on the bar to see how many your AI helpers have saved. If memories from before are found when you install, you're asked "Keep them?", and uninstall asks "Keep your memories?" too. Pressing Enter always keeps them. Deleting takes typing the word DELETE, and a copy is saved first (`~/omnemo-memories-<date>.tar.gz`). Kept memories stay in `~/.local/share/omnemo`, and a later install picks them up where you left off.

## Share your ideas

Omnemo OS is brand new, and it's being shaped by the people who use it. You don't need to be a programmer to help. If something is confusing, annoying, or missing, we want to hear it.

- Tell us in plain words what you were trying to do and what got in the way. "I couldn't find how to change the wallpaper" is a perfect report.
- A phone photo of your screen is fine. No logs needed.
- Ideas are welcome too: a button you wish was on the bar, an app you'd like in Favorites, anything.

Problems or confusion: on the GitHub page click Issues → New issue → "Something went wrong (or confused me)". Ideas: click Discussions → Ideas. (You'll need a free GitHub account.) Or ask your AI assistant to write it up for you and paste it there. Every message gets read.

If something breaks badly, `omnemo-os uninstall` puts your desktop back exactly the way Omarchy had it.

## What's inside (you can skip this)

- `MANIFEST.md` — every file and setting the edition touches, as written on the test laptop.
- `INSTALLER-NOTES.md` — installer-side notes.
- `bin/omnemo-os` (`install` / `uninstall` / `status` / `repair`) — the edition layer; install copies it to `~/.local/share/omnemo-os/app` and links `~/.local/bin/omnemo-os` to it.
- `plugins/` — the edition's seven bar plugins, including the flag bar (`guy.flag`: blue behind the icons, red and white stripes between them). `system/` — the one-bar guard (a 30-second timer that keeps exactly one bar running) and `omnemo-icons-update`, which fetches the colored icons ([Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme), GPL-3.0, downloaded from its makers, never bundled here). Run `omnemo-icons-update` any time for the newest set.

Omnemo OS is built on Omarchy (MIT license). "Omarchy" is a pending trademark of its owners. This project is not affiliated with or endorsed by them.
