# Omnemo OS

Omarchy, made easy, with memory built in.

Omnemo OS is our edition of [Omarchy](https://github.com/omacom/omarchy): the same Omarchy underneath, a desktop that works the way people expect (a taskbar, plain-words buttons, a "?" guide to every icon), and [Omnemo](https://github.com/GuyMannDude/omnemo) memory, so the AI helpers on your computer remember you. It doesn't replace Omarchy: one command installs it, and one command puts your computer back exactly as it was.

**Status: v0.9 Public Preview.** It works on today's Omarchy 4.5 test version and will be called 1.0 once Omarchy 4.5 stable is out and the edition has survived a reboot and an `omarchy-update` on a stock machine. Expect rough edges, and tell us about them (see below).

## Two ways to get it

1. **Just the memory.** Already on Omarchy and happy with it? Install [Omnemo](https://github.com/GuyMannDude/omnemo) on its own. Its guide shows you how to use it.
2. **The whole thing: Omnemo OS.** Install Omarchy from its own installer, then run our one command below. It sets up the friendlier desktop and installs Omnemo memory.

## Install

This preview needs Omarchy's 4.5 test version (release candidate). It never asks for your password, except Omarchy's own snapshot step.

1. Take a snapshot so you can undo: open a Terminal (Super + Enter) and type `omarchy snapshot create` (it asks for your password).
2. Switch to the test version: Omarchy menu → Update → Channel → RC, then Update → Omarchy.
3. Paste the three lines below into the Terminal.

```
git clone https://github.com/GuyMannDude/omnemo-os
cd omnemo-os
bin/omnemo-os install --allow-rc
```

`--allow-rc` is only needed while 4.5 is a test version. Afterwards, from any Terminal: `omnemo-os status` shows what is installed and flags anything an Omarchy update reset; `omnemo-os repair` puts it back; `omnemo-os uninstall` puts everything back exactly as it was.

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
- `bin/omnemo-os` (`install` / `uninstall` / `status` / `repair`) — the edition layer; `bin/omnemo-os-install` and `-uninstall` are the same script by another name.
- `plugins/` — the edition's six bar plugins. `system/` — the one-bar guard (a 30-second timer that keeps exactly one bar running).

Omnemo OS is built on Omarchy (MIT license). "Omarchy" is a pending trademark of its owners. This project is not affiliated with or endorsed by them.
