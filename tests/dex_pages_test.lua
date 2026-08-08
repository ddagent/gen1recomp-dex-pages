-- Standalone: luajit mods/dex_pages/tests/dex_pages_test.lua
--
-- ROM-free: everything runs against tests/fixture_data through the real
-- Loader and the real Screens resolver, so a green run means the mod really
-- registers a screen the engine would really resolve.
--
-- The pages are asserted on the rows they build rather than on pixels: a
-- row list is the whole contract between the joins and the renderer, and a
-- drawing test would pass on a page that computed the wrong number.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Screens = require("src.ui.Screens")

local Data = T.fixtures.fresh()
local A, B, C = "FIXMON_A", "FIXMON_B", "FIXMON_C"

local run = T.sdk.loadMod("mods/dex_pages", { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")

local rows = run.loader.exports.dex_pages.rows
T.check(type(rows) == "table", "exports its row builders")

local function setOptions(over)
  run.loader.modOptions.dex_pages = over or {}
end

-- collect the plain text of a row list, for order-insensitive membership
local function texts(list)
  local out = {}
  for _, row in ipairs(list) do out[#out + 1] = row.text end
  return table.concat(out, "|")
end

local function find(list, needle)
  for _, row in ipairs(list) do
    if row.text and row.text:find(needle, 1, true) then return row end
  end
  return nil
end

-- ---------------------------------------------------------------- the screen

-- ~~~ registration

T.check(Data.screens and Data.screens.DexEntryMenu ~= nil,
        "registers a DexEntryMenu replacement")
Screens.invalidate()

-- ------------------------------------------------------------ type matchups

-- ~~~ type matchups

do
  -- FIXMON_A is GRASS; the fixture chart gives FIRE 2x into GRASS and
  -- WATER 1/2x into GRASS
  local list = rows.types(Data, Data.pokemon[A])
  T.check(find(list, "TAKES 2x") ~= nil, "grass mon has a 2x bucket")
  local twice = false
  for i, row in ipairs(list) do
    if row.text == "TAKES 2x" and list[i + 1] then
      twice = list[i + 1].text:find("FIRE", 1, true) ~= nil
    end
  end
  T.check(twice, "FIRE is listed under 2x for a GRASS mon")

  local half = false
  for i, row in ipairs(list) do
    if row.text == "TAKES 1/2x" and list[i + 1] then
      half = list[i + 1].text:find("WATER", 1, true) ~= nil
    end
  end
  T.check(half, "WATER is listed under 1/2x for a GRASS mon")

  -- a bucket with no members must not print its heading
  T.check(not find(list, "TAKES 4x"), "empty buckets are omitted")
end

-- --------------------------------------------------------------- catch odds

-- ~~~ catch odds

do
  -- The table is two blocks (AWAKE / ASLEEP) of two columns (FULL / 1HP).
  -- One variable per axis: the old third column meant "1HP *and* asleep",
  -- which changed two things at once and could not be read on its own.
  local list = rows.catch(Data, Data.pokemon[A])
  T.check(list[1] and list[1].head, "leads with a heading")

  local blocks = {}
  local current = nil
  for _, row in ipairs(list) do
    if row.head and row.cols then
      current = { label = row.text, balls = {} }
      blocks[#blocks + 1] = current
      T.eq(#row.cols, 2, "each block has two columns")
    elseif row.cols and current then
      current.balls[#current.balls + 1] = row
    end
  end
  T.eq(#blocks, 2, "an AWAKE block and an ASLEEP block")
  T.eq(blocks[1].label, "AWAKE", "awake first")
  T.eq(blocks[2].label, "ASLEEP", "asleep second")
  T.check(#blocks[1].balls > 0, "the awake block lists balls")
  T.eq(#blocks[1].balls, #blocks[2].balls, "both blocks list the same balls")

  local awake, asleep = blocks[1].balls[1], blocks[2].balls[1]
  local full, low = awake.cols[1], awake.cols[2]
  T.check(type(full) == "number", "odds are a number")
  T.check(full >= 0 and full <= 100, "odds are a percentage, not a fraction")
  T.check(low > full, "a hurt mon is easier to catch than a healthy one")
  -- the reason the layout changed: sleep can now be read at full HP, on its
  -- own, without the HP term moving underneath it
  T.check(asleep.cols[1] > full, "sleep helps at full HP")
  T.check(asleep.cols[2] > low, "and still helps at 1HP")
end

do
  -- Blocks are separated by a blank row.  This pushes the page past one
  -- screen, which is fine -- it scrolls like the movelist -- and is the
  -- point: eleven unbroken rows of numbers read as a single slab.
  local list = rows.catch(Data, Data.pokemon[A])
  local blanks = 0
  for i, row in ipairs(list) do
    if row.text == "" then
      blanks = blanks + 1
      local next_row = list[i + 1]
      T.check(next_row and next_row.head and next_row.cols,
              "a blank row always introduces a block header")
    end
  end
  T.eq(blanks, 2, "one blank above each of the two blocks")
end

do
  -- both the always-catch row and the SLP/FRZ tip are gone
  local list = rows.catch(Data, Data.pokemon[A])
  T.check(find(list, "MASTER") == nil, "no always-catch ball in the table")
  T.check(find(list, "always") == nil, "and no always-catch footnote")
  T.check(find(list, "help most") == nil, "no SLP/FRZ tip line")
end

do
  -- bag order, not internal randMax order, which put SAFARI before ULTRA
  local list = rows.catch(Data, Data.pokemon[A])
  local seen = {}
  for _, row in ipairs(list) do
    if row.cols and not row.head then seen[#seen + 1] = row.text end
  end
  local order = table.concat(seen, ",")
  local poke = order:find("POKE", 1, true)
  local ultra = order:find("ULTRA", 1, true)
  local safari = order:find("SAFARI", 1, true)
  if poke and ultra then T.check(poke < ultra, "POKE before ULTRA") end
  if ultra and safari then
    T.check(ultra < safari, "ULTRA before SAFARI (bag order)")
  end
end

do
  -- catchRate 0 is the Gen 1 "never" (the tower GHOST), and dividing by it
  -- would be worse than saying so
  local uncatchable = {}
  for k, v in pairs(Data.pokemon[A]) do uncatchable[k] = v end
  uncatchable.catchRate = 0
  local list = rows.catch(Data, uncatchable)
  T.check(find(list, "Cannot be caught") ~= nil, "a 0 catch rate says so")
end

-- ---------------------------------------------------------------- locations

-- ~~~ locations

do
  -- the fixture puts FIXMON_A in FIX_ROUTE grass at L3
  local list = rows.locations(Data, Data.pokemon[A])
  -- the fixture's label is "FixRoute": camelCase splits, then uppercases
  local at = nil
  for i, row in ipairs(list) do
    if row.text and row.text:find("FIX ROUTE", 1, true) then at = i; break end
  end
  T.check(at ~= nil, "finds the fixture route")
  -- the detail is its own line under the name, not the same line
  local detail = list[at + 1]
  T.check(detail and detail.sub, "the detail is a second line")
  T.check(detail.text:find("GRASS", 1, true) ~= nil,
          "labels the encounter method")
  T.check(detail.text:find("L3", 1, true) ~= nil, "shows the level")
end

do
  -- FIXMON_B is in no encounter table at all
  local list = rows.locations(Data, Data.pokemon[B])
  T.check(find(list, "Not in the wild") ~= nil,
          "an unencounterable species says so instead of showing nothing")
end

do
  -- one species in two slots of the same table collapses to a range rather
  -- than printing the same map twice
  local data = T.fixtures.fresh()
  data.encounters = { FIX_ROUTE = { grass = { rate = 25, slots = {
    { level = 3, species = A }, { level = 9, species = A } } } } }
  local list = rows.locations(data, data.pokemon[A])
  T.eq(#list, 2, "duplicate slots collapse to one place (name + detail)")
  T.check(list[2].text:find("L3-9", 1, true) ~= nil, "and widen to a range")
end

-- -------------------------------------------------------------- level moves

-- ~~~ level moves

do
  local list = rows.levelMoves(Data, Data.pokemon[A])
  local start = find(list, "TACKLE")
  T.check(start ~= nil, "lists the starting move")
  T.check(texts(list):find("EMBER", 1, true) ~= nil, "lists a learnset move")
  local later = find(list, "EMBER")
  T.check(later.note == "L7", "tags the level it is learned at")
end

-- ------------------------------------------------------------------- TM/HM

-- ~~~ machines

do
  local list = rows.machines(Data, Data.pokemon[A])
  T.check(find(list, "CUT") ~= nil, "lists a TM the species can learn")
end

do
  local list = rows.machines(Data, Data.pokemon[B])
  T.check(find(list, "No TMs") ~= nil, "an empty tmhm list says so")
end

-- --------------------------------------------------------------- evolution

-- ~~~ evolution

do
  -- FIXMON_A evolves into FIXMON_B at L16
  local list = rows.evolution(Data, Data.pokemon[A])
  local at = nil
  for i, row in ipairs(list) do
    if row.text and row.text:find("INTO", 1, true) then at = i; break end
  end
  T.check(at ~= nil, "shows what it becomes")
  T.check(list[at].text:find("FIXMON B", 1, true) ~= nil, "names the target")
  T.check(list[at + 1] and list[at + 1].sub,
          "the method is its own line, not crammed alongside")
end

do
  -- the reverse index is the half a player cannot get from their own dex
  local list = rows.evolution(Data, Data.pokemon[B])
  T.check(find(list, "FROM") ~= nil, "shows what it came from")
end

do
  local list = rows.evolution(Data, Data.pokemon[C])
  local terminal = find(list, "Does not evolve") or find(list, "FROM")
  T.check(terminal ~= nil, "a species with no evolutions still says something")
end

-- ----------------------------------------------------------------- options

-- ~~~ options

local Screen = run.loader.exports.dex_pages.screen

local function newGame()
  return {
    data = Data,
    save = { pokedex = { seen = {}, owned = { [A] = true } } },
    input = { wasPressed = function() return false end },
    stack = { pop = function() end },
  }
end

-- Screen.new builds a real DexEntryMenu, which wants love graphics; the
-- page list is the part under test, so drive it on a bare instance.
local function screenFor(def, owned)
  local self = setmetatable({ game = newGame(), def = def,
                              owned = owned ~= false, index = 1, scroll = 0 },
                            Screen)
  return self
end

do
  setOptions({})
  local s = screenFor(Data.pokemon[A])
  T.eq(#s:pages(), 7, "all seven pages by default")
  T.check(s:pages()[1].vanilla, "the vanilla page is always first")
end

do
  setOptions({ show_catch = false, show_machines = false })
  local s = screenFor(Data.pokemon[A])
  T.eq(#s:pages(), 5, "switching two pages off drops exactly two")
  for _, page in ipairs(s:pages()) do
    T.check(page.key ~= "catch", "the catch page is gone")
  end
end

do
  -- every extra page off still leaves the dex the player started with
  setOptions({ show_types = false, show_catch = false, show_locations = false,
               show_moves = false, show_machines = false,
               show_evolution = false })
  local s = screenFor(Data.pokemon[A])
  T.eq(#s:pages(), 1, "the vanilla page cannot be switched off")
  T.check(s:pages()[1].vanilla, "and it is the vanilla one")
end

do
  setOptions({ page_button = "off" })
  local s = screenFor(Data.pokemon[A])
  T.eq(#s:pages(), 1, "OFF leaves the dex exactly as it was")
end

do
  -- the vanilla page hides the description until owned; the extra pages
  -- follow that gate only when the player asks them to
  setOptions({ owned_only = true })
  local unseen = screenFor(Data.pokemon[A], false)
  T.eq(#unseen:pages(), 1, "an unowned species shows only the vanilla page")
  local owned = screenFor(Data.pokemon[A], true)
  T.check(#owned:pages() > 1, "an owned species still gets the extra pages")

  -- On by default: off is incoherent, because the vanilla page says
  -- "Data unknown." for an uncaught species while the pages behind it would
  -- be listing its stats, locations and full movelist.
  setOptions({})
  local byDefault = screenFor(Data.pokemon[A], false)
  T.eq(#byDefault:pages(), 1,
       "by default an uncaught species shows only the page the engine gates")
  T.check(byDefault:pages()[1].vanilla, "and that page is the vanilla one")

  setOptions({ owned_only = false })
  local opened = screenFor(Data.pokemon[A], false)
  T.check(#opened:pages() > 1, "turning the gate off shows them anyway")
end

-- -------------------------------------------------------------- navigation

-- ~~~ navigation

do
  setOptions({})
  local s = screenFor(Data.pokemon[A])
  s.index = 1
  s:step(1)
  T.eq(s.index, 2, "RIGHT moves forward")
  s:step(-1)
  T.eq(s.index, 1, "LEFT moves back")
  s:step(-1)
  T.eq(s.index, 7, "and wraps around the start")
  s:step(1)
  T.eq(s.index, 1, "and around the end")
end

do
  -- a page switch has to reset the scroll, or a short page inherits a long
  -- page's offset and draws blank
  setOptions({})
  local s = screenFor(Data.pokemon[A])
  s.scroll = 20
  s:step(1)
  T.eq(s.scroll, 0, "changing page resets the scroll")
end

-- ~~~ fitting
--
-- The renderer clips, so overlap is impossible by construction.  What that
-- cannot tell you is whether real content *needed* clipping -- a page that
-- silently loses the end of every map name looks fine to a draw test and
-- broken to a player.  These cases use the longest strings Gen 1 actually
-- contains and assert nothing has to be cut.

do
  local Font = require("src.render.Font")
  local W = 160
  local BUDGET = W - 16          -- 8px margin each side, as the renderer uses

  -- longest real names: VIRIDIAN FOREST (15), THUNDERSTONE (12),
  -- THUNDERSHOCK (12), SAFARI BALL (11)
  local data = T.fixtures.fresh()
  data.maps.FIX_ROUTE.label = "Viridian Forest"
  data.pokemon.FIXMON_A.evolutions = {
    { method = "ITEM", item = "FIX_THUNDERSTONE", species = "FIXMON_B" } }
  data.items = data.items or {}
  data.items.FIX_THUNDERSTONE = { id = "FIX_THUNDERSTONE",
                                  name = "THUNDERSTONE" }

  local function fits(list, label)
    local worst, worstText = 0, ""
    for _, row in ipairs(list) do
      local used
      if row.cols then
        -- Columns are right-aligned, and where they start depends on how
        -- many there are -- the same table the renderer uses.
        local LAYOUT = { [1] = { 152 }, [2] = { 112, 152 },
                         [3] = { 88, 120, 152 } }
        local xs = LAYOUT[#row.cols] or LAYOUT[3]
        local first = row.cols[1]
        local text = type(first) == "number"
          and ("%d"):format(math.floor(first + 0.5)) or tostring(first or "")
        -- the label has to stop a character short of the first column
        if Font.width(row.text) + 8 > xs[1] - Font.width(text) - 8 then
          used = BUDGET + 1
        else
          used = 0
        end
      elseif row.note then
        used = Font.width(row.text) + Font.width(row.note) + 8
      else
        used = Font.width(row.text)
      end
      if used > worst then worst, worstText = used, tostring(row.text) end
    end
    T.check(worst <= BUDGET,
            label .. " fits without clipping (worst " .. worst .. "px on '"
            .. worstText .. "')")
  end

  fits(rows.locations(data, data.pokemon[A]), "a 15-letter map name")
  fits(rows.evolution(data, data.pokemon[A]), "a THUNDERSTONE evolution")
  fits(rows.catch(data, data.pokemon[A]), "the catch table")
  fits(rows.levelMoves(data, data.pokemon[A]), "level moves")
  fits(rows.machines(data, data.pokemon[A]), "the TM/HM list")
  fits(rows.types(data, data.pokemon[A]), "the type matchup buckets")
end

do
  -- MASTER BALL is out of the table and named once at the bottom instead
  local list = rows.catch(Data, Data.pokemon[A])
  for _, row in ipairs(list) do
    if row.cols and not row.head then
      T.check(not row.text:find("MASTER", 1, true),
              "no always-catch ball takes a table row")
    end
  end
  -- the short form is what buys the clearance
  local named = false
  for _, row in ipairs(list) do
    if row.cols and not row.head and row.text == "POKE" then named = true end
  end
  T.check(named, "ball names drop the redundant BALL")
end

-- ~~~ evolution picker

do
  -- The picker is what makes an Eevee page possible: one entry per related
  -- species, so a cursor can sit on one and a sprite can be drawn from it.
  local picks = run.loader.exports.dex_pages.picks
  T.check(type(picks) == "function", "exports the pick builder")

  local one = picks(Data, Data.pokemon[A])
  T.eq(#one, 1, "FIXMON_A has one relation")
  T.eq(one[1].dir, "INTO", "and it is an evolution target")
  T.eq(one[1].species, B, "naming the species a sprite can be loaded for")
  T.check(one[1].method ~= nil and one[1].method ~= "", "carries its method")

  -- the reverse relation is a pick too: it has a sprite worth showing
  local back = picks(Data, Data.pokemon[B])
  T.check(#back >= 1, "FIXMON_B knows what it came from")
  T.eq(back[1].dir, "FROM", "and that relation is labelled FROM")
end

do
  -- three targets is the Eevee case the cursor exists for
  local data = T.fixtures.fresh()
  data.pokemon[A].evolutions = {
    { method = "LEVEL", level = 16, species = B },
    { method = "LEVEL", level = 18, species = C },
  }
  local picks = run.loader.exports.dex_pages.picks(data, data.pokemon[A])
  T.eq(#picks, 2, "every target is its own pick")
  T.neq(picks[1].species, picks[2].species, "and they are distinct species")
end

-- ~~~ dex browsing

do
  -- UP/DOWN steps through the dex on a page with nothing to scroll.  The
  -- order is by dex number over *seen* species only: browsing into an unseen
  -- mon would show data the dex itself is still withholding.
  local Screen = run.loader.exports.dex_pages.screen
  local function browserFor(seen, at)
    local game = {
      data = Data,
      save = { pokedex = { seen = seen, owned = {} } },
      input = { wasPressed = function() return false end },
      stack = { pop = function() end },
    }
    return setmetatable({ game = game, def = Data.pokemon[at], owned = true,
                          index = 1, scroll = 0 }, Screen)
  end

  local all = { [A] = true, [B] = true, [C] = true }
  local s = browserFor(all, A)
  local order = s:seenOrder()
  T.eq(#order, 3, "all three seen species are in the order")
  T.check(order[1].dex <= order[2].dex, "sorted by dex number")

  -- only seen species count
  local partial = browserFor({ [A] = true, [C] = true }, A)
  T.eq(#partial:seenOrder(), 2, "an unseen species is left out of the order")

  -- a single seen species has nowhere to go
  local alone = browserFor({ [A] = true }, A)
  T.check(alone:browse(1) == false, "one seen species does not browse")

  -- a species the player has not seen is not a starting point either: that
  -- is battle_dex opening a first encounter, and stepping off it is a
  -- non-sequitur
  local unseen = browserFor({ [B] = true, [C] = true }, A)
  T.check(unseen:browse(1) == false, "browsing needs the current mon to be seen")
end

-- ~~~ charmap
--
-- The Game Boy charmap is not ASCII.  "%" and "<" and ">" have no glyph and
-- print as nothing at all, which is invisible to every other test here and
-- cost two rounds on hardware ("% PER THROW" rendered as " PER THROW").
-- Anything a page prints has to come from the set the font actually has.

do
  local SAFE = "^[A-Za-z0-9 ./,%-'%(%)!%?:]*$"
  local function safe(list, label)
    for _, row in ipairs(list) do
      local fields = { row.text }
      if row.note then fields[#fields + 1] = row.note end
      for _, col in ipairs(row.cols or {}) do
        if type(col) == "string" then fields[#fields + 1] = col end
      end
      for _, text in ipairs(fields) do
        T.check(text:match(SAFE) ~= nil,
                label .. " prints only glyphs the font has ('"
                .. tostring(text) .. "')")
      end
    end
  end
  safe(rows.catch(Data, Data.pokemon[A]), "catch odds")
  safe(rows.types(Data, Data.pokemon[A]), "type matchups")
  safe(rows.locations(Data, Data.pokemon[A]), "locations")
  safe(rows.levelMoves(Data, Data.pokemon[A]), "level moves")
  safe(rows.machines(Data, Data.pokemon[A]), "machines")
  safe(rows.evolution(Data, Data.pokemon[A]), "evolution")
end

do
  -- camelCase map labels weld shut when uppercased: VIRIDIANFOREST
  local data = T.fixtures.fresh()
  data.maps.FIX_ROUTE.label = "ViridianForest"
  local list = rows.locations(data, data.pokemon[A])
  T.check(list[1].text == "VIRIDIAN FOREST",
          "a camelCase label splits before uppercasing (got '"
          .. tostring(list[1].text) .. "')")
end

-- ~~~ drawing
--
-- The row builders are joins and are asserted above.  This block is about
-- the renderer: every page has to survive being drawn, because a nil index
-- in a draw path is invisible to a test that only inspects rows and is
-- extremely visible to a player.

do
  setOptions({})
  local Screens2 = require("src.ui.Screens")
  Screens2.invalidate()

  local game = newGame()
  local ok, screen = pcall(Screens2.get, game, "DexEntryMenu")
  if ok and screen and screen.new then
    local built, inst = pcall(screen.new, game, A)
    T.check(built, "the registered screen constructs (" ..
                   tostring(inst) .. ")")
    if built and inst then
      T.check(inst.vanilla ~= nil,
              "page 1 holds a real DexEntryMenu rather than a copy of it")
      T.check(inst.vanilla.def ~= nil, "and that instance resolved the species")

      -- draw every page, including the vanilla one
      local pages = inst:pages()
      for i = 1, #pages do
        inst.index = i
        inst.scroll = 0
        inst:build()
        local drew, err = pcall(inst.draw, inst)
        T.check(drew, "draws page " .. i .. " (" .. tostring(pages[i].title)
                      .. "): " .. tostring(err))
      end

      -- and a scrolled page, which uses a different row window
      inst.index = #pages
      inst:build()
      inst.scroll = 5
      T.check(pcall(inst.draw, inst), "draws a scrolled page")
    end
  else
    T.check(false, "Screens.get resolved the mod screen (" ..
                   tostring(screen) .. ")")
  end
end

-- ------- the ball table is merged, not chosen
--
-- data.balls is the mod REGISTRY, not extracted ROM data: it holds whatever
-- a mod overrode and nothing else.  Choosing it wholesale over the stock
-- table left the CATCH ODDS page drawing its column headers with not one
-- row underneath -- which is exactly what it did on the device, while the
-- fixture (which has no data.balls at all) fell back to stock and passed.
do
  local def = { id = "TESTMON", catchRate = 100,
                baseStats = { hp = 50, attack = 50, defense = 50,
                              speed = 50, special = 50 } }

  local function ballRows(data)
    return rows.catch(data, def)
  end

  -- an EMPTY registry -- the device case
  local function ballCount(out)
    local n = 0
    for _, r in ipairs(out or {}) do
      if r.cols and not r.head then n = n + 1 end
    end
    return n
  end

  T.check(ballCount(ballRows({ balls = {}, items = {} })) > 0,
    "an empty ball registry still lists the stock balls")

  -- a registry that overrides ONE ball keeps the other four
  T.check(ballCount(ballRows({ items = {},
      balls = { GREAT_BALL = { randMax = 180, hpFactor = 12 } } })) > 1,
    "overriding one ball does not hide the rest")
end

-- ------- a zoo placard shows the whole entry
--
-- The FUCHSIA signs open a dex entry deliberately, so hiding it behind
-- ownership defeats the exhibit.  A glimpse in battle is different and is
-- left alone -- only a script reaches this hook.
do
  local Runtime = require("src.mods.Runtime")
  local function through(name, args)
    return Runtime.call("script.command", function(_, _, a) return a end,
                        {}, name, args)
  end

  local args = { "DexEntryMenu", "CHANSEY" }
  through("push_screen", args)
  T.check(type(args[2]) == "table", "the bare species becomes an options table")
  T.eq(args[2].species, "CHANSEY", "naming the same species")
  T.eq(args[2].forceOwned, true, "and asking for the full entry")

  -- an options table already carrying a decision is left as it was
  local explicit = { "DexEntryMenu", { species = "MEW", forceOwned = false } }
  through("push_screen", explicit)
  T.eq(explicit[2].forceOwned, false, "an explicit choice is not overridden")

  -- nothing else is touched
  local other = { "SomeOtherScreen", "CHANSEY" }
  through("push_screen", other)
  T.eq(other[2], "CHANSEY", "another screen is left alone")
  local notPush = { "DexEntryMenu", "CHANSEY" }
  through("show_text", notPush)
  T.eq(notPush[2], "CHANSEY", "and so is another command")
end

-- ------- the entry page and the pages behind it are separate decisions
--
-- A glimpse in battle should read like the show: point the dex at the thing
-- and it tells you what it is.  It should not hand over the stats, the
-- catch odds and the whole movelist for something never caught.  A zoo
-- placard, which exists to show you the exhibit, still gets everything.
do
  setOptions({})
  local function ownedWith(realOwned, forceOwned, entryOnly)
    local self = setmetatable({ game = newGame(), def = { id = A },
                                index = 1, scroll = 0,
                                entryOnly = entryOnly or false,
                                vanilla = { forceOwned = forceOwned or false } },
                              Screen)
    local dex = { owned = realOwned and { [A] = true } or {} }
    return self:ownedFor(A, dex)
  end

  T.eq(ownedWith(false, true, false), true,
    "a placard forces the whole entry open")
  T.eq(ownedWith(false, true, true), false,
    "entryOnly opens the entry page without claiming the species is owned")
  T.eq(ownedWith(true, true, true), true,
    "a species you actually own is owned however it was opened")
  T.eq(ownedWith(false, false, false), false,
    "and nothing is invented for one you neither own nor forced")

  -- and that flows through to how many pages are offered
  local def = Data.pokemon[A]
  T.eq(#screenFor(def, false):pages(), 1,
    "not owned: the entry page alone")
  T.check(#screenFor(def, true):pages() > 1,
    "owned: the pages behind it as well")
end

-- ------- an entry opened AT a POKeMON stays on it
--
-- You asked about the one in front of you, or the one you picked in the
-- party menu.  Stepping from there into the rest of the dex is a
-- non-sequitur, and mid-battle it is worse than that.
do
  setOptions({})
  local function pinnedScreen(pinned)
    local g = newGame()
    g.save.pokedex = { seen = { [A] = true, [B] = true, [C] = true },
                       owned = { [A] = true } }
    return setmetatable({ game = g, def = { id = A }, index = 1, scroll = 0,
                          pinned = pinned, vanilla = { forceOwned = false } },
                        Screen)
  end
  T.eq(pinnedScreen(true):browse(1), false, "a pinned entry does not browse")
  T.eq(pinnedScreen(true):browse(-1), false, "in either direction")
  T.eq(pinnedScreen(false):browse(1), true,
    "one opened from the POKeDEX still browses as before")
end

-- ------- CATCH ODDS survives the ownership gate for a glimpse
--
-- Everything else behind the entry is reference you can look up once it is
-- yours.  The odds are what you need in the moment, deciding whether to
-- spend a ball on the thing in front of you.
do
  setOptions({})
  -- forceOwned is what battle_dex passes to open the entry page itself; the
  -- POKeDEX list passes nothing, so it has to be off for that case or the
  -- species counts as owned and nothing is gated at all
  local function pagesFor(entryOnly, owned)
    local g = newGame()
    g.save.pokedex = { seen = {}, owned = owned and { [A] = true } or {} }
    local self = setmetatable({ game = g, def = { id = A }, index = 1,
                                scroll = 0, entryOnly = entryOnly,
                                vanilla = { forceOwned = entryOnly } }, Screen)
    self.owned = self:ownedFor(A, g.save.pokedex)
    local keys = {}
    for _, p in ipairs(self:pages()) do keys[#keys + 1] = p.key or "vanilla" end
    return table.concat(keys, ",")
  end
  T.check(pagesFor(true, false):find("catch"),
    "unowned, opened at a POKeMON: the odds are there")
  T.check(not pagesFor(true, false):find("where"),
    "but not its locations, which can wait until you own it")
  T.check(not pagesFor(false, false):find("catch"),
    "browsing the dex unowned still shows nothing behind the entry")
  T.check(pagesFor(true, true):find("where"),
    "and once it is yours everything opens as before")

  -- turning the page off still turns it off
  setOptions({ show_catch = false })
  T.check(not pagesFor(true, false):find("catch"),
    "CATCH ODDS PAGE off means off, glimpse or not")
  setOptions({})
end

T.finish("dex_pages")
