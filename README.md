# GLADIA

`light-sculpture` is not one polished application. It is a folder of 21 shell tools under `GLADIA/` that I kept separate because I rarely need the whole stack at once. Some days I only want to trim media. Other days I want OCR, transcription, translation or image generation.

## Why it stayed as many scripts

I chose small command-line tools over a single interface because chaining them by hand was faster than building a GUI for every variation. The cost is real:

- first-run setup is uneven,
- Python environments can drift,
- model paths and checksums still need explicit care in some flows.

## What the repo is good at

- audio and video preprocessing,
- local OCR and transcription workflows,
- small audiovisual pipelines built from reusable steps,
- exploratory work where command-line composability matters more than UI polish.

## What I would not oversell

- not every script is equally hardened,
- some model-dependent flows are still environment-sensitive,
- "all-in-one toolkit" sounds nice, but the truth is that this repo behaves better when you treat it like a box of instruments, not a finished workstation.

## Why the name matters

I kept the "sculpture" metaphor because that is how I was actually using it: cut, isolate, layer, translate, re-run. Less like a media platform, more like manual material work with shell commands.
