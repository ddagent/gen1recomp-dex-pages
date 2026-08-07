# Dex Pages

> This mod was coded by AI.

Adds pages to the POKéDEX entry. **A** moves through them, **B** closes.

Your usual page is untouched and still comes first. The `1/7 ▶` in the
corner is the only mark on it.

![The vanilla POKeDEX entry for PIKACHU, unchanged, with a small page counter in the corner](docs/page-1-data.png)

## The pages

### Type matchup

![Type matchup: PIKACHU takes 2x from GROUND and 1/2x from ELECTRIC and FLYING](docs/page-2-type-matchup.png)

### Catch odds

![Catch odds: a table of percentages per ball, awake and asleep, at full HP and at 1HP](docs/page-3-catch-odds.png)

### Locations

![Locations: POWER PLANT at L20-24 and VIRIDIAN FOREST at L3-5](docs/page-4-locations.png)

### Level moves

![The level-up movelist for PIKACHU, from THUNDERSHOCK at START to THUNDER at L41](docs/page-5-level-moves.png)

### TM and HM

![The TM and HM list for PIKACHU, by machine number](docs/page-6-tm-and-hm.png)

### Evolution

![Evolution: INTO RAICHU by THUNDERSTONE, with RAICHU's sprite](docs/page-7-evolution.png)

## Buttons

| | |
| --- | --- |
| **A** | next page, wrapping round |
| **B** | close |
| **LEFT** / **RIGHT** | back and forward a page |
| **UP** / **DOWN** | scroll a long page, pick an evolution, or step to the next POKéMON |

Stepping through the dex keeps the page you are on, so you can hold **DOWN**
comparing catch odds across species without reopening each entry. Only ones
you have seen are in the order.

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

`D-PAD ONLY` gives A back its old job of closing the entry.

`OWNED DATA ONLY` follows the game's own rule — the vanilla page hides height,
weight and the description until you own a species, so the extra pages wait
for the same moment.

## Notes

- **The numbers are the game's own.** They come from its catch routine and
  its type chart, so a mod that changes a ball or edits the chart changes
  these pages with it.
- **Turning every page off leaves the vanilla entry**, not a blank screen.
- **Only one mod can own the dex page.** If you run another that replaces the
  POKéDEX entry screen, whichever loads last wins. Run one or the other.
- Works on Red, Blue and Yellow.

## Install

Download the `.zip` from
[Releases](https://github.com/ddagent/gen1recomp-dex-pages/releases) and
install it from the game: **MODS → Import mod .zip**. After that the launcher
offers **Update** whenever a new version appears.
