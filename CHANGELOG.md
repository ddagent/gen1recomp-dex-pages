# Changelog

Format: [keep a changelog](https://keepachangelog.com/en/1.1.0/).
Version headings match `manifest.json`'s `version`.

## 1.7.1

### Added

- `entryOnly` splits what `forceOwned` used to decide at once: the entry
  page can be opened in full while the pages behind it keep following real
  ownership. A glimpse in battle uses it; a zoo placard does not, because
  the sign exists to show you the exhibit.
## 1.7.0

### Fixed

- **CATCH ODDS drew its column headers and no rows.** `data.balls` is the
  mod registry, not extracted ROM data: it holds whatever a mod overrode and
  nothing else. This page picked it over the stock table wholesale, so an
  empty registry meant an empty page. It now merges the two the way
  `BattleState:ballDef` does, per ball -- a mod that retunes GREAT BALL
  changes that one row and the other four keep their stock numbers.

### Added

- **A zoo placard shows the whole entry.** The FUCHSIA signs open a dex page
  on purpose, so hiding it behind ownership defeats the exhibit. A sign now
  opens the full entry; a glimpse in battle is still only a glimpse.
## 1.6.0

### Fixed

- **The evolution sprite was the wrong colour** -- MAGNETON drew brown, and
  only the fragments that happened to overlap one rectangle drew right. The
  Game Boy colours by zone, not by sprite: the vanilla page pins the mon
  palette to tiles (1,1)-(8,8), where *its* sprite sits, and the picker
  draws a different mon centred lower down. The zone now follows the picker,
  and names the species the cursor is on rather than the one whose entry
  this is. Placement is snapped to whole tiles, because a zone is measured
  in tiles and half a tile off colours half the mon.
- `Sprites.path` returns two values and the call was wrapped in parentheses,
  which truncated it to one and dropped `trueColor`. A full-colour
  replacement sprite would have been put through the recolour pass.
- **`OWNED DATA ONLY` now defaults to on.** Off was incoherent: the vanilla
  page says "Data unknown." for a species you have not caught while the
  pages behind it list its whole movelist, every TM it can take, its wild
  locations and its catch odds. The gate is the engine's own -- owned, not
  merely seen -- so the extra pages arrive exactly when the description
  does. Still switchable.

## 1.5.0

### Added

- **UP and DOWN step through the dex** on any page with nothing to scroll,
  keeping the page you are on -- so you can hold DOWN comparing catch odds,
  or type matchups, across species without going back to the front of each
  entry. The sprite loads and the cry plays, the way opening an entry does.
- Only species you have **seen** are in the order, by dex number. Browsing
  into an unseen mon would hand over data the dex itself is still hiding.
  Opening a page for a species you have not seen -- which is exactly what
  battle_dex does on a first encounter -- does not browse at all, because
  stepping off it would be a non-sequitur.

### Note

On pages that scroll, UP and DOWN still scroll. On pages that do not they
previously did nothing at all, so this takes nothing away.

## 1.4.0

### Changed

- The catch table has a blank row above each block. Eleven unbroken rows of
  numbers read as one slab. This pushes the page past a single screen, which
  is fine -- it scrolls like the movelist, with the same `▼`.
- The vanilla page's hint moved to the bottom-right corner and now reads
  `1/7 ▶` rather than sitting in the gap above the description. That corner
  is provably free: all 151 descriptions are exactly six lines, so the last
  row the engine draws ends at y=130 and nothing ever reaches y=134.

### Note

Move tutors do not exist in Gen 1 -- they arrive in Gen 2 -- so START moves,
the level-up learnset and TM/HM are the complete set of ways a species can
learn anything here. The only "tutor" in the engine is the Viridian old
man's catch tutorial, which teaches nothing.

## 1.3.0

### Changed

- **A moves to the next page and wraps.** It used to close the entry, which
  B already did, so the more reachable of the two buttons was spent on a job
  that was already covered. `D-PAD ONLY` restores the old behaviour.
- **The page name is at the top now, and only there.** It used to be at the
  bottom as well, and the species name sat at the top beside it -- which
  said the same thing twice and still did not fit (`PIKACHU` clipped to
  `PIKAC` on the type page). You reached this page from that species, so
  naming it again spends five characters on something already known.
- **The bottom line is scroll state and nothing else**, using the game's own
  `▼` and `▲`. 1.2.0 had no arrows because the charmap has no `<` or `>` --
  but it does have the triangles, which was never checked.
- **The vanilla page carries a single `▶`** in the 8px band between `WT` and
  the description, the one row the engine never draws into. Nothing else
  hinted the other pages existed.

### Fixed

- **The catch table's third column meant two things at once.** `SLP` was
  "1HP *and* asleep", so the cost of sleep could not be read on its own at
  any HP. It is now two blocks (`AWAKE` / `ASLEEP`) of two columns (`FULL` /
  `1HP`): one variable per axis, every cell defined by its block and column.
- Balls are in bag order. Sorting by the internal `randMax` had put SAFARI
  between GREAT and ULTRA.
- The always-catch row and the SLP/FRZ footnote are gone.

### Added

- **The evolution page has a cursor.** UP/DOWN moves between relations and
  the sprite follows, which is what makes an Eevee page possible -- three
  targets, one picture. The method moves with the cursor rather than being
  listed once per row.

## 1.2.0

Everything here was found by screenshotting all seven pages on real
hardware. None of it was visible to the test suite as it stood.

### Fixed

- The Game Boy charmap has **no `%`, `<` or `>` glyph**. They printed as
  nothing: `% PER THROW` rendered as ` PER THROW`, and the footer's `<` and
  `>` arrows never appeared at all. The catch heading now reads
  `CHANCE PER THROW` and the arrows are gone -- `2/7` already says where you
  are. A test now rejects any character outside the set the font has.
- The header collided the same way the rows used to: `PIKACHU` and
  `TYPE MATCHUP` are 19 characters together and the row holds 18, so it
  drew `PIKACHUYPE MATCHUP`. The species name is now clipped to what the
  title leaves.
- The footer collided with the scroll counter -- `CATCH ODDS1/1`. The title
  is clipped to what the counter leaves, and a page that fits on one screen
  no longer prints a counter at all (`1/1` read as part of the title).
- Map labels are camelCase, so uppercasing welded them shut:
  `VIRIDIANFOREST`, `POWERPLANT`. They split on the case change first.
- The catch page lost its last line. Rows per screen went from 10 to 11 and
  the footer moved from y=130 to y=132, which the layout had room for.

### Changed

- **Nothing is drawn over the vanilla page any more.** The `1/7 DATA`
  footer sat directly under the last line of the dex description, close
  enough to read as the description being truncated -- and the engine draws
  entry text as far down as y=132, exactly where the footer was, so a
  longer entry would have collided outright.

## 1.1.0

### Fixed

- Text ran into itself on three pages. The screen is 160px of an 8px
  fixed-width font -- exactly 20 characters -- and LOCATIONS, EVOLUTION and
  CATCH ODDS each put two fields on one line that together needed more than
  that. `VIRIDIAN FOREST` alone is 15, and `GRASS L3-5` right-aligned back
  into the middle of it.
- LOCATIONS and EVOLUTION now put the detail on its own indented line under
  the name, so nothing is truncated and nothing overlaps.
- CATCH ODDS drops the redundant `BALL` from every row (`POKE`, `GREAT`),
  moves the always-catch balls to a footer line instead of a table row, and
  prints the percent sign once in the heading rather than in every cell --
  columns sit 32px apart and `100%` is exactly 32px, so a per-cell sign made
  `95` and `100` print as `95%100%`.
- Type matchups only pair two names on a row when they actually fit;
  `ELECTRIC FIGHTING` is 19 characters and the row holds 18.

### Changed

- Every two-field row now measures its right-hand field first and clips the
  left one to what is left over. Overlap is impossible by construction now,
  rather than avoided by choosing short strings and hoping.

## 1.0.0

### Added

- Six pages behind LEFT and RIGHT on the POKéDEX entry: type matchups,
  catch odds, locations, level-up moves, TMs and HMs, and evolution.
- `DEX PAGE BUTTON` (LEFT/RIGHT, A CYCLES, OFF), a toggle per page, and
  `OWNED DATA ONLY`.
- UP/DOWN scrolls a page that runs past one screen.

### Note

The vanilla page is not reimplemented. Page 1 holds a real `DexEntryMenu`
instance and calls its `:draw()`, so the sprite, the height, the weight and
the ROM description are whatever the engine draws — if the engine's page
changes, this one follows. Its `:update` is never called, which is the only
part being replaced.

Nothing recomputes a game formula. Catch percentages come from
`Catching.chance` and matchups from `TypeChart.effectiveness`, so a mod that
adds a ball or edits the type chart is reflected here without a change.
