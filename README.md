# Dex Pages

> This mod was coded by AI.

Adds pages to the POKéDEX entry. Press **A** to step through them, **B** to
close, **UP** and **DOWN** to move between the POKéMON you have seen.

The page you already know is untouched and still comes first — same sprite,
same height and weight, same description. Nothing is taken away to make room.

![The vanilla entry page, unchanged, with a small page counter in the corner](docs/page-1-data.png)

The only mark on it is `1/7 ▶` in the corner, so you know the rest are there.

## The pages

### Type matchup

What hurts it and what barely scratches it, worked out from the game's own
type chart.

![The type matchup page for PIKACHU](docs/page-2-type-matchup.png)

### Catch odds

Your real chance for a single throw, as a percentage, for every ball —
awake and asleep, at full health and at 1 HP.

![The catch odds page, showing awake and asleep blocks](docs/page-3-catch-odds.png)

This is the number people normally have to look up. You can see for yourself
whether it is worth another Great Ball or whether you should put it to sleep
first. Note that in Gen 1 a Great Ball can beat an Ultra Ball at full health
and lose to it at 1 HP — that is the real game's maths, not a mistake.

### Locations

Every route it appears on and at what levels, worked backwards from the
encounter tables. Surfing and all three rods count.

![The locations page, listing places and levels](docs/page-4-locations.png)

A species you can only get from an evolution or a trade says so.

### Level moves

Everything it learns by levelling, and when.

![The level-up movelist for PIKACHU](docs/page-5-level-moves.png)

### TM and HM

Every machine it can take, by number.

![The TM and HM list for PIKACHU](docs/page-6-tm-and-hm.png)

Gen 1 has no move tutors, so these two pages and the starting moves are the
complete set of ways anything learns anything.

### Evolution

What it becomes, and what it came from.

![The evolution page, showing RAICHU and the THUNDERSTONE it needs](docs/page-7-evolution.png)

Your own dex can tell you what a mon becomes; it cannot tell you what it came
from, which is the half you actually want when you find something halfway up
a chain. Where there is more than one outcome — EEVEE — **UP** and **DOWN**
move a cursor and the picture follows.

## Moving around

| Button | What it does |
| --- | --- |
| **A** | next page, wrapping round |
| **B** | close |
| **LEFT** / **RIGHT** | back and forward a page |
| **UP** / **DOWN** | scroll a long page, or step through the dex when there is nothing to scroll |

Stepping through the dex keeps the page you are on, so you can hold **DOWN**
comparing catch odds — or type matchups — across species without reopening
each entry. Only POKéMON you have seen are in the order.

## Options

Set these in the in-game mod manager.

| Option | | Default |
| --- | --- | --- |
| `DEX PAGE BUTTON` | A AND D-PAD · D-PAD ONLY · OFF | A AND D-PAD |
| `TYPE MATCHUP PAGE` | show it | on |
| `CATCH ODDS PAGE` | show it | on |
| `LOCATIONS PAGE` | show it | on |
| `LEVEL MOVES PAGE` | show it | on |
| `TM/HM PAGE` | show it | on |
| `EVOLUTION PAGE` | show it | on |
| `OWNED DATA ONLY` | wait until you own one | on |

`D-PAD ONLY` gives A back its old job of closing the entry, if you would
rather it worked that way.

`OWNED DATA ONLY` follows the game's own rule. The vanilla page hides height,
weight and the description until you own a species, so the extra pages wait
for the same moment — otherwise the front page says "Data unknown." while the
pages behind it hand over the whole movelist.

## Notes

- **Nothing here is invented.** The catch percentages come from the game's
  own catch routine and the matchups from its own type chart, so if another
  mod changes a ball or edits the chart, these pages change with it.
- **Long pages scroll.** A `▼` in the corner means there is more below.
- **It cannot be switched off entirely.** Turning every page off leaves the
  vanilla entry, not a blank screen.
- **Only one mod can own the dex page.** If you run another mod that replaces
  the POKéDEX entry screen, whichever loads last wins. Run one or the other,
  not both.
- Works on Red, Blue and Yellow.

## Install

Download the `.zip` from
[Releases](https://github.com/ddagent/gen1recomp-dex-pages/releases) and
install it from the game: **MODS → Import mod .zip**. After that the launcher
offers **Update** whenever a new version appears.
