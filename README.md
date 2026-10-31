# Omnemo OS

A user-friendly edition layered on stock [Omarchy](https://github.com/omacom/omarchy), named for [Omnemo](https://github.com/GuyMannDude/omnemo), the memory for your AI helpers.
This preview does not install Omnemo yet; add it with Omnemo's own install guide, and a later release will bundle it.
Not a fork: one command installs, one command returns the machine to exact stock.

**Status: v0.9 Public Preview.** It works on today's Omarchy 4.5 release candidate and will be called 1.0 once Omarchy 4.5 stable is out and the edition has survived a reboot and an `omarchy-update` on a stock machine. Expect rough edges, and tell us about them (see below).

## Install

Step 0, before anything: this preview needs Omarchy's **4.5 RC channel**. Switch to it the way Omarchy documents, and take a snapshot first (Omarchy's own advice for the RC channel). Everything the edition does is in your home folder, no sudo, and `omnemo-os uninstall` puts it all back.

```
git clone https://github.com/GuyMannDude/omnemo-os
cd omnemo-os
bin/omnemo-os install --allow-rc
```

`--allow-rc` is only needed while 4.5 is a release candidate. `bin/omnemo-os status` shows what is installed and flags anything an Omarchy update reset; `bin/omnemo-os repair` puts it back; `bin/omnemo-os uninstall` restores stock, byte for byte.

- `MANIFEST.md` — every file and setting the edition touches, as written on the test laptop.
- `INSTALLER-NOTES.md` — installer-side notes.
- `bin/omnemo-os` (`install` / `uninstall` / `status` / `repair`) — the edition layer; `bin/omnemo-os-install` and `-uninstall` are the same script by another name.
- `plugins/` — the edition's six bar plugins. `system/` — the one-bar guard (a 30-second timer that keeps exactly one bar running).

## Share your ideas

Omnemo OS is brand new, and it's being shaped by the people who use it. You don't need to be a programmer to help. If something is confusing, annoying, or missing, we want to hear it.

- Tell us in plain words what you were trying to do and what got in the way. "I couldn't find how to change the wallpaper" is a perfect report.
- A phone photo of your screen is fine. No logs needed.
- Ideas are welcome too: a button you wish was on the bar, an app you'd like in Favorites, anything.

Where to send it: open a Discussion on this repo's GitHub page (Ideas, or Q&A for help), or ask your AI assistant to write it up for you and paste it there. Every message gets read.

If something breaks badly, `omnemo-os uninstall` puts your desktop back exactly the way Omarchy had it.

Omnemo OS, built on Omarchy (MIT). Omarchy is a pending trademark of its owners; this project is not affiliated.
