# Helping make Omnemo OS better

Omnemo OS is a friendlier desktop layered on top of Omarchy, with Omnemo memory built in: a bottom bar with a taskbar, Tools, a "?" guide and Favorites, plus a few fixes for people who are not developers. It is a living project, and your ideas are how it improves.

## Ideas and problems (no coding needed)
On the GitHub page, click Issues → New issue, and pick **"Something went wrong (or confused me)"**. It asks three questions: what you tried to do, what happened, and what you expected. A photo of the screen is perfect.

"This confused me" is a valid report. If something needed a manual, we want to know.

## Trying a change safely
Everything Omnemo OS does lives in your user folders, and every file it changes is backed up first.

```
omnemo-os status      # what is installed, and anything an update reset
omnemo-os repair      # put back what an Omarchy update reset
omnemo-os uninstall   # back to stock Omarchy, exactly as it was
```

The bar widgets are plain QML files in `plugins/<name>/BarWidget.qml`. After editing one, run `omarchy restart shell` (a hot reload keeps running the old code), then check that exactly one bar is running: `pgrep -cx quickshell` should print `1`.

## If you send code
- **No sudo, no edits to Omarchy's own files.** Only user files, only through the installer.
- **Everything can be undone.** Before you send a change, install, uninstall, and check every file comes back identical.
- **Plain words.** Labels are written for someone who has never used Linux: no "foot", no "dock", no jargon.
- **Only show what works.** If a button needs an app that isn't installed, hide it or offer the web version.
- **Launch apps as argument lists**, never through a shell string.

See `MANIFEST.md` for the full list of what the edition changes and why.
