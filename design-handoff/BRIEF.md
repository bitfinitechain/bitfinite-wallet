# BitFinite Wallet — design brief

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
2. **Hero** — price sparkline with 24H/7D/30D range pills, `FULL BALANCE` label
   with a privacy eye and a sync-status pill, the balance, a fiat line with a
   today delta, and an address chip. Rounded 32px foot.
3. **Payouts row** — *conditional.* Only on a wallet mining has paid. One line:
   how recent, how many, how much.
4. **Transactions** header with a *See all* link.
5. **Truncation notice** — *conditional.* Only when history was capped.
6. **Day headers** (`TODAY`, `YESTERDAY`, `31 AUG`) with transaction rows under
   each: icon, direction, time, amount, fiat.
7. **Receive / Send dock** floating over the bottom. The last row pads itself
   past it, and content fades out beneath it.

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

## Constraints that will bite you

- **Balances are enormous.** Pepecoin runs to thirteen digits before the decimal
  point, and amounts carry eight decimals. Design at
  `4,946,461,530.06954205 PEP`, not at Bitcoin-sized numbers. In transaction
  rows the amount is capped at 52% of the row so a long number cannot crush the
  Sent/Received label; the payouts total is capped at 45%.
- **Addresses are long and get truncated in the middle**
  (`PnBFXec7tVQv…GFnwoo`). BitFinite addresses carry a `bfx:` prefix.
- **Both themes ship**, and the hero is the same neutral in each — it reads as a
  distinct block on light, and closer to the page on dark.

## Open, and genuinely yours to decide

1. **Accent on the page ground.** The *See all* link and the dock accents take
   the raw coin colour, so on Bellscoin they sit at **1.64:1** on the light
   page. This is the last unresolved contrast problem in the app.
2. **What the price chart earns.** Its card spends about 219px to show a 36px
   sparkline; the rest is padding, the price row and the range pills. It is the
   largest single block in the hero. BitFinite has no price data, so its hero
   already ships without one — a free control for how the screen reads without.
3. **Hero density.** The balance has already come down 52 → 44 → 36 → 30px.

## Do not

- Do not invent component APIs or claim these map to real widgets. They do not.
- Do not use the coin colour as a large fill behind text. That is the mistake
  this design already corrected.
