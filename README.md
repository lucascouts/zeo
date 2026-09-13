# Zeo

Zeo is a rebranded build of the [Zed](https://zed.dev) editor: Zed's engine, a
distinct visual identity, and a set of downstream refinements on top.

**Zeo is not a fork.** It is a *patch set* applied to the exact Zed source commit that
gets packaged, in the spirit of what Betterbird is to Thunderbird. There is no vendored
copy of Zed here and no rebased branch to keep alive — the patches live in
[`lucascouts/zed-patches`](https://github.com/lucascouts/zed-patches), each one written
against a named upstream commit and re-verified whenever that commit moves.

That choice is the whole design. A fork accumulates a merge debt that grows with every
upstream release; a patch series states exactly what it changes, and stops applying —
loudly — the moment upstream moves the ground under it.

## Not affiliated with Zed Industries

Zeo is an independent project. It is **not** affiliated with, endorsed by, or supported
by Zed Industries. "Zed" and the Zed logo are theirs; this project neither uses nor
claims them. The Zeo mark in [`brand/`](brand/) is original work, constructed rather
than traced — see [`brand/build-icon.py`](brand/build-icon.py), which generates it.

Zed is distributed under the GPL-3.0-or-later (with parts under Apache-2.0), and Zeo
inherits those terms. Report Zeo problems here, never to Zed Industries.

## What lives where

| | |
|---|---|
| [`brand/`](brand/) | the Zeo mark — SVG sources, the generator that builds it, the rendered icons, and their checksums |
| [`docs/`](docs/) | the rebrand's touch-point inventory, the roadmap, and the Visual Extension API research |
| [`archive/`](archive/) | the first run (2026), kept as the record it is: story specifications, unpublished commits as patches, and the icon exploration renders |
| `lucascouts/zed-patches` | **the patches themselves**, including the rebrand series |
| the `bentoo` overlay | `app-editors/zeo`, which decides which patches apply |

## Status

**Early.** The rebrand is fully specified in [`docs/REBRAND.md`](docs/REBRAND.md) — every
constant, every decision, with its rationale — and the mark is finished and reproducible.
What does not exist yet is an installable Zeo: the identity patches have to be written
against the currently packaged Zed commit, and the ebuild after them.

There is nothing to download here yet. When there is, it will say so.
