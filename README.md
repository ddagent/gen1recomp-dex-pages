# Dex Pages

> This mod was coded by AI.

Adds pages to the POKéDEX entry. Press **RIGHT** to move through them and
**LEFT** to come back.

The page you already know is untouched and still comes first — same sprite,
same height and weight, same description. Nothing is taken away to make room.

| Page | What is on it |
| --- | --- |
| **DATA** | the entry you have always had |
| **TYPE MATCHUP** | what it takes double damage from, and what barely scratches it |
| **CATCH ODDS** | your real chance per throw, as a percentage, for every ball |
| **LOCATIONS** | every route it appears on, and at what levels |
| **LEVEL MOVES** | everything it learns, and when |
| **TM AND HM** | every machine it can take, by number |
| **EVOLUTION** | what it becomes, and what it came from |

Try it: open any POKéMON you own and press RIGHT.

## What it does

**Catch odds** are the number people usually have to look up. It is your
chance for a single throw at full health, at 1 HP, and at 1 HP asleep — so
you can see for yourself whether it is worth another Great Ball or whether
you should put it to sleep first. Sleep and freeze help the most, and they
help most when the mon is nearly out of HP.

**Locations** works backwards from the encounter tables, so it lists the
places rather than the other way round. Surfing and all three rods count.
A species you can only get from an evolution or a trade says so.

**Evolution** shows both directions. Your own dex can tell you what a mon
becomes; it cannot tell you what it came from, which is the half you
actually need when you find something halfway up a chain.

Nothing here is invented. The catch percentages come from the game's own
catch routine and the matchups from its own type chart, so if a mod changes
either, these pages change with it.

## Options

Set these in the in-game mod manager.

| Option | | Default |
| --- | --- | --- |
| `DEX PAGE BUTTON` | LEFT/RIGHT · A CYCLES · OFF | LEFT/RIGHT |
| `TYPE MATCHUP PAGE` | show it | on |
| `CATCH ODDS PAGE` | show it | on |
| `LOCATIONS PAGE` | show it | on |
| `LEVEL MOVES PAGE` | show it | on |
| `TM/HM PAGE` | show it | on |
| `EVOLUTION PAGE` | show it | on |
| `OWNED DATA ONLY` | hide the new pages until you own one | off |

`A CYCLES` is there if you would rather step through with A, the way some
other dex mods do. On LEFT/RIGHT — the default — A and B still close the
entry exactly as they always have.

`OWNED DATA ONLY` extends the game's own rule. The vanilla page already
hides height, weight and the description until you own a species; turn this
on and the new pages wait for the same moment, so the dex cannot be used to
scout something you have never met.

## Notes

- **Long pages scroll.** Press DOWN for the next screenful of moves or
  machines, UP to come back. The footer shows where you are.
- **It cannot be switched off entirely.** Turning every page off leaves the
  vanilla entry, not a blank screen.
- **Only one mod can own the dex page.** If you run another mod that
  replaces the POKéDEX entry screen, whichever loads last wins. Run one or
  the other, not both.
- Works on Red, Blue and Yellow.

## Install

Download the `.zip` from
[Releases](https://github.com/ddagent/gen1recomp-dex-pages/releases) and
install it from the game: **MODS → Import mod .zip**. After that the launcher
offers **Update** whenever a new version appears.
