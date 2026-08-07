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
  local list = rows.catch(Data, Data.pokemon[A])
  local header = list[1]
  T.check(header and header.head, "leads with a column header")

  local ball = nil
  for _, row in ipairs(list) do
    if row.cols and not row.head then ball = row; break end
  end
  T.check(ball ~= nil, "produces at least one ball row")

  local full, low, slp = ball.cols[1], ball.cols[2], ball.cols[3]
  T.check(type(full) == "number", "full-HP odds are a number")
  T.check(full >= 0 and full <= 100, "odds are a percentage, not a fraction")
  -- the whole point of the page: these three must move in the right order
  T.check(low > full, "a hurt mon is easier to catch than a healthy one")
  T.check(slp > low, "sleep beats no status at the same HP")
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

  setOptions({})
  local off = screenFor(Data.pokemon[A], false)
  T.check(#off:pages() > 1, "off by default, so unowned mons keep the pages")
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
        -- name, then the three columns right-aligned at 88/120/152
        -- cells are bare numbers; the % lives in the heading
        local first = row.cols[1]
        local text = type(first) == "number"
          and ("%d"):format(math.floor(first + 0.5)) or tostring(first or "")
        used = Font.width(row.text) + Font.width(text) + 8
        -- the first column's left edge is 88 - its own width
        if Font.width(row.text) + 8 > 88 - Font.width(text) - 8 then
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
  T.check(find(list, "always") ~= nil, "and it is named in a footer line")
  -- the short form is what buys the clearance
  local named = false
  for _, row in ipairs(list) do
    if row.cols and not row.head and row.text == "POKE" then named = true end
  end
  T.check(named, "ball names drop the redundant BALL")
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

T.finish("dex_pages")
