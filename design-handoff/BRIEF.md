# BitFinite Wallet — design brief

**Status: closed.** Every question this brief opened has been answered and the
answers have shipped; the sections below record what was decided rather than
asking. Kept as the reference for the wallet screen, and as the input to any
future design round — which should start by re-reading the source, since these
values go stale the moment someone edits a widget.

Give this file and `wallet-tokens.css` to Claude Design. Everything below is
read from the Flutter source or measured on a 1080×2408 device; none of it comes
from a mockup.

## What the app is

A multi-coin mobile wallet, Flutter, forked from Stack Wallet. Three coins:
**BitFinite (BFX)**, **Pepecoin (PEP)**, **Bellscoin (BELLS)**. Portrait only.

Designs made here are a **visual target**, not shippable code — the app is
Flutter, so React output gets reimplemented by hand. Design for that: layout,
colour, type and hierarchy matter; component APIs do not.

## The screen that matters

The wallet view. **One scrolling page.** Only the app bar is pinned; everything
below scrolls, including the hero.

Top to bottom:

1. **App bar** (pinned) — back, coin icon, wallet name, account type
   (`MAIN ACCOUNT` / `WATCH ONLY`), then chart, notifications and menu icons.
   Painted in `--wallet-surface-hero` so rows pass cleanly behind it on scroll.
2. **Hero** — an inset card, 24px on all four corners. Top row: price with its
   change under it on the left, 24H/7D/30D range pills on the right. Under that
   the sparkline, full width. Then the `FULL BALANCE` label with a privacy eye
   and a sync-status pill, the balance, a fiat line with a today delta, and an
   address chip.
3. **Payouts card** — *conditional.* Only on a wallet mining has paid. Two
   lines: how recent on the headline, how many and since when beneath it, the
   total right-aligned. Tapping it opens the transaction list filtered to
   payouts.
4. **Transactions** header with a *See all* link.
5. **Truncation notice** — *conditional.* Only when history was capped.
6. **Day headers** (`TODAY`, `YESTERDAY`, `31 AUG`) with transaction rows under
   each: icon, direction, time, amount, fiat.
7. **Receive / Send dock** floating over the bottom, on its own opaque bar with
   a 28px gradient above it. The list pads its foot by the bar's height, so the
   last row can be scrolled clear rather than resting under it.

The two conditional blocks matter: an ordinary wallet has neither, a mining or
exchange address has both, so the screen has two quite different heights.

## Rules that are settled — please keep them

- **The hero is one neutral for every coin**, with white ink. The coin colour
  paints the icon, the home-screen card and the accents, never the balance
  surface. This was decided against two alternatives: white cannot be used on
  Bellscoin gold (1.64:1), and deepening the gold to earn white broke the brand.
- **The balance never abbreviates its magnitude.** Past eight whole digits it
  drops sub-coin decimals — `4,946,461,530.06954205` becomes `4,946,461,530` —
  but never becomes `4.9B`. It stays exact to a whole coin.
- **No approximation marks.** No `~` or `≈` in front of amounts.
- **A shortened list says so.** The truncation notice states both numbers and
  that the balance is unaffected: "Showing 1,009 of about 31,643 transactions.
  The balance is exact."
- **Payouts lead with freshness**, not the total. Whether payouts are still
  arriving is the question a miner opens the wallet to ask.
- **Chrome does not take the coin's colour.** Buttons, links, switches and the
  sync chip take whatever the active theme passes down, on light and dark
  alike. The coin colour is reserved for the marks that identify the coin: its
  icon, and its card on the home list. Recolouring the accent per coin meant
  every theme's contrast pairing had to be re-earned against every coin colour,
  which is a matrix, and it leaked — a white-on-gold Save button at 1.64:1, and
  a dock pill that came out white on one screen and dark on the next for the
  same wallet.
- **Direction is green up, red down, from the theme** — the same two colours a
  received and a sent amount use in the list, so a rise in the hero and a
  payment below it are not two unrelated greens. On the hero they pass through
  `onHeroSignal`, which lifts a colour toward white only as far as it takes to
  clear 4.5:1 on the hero surface; every bundled theme passes untouched. The
  sign is always printed too: colour alone is not a way to say "down".

## Constraints that will bite you

- **Balances are enormous.** Pepecoin runs to thirteen digits before the decimal
  point, and amounts carry eight decimals. Design at
  `4,946,461,530.06954205 PEP`, not at Bitcoin-sized numbers. In transaction
  rows the amount is capped at 52% of the row so a long number cannot crush the
  Sent/Received label; the payouts total is capped at 42%.
- **Addresses are long and get truncated in the middle**
  (`PnBFXec7tVQv…GFnwoo`). BitFinite addresses carry a `bfx:` prefix.
- **Both themes ship**, and the hero is the same neutral in each — it reads as a
  distinct block on light, and closer to the page on dark.

## The questions this brief opened, and how they were settled

1. **Accent on the page ground** — the *See all* link and the dock accents took
   the raw coin colour, sitting at **1.64:1** on Bellscoin. Settled by removing
   the coin from the chrome entirely rather than by tuning it: see the rule
   above. The mechanism that did the recolouring (`CoinThemed`, twelve accent
   slots overridden per coin-scoped route) is gone.
2. **What the price chart earns** — it was a 219px card around a 36px line. It
   is now two rows of the hero: price and change beside the range pills, then a
   full-width 32px line. The intermediate step, a single 44px row with the line
   squeezed between the price and the pills, was wrong in the other direction —
   a sparkline about a third of the hero's width shows no shape at all, which
   is the only thing a sparkline is for.
3. **Hero density** — the balance settled at 30px, down from 52. It is the
   largest thing on the screen by more than double regardless, so the hierarchy
   comes from the gap and the weight rather than the absolute size. The break
   is at the decimal separator, so the headline is the whole coins and
   everything under one coin is the quiet part.

## Do not

- Do not invent component APIs or claim these map to real widgets. They do not.
- Do not use the coin colour as a large fill behind text. That is the mistake
  this design already corrected.
