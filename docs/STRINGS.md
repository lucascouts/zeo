# "Zed" in strings — what Zeo renames, and what it must not

Measured 2026-09-13 against Zed `9d272b036335`: **404 string literals** in
`crates/` contain the word `Zed`. Patch `0025` changes **21** of them. This file
is why the other 383 stay.

Re-run the count before trusting any number here:

```sh
grep -rhoE '"[^"]*\bZed\b[^"]*"' crates/ --include='*.rs' | wc -l
```

## The axis is not "is it visible" — it is "what does it name"

The first pass classified by visibility and got 245 candidates. Nearly all were
wrong, because the most visible "Zed" strings are visible *precisely because they
name Zed Industries*:

> `Upgrade to Zed Pro` · `Your Zed Pro Trial has expired` · `Sends the current
> conversation to the Zed team` · `Authorize Zed in your browser` · `Zed's hosted
> models`

Zeo runs on Zed's backend by design ([`REBRAND.md`](REBRAND.md) §3). There is no
Zeo Pro; the OAuth page really does say Zed, the conversation really does go to
Zed's team, and the subscription really is theirs. Renaming these would not be a
rebrand — it would be false.

**The rule: a literal becomes "Zeo" only when it names the application the user
is running.** Vendor, service, plan, team and hosted models stay "Zed".

## What must never change, and what breaks if it does

| Class | Count | What breaks |
|---|---|---|
| **Font family names** — `Zed Mono`, `Zed Sans`, `Zed Plex Sans`, `Zed Icons` | 15 | values of `font_family:`; the file behind `Zed Mono` is *Lilex*, shipped under that alias. The editor stops finding its own font |
| Vendor, plan, team, hosted models | 42 | states something untrue |
| Tests, fixtures, examples | 31 | noise; and the window-title tests assert the *old* format |
| Windows paths, `.exe`, `C:\Zed Data` | 19 | not built here |
| `User-Agent` — `Zed/{} ({}; {})` | 3 | changes what remote servers see |
| Theme names — `Zed (Default)` | 3 | breaks themes referenced from user settings |
| `migrator.rs` literals | — | corrupts settings migration |
| `zed.dev` URLs (156) and the `zed://` scheme (70) | — | decided in REBRAND §3 and patch `0022` |

## One large class needed no patch at all

The **window title** — the string a user sees more than any other — is built from

```rust
ReleaseChannel::try_global(cx).unwrap_or(Stable).display_name()
```

which patch `0021` already makes return `"Zeo"`. **75 sites reach the product
name that way.** The three `"Zed — root1, root2"` literals that looked like the
highest-value target are *test assertions* for that code.

This is the pattern worth copying: where the product name is read from the
channel, the rebrand is free and cannot drift.

## What `0025` does cover

| | |
|---|---|
| seen constantly | `Welcome to Zeo` · `Welcome back to Zeo` · `Open Zeo Log` · `Zeo — Settings` · `Zeo failed to launch` |
| seen on events | the update flow · CLI installation · the xdg-desktop-portal error · the OAuth callback page · `Add to existing Zeo window` |

## What was left out on purpose

**24 settings descriptions** and **154 log, error and macOS-only strings.** They
are upstream UI copy — the churniest kind of file — so each one bought costs a
`refresh.sh` conflict forever, for text read once or never.

## Why literals and not `display_name()`

`display_name()` would be better in principle: self-maintaining, and plausibly
upstreamable, since Zed Nightly displays "Zed" in these same strings where it
should display its own channel name.

It was tested and rejected for `0025`. The sites bind to `&'static str`:

```rust
let label = match auto_updater.map(...) {
    Some(AutoUpdateStatus::Updated { .. }) => "Please restart Zed to Collaborate",
    ...                                     => "Updating...",
};
```

Reaching for `display_name()` forces `format!`, which turns the binding into a
`String` and drags in sibling arms like `"Updating..."` that have nothing to do
with the rebrand. Converting those sites properly is a separate change, and one
worth offering upstream rather than carrying.
