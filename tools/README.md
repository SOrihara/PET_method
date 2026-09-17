# Rebuild the English HTML guide

Edit the repository's `README.md` for the guide text and examples.
With Node.js 20 or newer, run these commands from the repository root:

```sh
npm --prefix tools ci
npm --prefix tools run guide
```

The result is `docs/index.html`, with the figure embedded for offline reading.
Edit `tools/build-guide.mjs` for shared layout and styling. Rebuilding replaces
direct edits to the generated HTML. Node.js is needed only to rebuild the guide,
not to install or use the R package.
