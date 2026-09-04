# Watch-only limits

This is a personal wallet. It holds your coins, and it can watch addresses you
care about. It is not an exchange or treasury monitoring tool, and this page is
honest about where that line falls, with the numbers we measured rather than a
general warning.

## What always holds

**The balance is exact.** It is the sum of the address's unspent outputs, not a
running total derived from the transactions on screen. A shortened history does
not make the balance approximate.

## Watching a busy address

It works, within limits, and the app states them on screen rather than hiding
them.

**History is capped at the most recent 1,000 transactions per sync.** Above
that the wallet shows a notice saying how many it is displaying, how many exist,
and that the balance is unaffected. Walking a full pool history is not a
practical operation on a phone: measured against real addresses, one with 31,629
transactions would have taken about ten hours.

**The first balance can take minutes.** The balance is not known until every
unspent output has been fetched, so nothing can be shown before that finishes. A
mining pool address with 45,376 transactions took roughly eight minutes to
produce its first balance on a phone. While it works the wallet says "Syncing"
rather than showing a zero it cannot vouch for.

## Where it stops working

**Some addresses cannot be read at all.** Public Electrum servers refuse to
enumerate very large unspent-output sets. The Bitcoin genesis address answers
`Too many unspent outputs` and no balance is computable from it by any light
wallet talking to that server. The wallet keeps saying "Syncing" instead of
inventing a number.

**Public servers throttle.** Heavy addresses draw `server busy` and
`excessive resource usage` responses. A light wallet is a guest on
infrastructure someone else pays for, and a pool address asks far more of it
than a personal wallet does.

## Not recommended for

- Exchange vaults and custodial hot wallets.
- Large institutional addresses, or any address holding funds that are not
  yours.
- Anything needing continuous, authoritative monitoring, or an alert you would
  act on.

For those, run an indexer or use a block explorer. Both are built to answer
questions about arbitrary addresses at arbitrary scale. This wallet is built to
look after yours.

## What a pool operator can reasonably do

Watching your own pool payout address works and is a supported case. Expect the
capped history, expect the first sync to take a while, and read the balance
rather than counting the rows.
