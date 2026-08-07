-- Dex Pages: extra POKéDEX pages behind LEFT and RIGHT.
--
-- The vanilla entry page is not reimplemented here.  Page 1 is a real
-- DexEntryMenu instance whose :draw() we call, so the sprite, the kind,
-- the height/weight and -- the part that matters -- the ROM description
-- are whatever the engine draws today.  If the engine's page changes, this
-- page changes with it, and a player who never presses LEFT or RIGHT sees
-- the dex they have always seen.
--
-- Implemented as a registered replacement for the "DexEntryMenu" screen:
-- Screens.resolve prefers the screens registry over the builtin module and
-- a throwing factory degrades to the builtin (src/ui/Screens.lua), so the
-- worst case is the vanilla page rather than a dead end.
--
-- Every extra page is a join over data the engine already has, or a call
-- into the engine's own maths.  Nothing here reimplements a formula:
-- catch odds come from Catching.chance, matchups from TypeChart.

local Font = require("src.render.Font")
local Strings = require("src.core.Strings")
local DexEntryMenu = require("src.ui.DexEntryMenu")
local TypeChart = require("src.battle.TypeChart")
local Catching = require("src.battle.Catching")
local Stats = require("src.pokemon.Stats")

-- ---------------------------------------------------------------- layout

local W, H = 160, 144
local ROW_Y0, ROW_H = 22, 10
local ROWS = 11            -- 22..122, the footer clears at 132
local FOOTER_Y = 132

local function startFrame()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 0, 0, W, H)
  love.graphics.setColor(0, 0, 0, 1)
end

local function endFrame()
  love.graphics.setColor(1, 1, 1, 1)
end

local function right(text, x, y)
  Font.draw(text, x - Font.width(text), y)
end

-- Trim a string until it fits `budget` pixels.  Every two-field row measures
-- its right-hand field first and clips the left one to what is actually
-- left over, so a long name can lose its tail but can never draw over the
-- thing it is supposed to be labelling.
local function clip(text, budget)
  if budget <= 0 then return "" end
  if Font.width(text) <= budget then return text end
  local out = text
  while #out > 0 and Font.width(out) > budget do
    out = out:sub(1, #out - 1)
  end
  return out
end

-- ---------------------------------------------------------- shared lookups

-- Caches are keyed on the data table so a mod that patches encounters or
-- items between boots cannot serve a stale index (the same trap npc_bubbles
-- hit with its sandbox cache).
local cacheFor, cache = nil, {}

local function indexes(data)
  if cacheFor == data then return cache end
  cacheFor, cache = data, {}

  -- move id -> { kind = "TM"|"HM", number = n }
  local machines = {}
  for _, item in pairs(data.items or {}) do
    local m = item.machine
    if m and m.move and not machines[m.move] then
      machines[m.move] = { kind = m.kind, number = m.number }
    end
  end
  cache.machines = machines

  -- species id -> list of { where, method, lo, hi, rate }
  local places = {}
  local function add(species, where, method, level, rate)
    if not species then return end
    local list = places[species]
    if not list then list = {}; places[species] = list end
    for _, row in ipairs(list) do
      if row.where == where and row.method == method then
        row.lo = math.min(row.lo, level)
        row.hi = math.max(row.hi, level)
        return
      end
    end
    list[#list + 1] = { where = where, method = method,
                        lo = level, hi = level, rate = rate }
  end

  for mapId, enc in pairs(data.encounters or {}) do
    for _, pair in ipairs({ { enc.grass, "GRASS" }, { enc.water, "SURF" } }) do
      local tbl, method = pair[1], pair[2]
      for _, slot in ipairs(tbl and tbl.slots or {}) do
        add(slot.species, mapId, method, slot.level, tbl.rate)
      end
    end
  end

  local fishing = (data.field or {}).fishing or {}
  local always = fishing.OLD_ROD and fishing.OLD_ROD.always
  if always then add(always.species, nil, "OLD ROD", always.level) end
  for _, row in ipairs(fishing.GOOD_ROD and fishing.GOOD_ROD.pool or {}) do
    add(row.species, nil, "GOOD ROD", row.level)
  end
  local perMap = (data.field or {})[fishing.SUPER_ROD
    and fishing.SUPER_ROD.perMap or "superRod"] or {}
  for mapId, rows in pairs(perMap) do
    for _, row in ipairs(rows) do
      add(row.species, mapId, "SUPER ROD", row.level)
    end
  end
  cache.places = places

  -- species id -> list of { from = speciesId, evo }
  local preEvos = {}
  for id, def in pairs(data.pokemon or {}) do
    for _, evo in ipairs(def.evolutions or {}) do
      if evo.species then
        local list = preEvos[evo.species]
        if not list then list = {}; preEvos[evo.species] = list end
        list[#list + 1] = { from = id, evo = evo }
      end
    end
  end
  cache.preEvos = preEvos

  -- Attacking types in ROM order, for a stable matchup layout.  The merged
  -- registry is preferred, but a dataset can carry matchups without type
  -- records (the ROM-free fixture does), so fall back the same way
  -- TypeChart.displayName does rather than showing an empty page.
  local records = (data.type_chart or {}).types
  if not records or next(records) == nil then records = TypeChart.TYPES end
  local order = {}
  for id, record in pairs(records or {}) do
    order[#order + 1] = { id = id, index = record.index or 0 }
  end
  table.sort(order, function(a, b)
    if a.index ~= b.index then return a.index < b.index end
    return a.id < b.id
  end)
  cache.types = order

  return cache
end

-- Map constants read as SCREAMING_SNAKE; the label is what the town map
-- and the fly menu show, so prefer it and fall back to a prettied id.
local function placeName(data, mapId)
  if not mapId then return "ANY WATER" end
  local def = (data.maps or {})[mapId]
  local label = def and def.label
  if not label or label == "" then label = (mapId:gsub("_", " ")) end
  -- Map labels are camelCase ("ViridianForest"), and uppercasing alone
  -- welds them shut -- VIRIDIANFOREST.  Split on the case change first.
  label = label:gsub("(%l)(%u)", "%1 %2"):gsub("(%a)(%d)", "%1 %2")
  -- Place names are uppercase everywhere else in the game.  Lua's upper is
  -- byte-wise, so the é in POKéMON TOWER survives it, which is the casing
  -- the game's own font expects.
  return label:upper()
end

-- ------------------------------------------------------------ page: types

-- Gen 1 applies each matchup row separately, so the combined multiplier is
-- already what TypeChart.effectiveness returns (x10: 10 is neutral).
local function typeRows(data, def)
  -- effectiveness() asserts on an unbuilt index; load is idempotent and this
  -- runs once per page switch, not per frame
  pcall(TypeChart.load, data)
  local out = {}
  local buckets = { [40] = {}, [20] = {}, [5] = {}, [2] = {}, [0] = {} }
  local order = { 40, 20, 5, 2, 0 }
  local labels = { [40] = "TAKES 4x", [20] = "TAKES 2x", [5] = "TAKES 1/2x",
                   [2] = "TAKES 1/4x", [0] = "NO EFFECT" }
  for _, t in ipairs(indexes(data).types) do
    local mult = TypeChart.effectiveness(t.id, def.types or {})
    local bucket = buckets[mult]
    if bucket then bucket[#bucket + 1] = TypeChart.displayName(t.id) end
  end
  for _, mult in ipairs(order) do
    local names = buckets[mult]
    if #names > 0 then
      out[#out + 1] = { text = labels[mult], head = true }
      -- Two per row where they fit, one where they do not: ELECTRIC and
      -- FIGHTING together are 19 characters and the row holds 18, so a
      -- blind pairing would clip a type name in half.
      local i = 1
      while i <= #names do
        local line = "  " .. names[i]
        if names[i + 1]
          and Font.width(line .. " " .. names[i + 1]) <= W - 16 then
          line = line .. " " .. names[i + 1]
          i = i + 2
        else
          i = i + 1
        end
        out[#out + 1] = { text = line }
      end
    end
  end
  if #out == 0 then out[1] = { text = "Nothing special." } end
  return out
end

-- ------------------------------------------------------------ page: catch

-- The odds are per throw, at a reference level: the Gen 1 formula reads the
-- HP *fraction*, not the level, so the number barely moves between L5 and
-- L50 and quoting a level would imply a precision that is not there.
local REF_LEVEL = 25
local REF_DVS = { hp = 8, attack = 8, defense = 8, speed = 8, special = 8 }

-- "POKé BALL" -> "POKé".  The word BALL is the same on every row, so it is
-- 40px of screen saying nothing, and this table has none to spare.
local function shortBall(name)
  local trimmed = name:gsub("%s*BALLS?$", "")
  if trimmed ~= "" then return trimmed end
  return name
end

local function catchRows(data, def)
  local out = {}
  if (def.catchRate or 0) <= 0 then
    return { { text = "Cannot be caught." } }
  end
  local ok, stats = pcall(Stats.calc, def, REF_LEVEL, REF_DVS, nil)
  local maxHp = (ok and stats and stats.hp) or 50
  local balls = data.balls or Catching.BALLS or {}

  local function pct(ballId, record, hp, status)
    local mon = { hp = hp, status = status, stats = { hp = maxHp } }
    local got, value = pcall(Catching.chance, ballId, mon, def, nil,
                             { ballDef = record, statuses = data.statuses })
    if not got or type(value) ~= "number" then return nil end
    return value
  end

  -- Bag order, not internal order.  Sorting by randMax put SAFARI between
  -- GREAT and ULTRA, which is not how anyone thinks about balls.
  local BAG = { POKE_BALL = 1, GREAT_BALL = 2, ULTRA_BALL = 3, SAFARI_BALL = 4 }
  local ids = {}
  for id, record in pairs(balls) do
    -- A ball that always works has no odds worth tabulating
    if not (record and record.autoCatch) then ids[#ids + 1] = id end
  end
  table.sort(ids, function(a, b)
    local ra, rb = BAG[a] or 99, BAG[b] or 99
    if ra ~= rb then return ra < rb end
    return a < b
  end)

  -- One variable per axis.  The old layout had FULL / 1HP / SLP, where the
  -- third column silently changed *two* things at once -- it meant "1HP and
  -- asleep" -- so there was no way to read the cost of sleep on its own.
  -- Blocks are the status, columns are the HP.  Every cell is now defined by
  -- exactly the row block it is in and the column it is under.
  --
  -- No % anywhere: the Game Boy charmap has no % glyph -- checked against a
  -- real imported font table, not assumed -- so one prints as a blank.
  out[#out + 1] = { text = "CHANCE PER THROW", head = true }
  local STATES = { { label = "AWAKE", status = nil },
                   { label = "ASLEEP", status = "SLP" } }
  for _, state in ipairs(STATES) do
    -- A blank row above each block.  Eleven rows of numbers with nothing
    -- between them read as one slab; the page scrolls like the movelist
    -- does, so the two rows this costs are cheaper than the density.
    out[#out + 1] = { text = "" }
    out[#out + 1] = { text = state.label, head = true,
                      cols = { "FULL", "1HP" } }
    for _, id in ipairs(ids) do
      local record = balls[id]
      local name = (data.items and data.items[id] and data.items[id].name)
        or (id:gsub("_", " "))
      local full = pct(id, record, maxHp, state.status)
      local low = pct(id, record, 1, state.status)
      if full then
        out[#out + 1] = { text = shortBall(name), cols = { full, low } }
      end
    end
  end
  return out
end

-- -------------------------------------------------------- page: locations

local function locationRows(data, def)
  local places = indexes(data).places[def.id]
  if not places or #places == 0 then
    return { { text = "Not in the wild." } }
  end
  local sorted = {}
  for _, row in ipairs(places) do sorted[#sorted + 1] = row end
  table.sort(sorted, function(a, b)
    local na, nb = placeName(data, a.where), placeName(data, b.where)
    if na ~= nb then return na < nb end
    return a.method < b.method
  end)
  -- Two lines per place.  A map name and its method together run past the
  -- screen's 20 characters (VIRIDIAN FOREST alone is 15), and a name that
  -- collides with its own detail is worse than one that scrolls.
  local out = {}
  for _, row in ipairs(sorted) do
    local level = row.lo == row.hi and ("L%d"):format(row.lo)
      or ("L%d-%d"):format(row.lo, row.hi)
    out[#out + 1] = { text = placeName(data, row.where) }
    out[#out + 1] = { text = "  " .. row.method .. " " .. level, sub = true }
  end
  return out
end

-- ------------------------------------------------------------ page: moves

local function moveName(data, id)
  local def = (data.moves or {})[id]
  return (def and def.name) or (id and id:gsub("_", " ")) or "?"
end

local function levelMoveRows(data, def)
  local out = {}
  for _, id in ipairs(def.level1Moves or {}) do
    out[#out + 1] = { text = moveName(data, id), note = "START" }
  end
  for _, row in ipairs(def.learnset or {}) do
    out[#out + 1] = { text = moveName(data, row.move),
                      note = ("L%d"):format(row.level) }
  end
  if #out == 0 then out[1] = { text = "Learns nothing." } end
  return out
end

-- --------------------------------------------------------- page: machines

local function machineRows(data, def)
  local machines = indexes(data).machines
  local rows = {}
  for _, move in ipairs(def.tmhm or {}) do
    local m = machines[move]
    rows[#rows + 1] = {
      kind = m and m.kind or "TM",
      number = m and m.number or 0,
      text = moveName(data, move),
    }
  end
  if #rows == 0 then return { { text = "No TMs or HMs." } } end
  -- HMs after TMs, each by machine number, the order the bag shows them
  table.sort(rows, function(a, b)
    local ka = a.kind == "HM" and 1 or 0
    local kb = b.kind == "HM" and 1 or 0
    if ka ~= kb then return ka < kb end
    return a.number < b.number
  end)
  local out = {}
  for _, row in ipairs(rows) do
    out[#out + 1] = { text = row.text,
                      note = ("%s%02d"):format(row.kind, row.number) }
  end
  return out
end

-- -------------------------------------------------------- page: evolution

local function methodLabel(data, evo)
  local method = (data.evolution_methods or {})[evo.method]
  if method and method.describe then
    local ok, label = pcall(method.describe, evo, data)
    if ok and type(label) == "string" and label ~= "" then return label end
  end
  if evo.level then return ("L%d"):format(evo.level) end
  if evo.item then
    local item = (data.items or {})[evo.item]
    return (item and item.name) or (evo.item:gsub("_", " "))
  end
  return (tostring(evo.method):gsub("_", " "))
end

local function speciesName(data, id)
  local def = (data.pokemon or {})[id]
  return (def and def.name) or (id and id:gsub("_", " ")) or "?"
end

-- Two lines again: THUNDERSTONE is 12 characters on its own, and the
-- method is the half worth reading.
local function evolutionRows(data, def)
  local out = {}
  local function pair(text, method)
    out[#out + 1] = { text = text }
    out[#out + 1] = { text = "  " .. method, sub = true }
  end
  for _, row in ipairs(indexes(data).preEvos[def.id] or {}) do
    pair("FROM " .. speciesName(data, row.from), methodLabel(data, row.evo))
  end
  for _, evo in ipairs(def.evolutions or {}) do
    pair("INTO " .. speciesName(data, evo.species), methodLabel(data, evo))
  end
  if #out == 0 then out[1] = { text = "Does not evolve." } end
  return out
end

-- The same relations as evolutionRows, but flat: one entry per related
-- species, which is what a cursor can move over and what a sprite can be
-- drawn from.  Eevee has three targets, so a page that shows only one
-- picture has to let the player say which.
local function evolutionPicks(data, def)
  local out = {}
  for _, row in ipairs(indexes(data).preEvos[def.id] or {}) do
    out[#out + 1] = { species = row.from, name = speciesName(data, row.from),
                      method = methodLabel(data, row.evo), dir = "FROM" }
  end
  for _, evo in ipairs(def.evolutions or {}) do
    out[#out + 1] = { species = evo.species,
                      name = speciesName(data, evo.species),
                      method = methodLabel(data, evo), dir = "INTO" }
  end
  return out
end

-- ------------------------------------------------------------- page table

-- `option` is the toggle that hides the page; the vanilla page has none, so
-- it can never be switched off and the mod can never leave the player with
-- no dex at all.
local PAGES = {
  { key = "data", title = "DATA", vanilla = true },
  { key = "types", title = "TYPE MATCHUP", option = "show_types",
    build = typeRows },
  { key = "catch", title = "CATCH ODDS", option = "show_catch",
    build = catchRows },
  { key = "where", title = "LOCATIONS", option = "show_locations",
    build = locationRows },
  { key = "moves", title = "LEVEL MOVES", option = "show_moves",
    build = levelMoveRows },
  { key = "tmhm", title = "TM AND HM", option = "show_machines",
    build = machineRows },
  { key = "evo", title = "EVOLUTION", option = "show_evolution",
    build = evolutionRows, cursor = true, picks = evolutionPicks },
}

-- ------------------------------------------------------------------ setup

return function(mod)
  mod.options:define({
    -- A steps forward and wraps by default.  B already closes the entry, so
    -- leaving A as a second close button spent the more reachable of the two
    -- on a job that was already done.  LEFT/RIGHT keeps A closing for anyone
    -- who wants the vanilla feel.
    { key = "page_button", label = "DEX PAGE BUTTON", type = "choice",
      default = "cycle",
      choices = { { "A AND D-PAD", "cycle" }, { "D-PAD ONLY", "dpad" },
                  { "OFF", "off" } } },
    { key = "show_types", label = "TYPE MATCHUP PAGE", type = "toggle",
      default = true },
    { key = "show_catch", label = "CATCH ODDS PAGE", type = "toggle",
      default = true },
    { key = "show_locations", label = "LOCATIONS PAGE", type = "toggle",
      default = true },
    { key = "show_moves", label = "LEVEL MOVES PAGE", type = "toggle",
      default = true },
    { key = "show_machines", label = "TM/HM PAGE", type = "toggle",
      default = true },
    { key = "show_evolution", label = "EVOLUTION PAGE", type = "toggle",
      default = true },
    -- The vanilla page hides height, weight and the description until the
    -- species is owned.  On extends that gate to the new pages, so the dex
    -- cannot be used to scout a mon you have never met.
    { key = "owned_only", label = "OWNED DATA ONLY", type = "toggle",
      default = false },
  })

  local Screen = {}
  Screen.__index = Screen
  Screen.isOpaque = true

  function Screen:sgbPalettes(game)
    return self.vanilla and DexEntryMenu.sgbPalettes(self.vanilla, game) or nil
  end

  -- Which pages this species can actually show, vanilla always first.
  function Screen:pages()
    local out = { PAGES[1] }
    if mod.options:get("page_button") == "off" then return out end
    local locked = mod.options:get("owned_only") == true
      and not self.owned
    if locked then return out end
    for i = 2, #PAGES do
      local page = PAGES[i]
      if mod.options:get(page.option) ~= false then out[#out + 1] = page end
    end
    return out
  end

  function Screen.new(game, speciesOrOpts, onDone)
    local self = setmetatable({ game = game, onDone = onDone }, Screen)
    -- A real instance: it loads the sprite, plays the cry and owns the
    -- vanilla draw.  We never call its :update, so its A/B handling -- the
    -- part we are replacing -- never runs.
    self.vanilla = DexEntryMenu.new(game, speciesOrOpts, nil)
    self.def = self.vanilla.def
    self.index = 1
    self.scroll = 0
    self.rows = nil
    local dex = game.save and game.save.pokedex
    self.owned = self.vanilla.forceOwned
      or (dex and dex.owned and dex.owned[self.def and self.def.id]) or false
    return self
  end

  function Screen:page()
    local pages = self:pages()
    return pages[math.min(self.index, #pages)] or PAGES[1]
  end

  function Screen:build()
    local page = self:page()
    self.picks, self.pick = nil, 1
    if page.vanilla or not page.build then self.rows = nil; return end
    local ok, rows = pcall(page.build, self.game.data, self.def)
    -- A page that throws shows as empty rather than taking the dex down
    -- with it; the other pages and the vanilla page keep working.
    self.rows = (ok and type(rows) == "table") and rows
      or { { text = "No data." } }
    if page.picks then
      local got, picks = pcall(page.picks, self.game.data, self.def)
      if got and type(picks) == "table" and #picks > 0 then
        self.picks = picks
      end
    end
  end

  -- Front sprites, resolved the way the vanilla dex page resolves its own
  -- (src/ui/DexEntryMenu.lua): through Sprites.path, so a sprite-replacing
  -- mod is picked up here too.  Cached because draw runs every frame.
  local sprites = {}
  local function spriteFor(game, species)
    if sprites[species] ~= nil then return sprites[species] or nil end
    local ok, path = pcall(function()
      return (require("src.pokemon.Sprites").path(
        game.data, species, "front", { kind = "dex" }))
    end)
    local image = nil
    if ok and path then
      local built, img = pcall(love.graphics.newImage, path)
      image = built and img or nil
    end
    sprites[species] = image or false
    return image
  end

  function Screen:step(delta)
    local pages = self:pages()
    if #pages < 2 then return end
    self.index = ((self.index - 1 + delta) % #pages) + 1
    self.scroll = 0
    self:build()
  end

  function Screen:maxScroll()
    if not self.rows then return 0 end
    return math.max(0, #self.rows - ROWS)
  end

  function Screen:update(dt)
    local input = self.game.input
    local mode = mod.options:get("page_button")
    if input:wasPressed("b") then
      self.game.stack:pop()
      if self.onDone then self.onDone() end
      return
    end
    if input:wasPressed("a") then
      -- A steps forward and wraps; it never closes.  B closes, and B alone
      -- is enough, so spending A on "close" wasted the more useful button.
      if mode == "cycle" then
        self:step(1)
      else
        self.game.stack:pop()
        if self.onDone then self.onDone() end
      end
      return
    end
    if mode ~= "off" then
      if input:wasPressed("right") then self:step(1); return end
      if input:wasPressed("left") then self:step(-1); return end
      -- On a page with a cursor, UP/DOWN moves the cursor instead of
      -- scrolling.  Those pages are short by nature -- a species has a
      -- handful of evolutions, never a screenful -- so there is nothing to
      -- scroll and the keys are free.
      local page = self:page()
      if page.cursor and self.picks and #self.picks > 1 then
        if input:wasPressed("down") then
          self.pick = (self.pick % #self.picks) + 1
        elseif input:wasPressed("up") then
          self.pick = ((self.pick - 2) % #self.picks) + 1
        end
        return
      end
      if self.rows then
        if input:wasPressed("down") then
          self.scroll = math.min(self:maxScroll(), self.scroll + ROWS)
        elseif input:wasPressed("up") then
          self.scroll = math.max(0, self.scroll - ROWS)
        end
      end
    end
  end

  -- The bottom line is nothing but scroll state.  The page's own name used
  -- to be repeated down here as well as at the top, which said the same
  -- thing twice and left no room for anything that was not already known.
  --
  -- The charmap has no < or >, which is why 1.2.0 had no arrows at all --
  -- but it does have the triangles the game's own menus use, so a reader
  -- can be told there is more below without being told in words.
  local ARROW_DOWN, ARROW_UP, CURSOR = "▼", "▲", "▶"

  function Screen:drawScrollHints()
    if self:maxScroll() <= 0 then return end
    if self.scroll > 0 then Font.draw(ARROW_UP, 8, FOOTER_Y) end
    if self.scroll < self:maxScroll() then
      right(ARROW_DOWN, W - 8, FOOTER_Y)
    end
  end

  -- A list you move a cursor down, with the picture of whichever entry the
  -- cursor is on.  The list is one line per relation rather than the two the
  -- other pages use, because here the cursor has to land on something.
  function Screen:drawPicker(pages, page)
    startFrame()
    Font.draw(clip(("%d/%d %s"):format(self.index, #pages, page.title),
                   W - 16), 8, 4)
    love.graphics.rectangle("fill", 0, 18, W, 1)

    local picks = self.picks
    local sel = picks[math.min(self.pick or 1, #picks)]
    local y = ROW_Y0
    for i, entry in ipairs(picks) do
      if entry == sel and #picks > 1 then Font.draw(CURSOR, 6, y) end
      Font.draw(clip(entry.dir .. " " .. entry.name, W - 24), 16, y)
      y = y + ROW_H
    end

    -- The method belongs to the highlighted entry, so it moves with the
    -- cursor instead of being listed once per row and read twice.
    y = y + 4
    if sel then Font.draw(clip(sel.method, W - 16), 8, y) end

    -- The picture goes under the list, not beside it: INTO plus a ten-letter
    -- species name already reaches x=104, which would leave a 56px sprite
    -- nowhere to stand.
    local image = sel and spriteFor(self.game, sel.species) or nil
    if image then
      local w, h = image:getDimensions()
      local top = y + 14
      if top + h <= FOOTER_Y then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image, math.floor((W - w) / 2), top)
        love.graphics.setColor(0, 0, 0, 1)
      end
    end
    endFrame()
  end

  function Screen:draw()
    local pages = self:pages()
    local page = pages[math.min(self.index, #pages)] or PAGES[1]
    if page.vanilla then
      -- The vanilla page keeps every one of its own pixels.  The one
      -- addition sits in the bottom-right corner, which is provably free:
      -- every one of the 151 descriptions is exactly six lines, so the last
      -- one the engine draws ends at y=130 and nothing ever reaches this
      -- row.  Without it nothing tells a player the other pages exist.
      self.vanilla:draw()
      if #pages > 1 then
        love.graphics.setColor(0, 0, 0, 1)
        right(("%d/%d "):format(self.index, #pages) .. CURSOR, W - 8, 134)
      end
      endFrame()
      return
    end
    if not self.rows then self:build() end

    if page.cursor and self.picks then
      self:drawPicker(pages, page)
      return
    end

    startFrame()
    -- One title, at the top, and no species name: you got here from that
    -- species' own page, so naming it again spends five characters saying
    -- what the player already knows -- and PIKACHU + TYPE MATCHUP did not
    -- fit on one row anyway.
    Font.draw(clip(("%d/%d %s"):format(self.index, #pages, page.title),
                   W - 16), 8, 4)
    love.graphics.rectangle("fill", 0, 18, W, 1)

    local y = ROW_Y0
    for i = self.scroll + 1, math.min(#self.rows, self.scroll + ROWS) do
      local row = self.rows[i]
      if row.cols then
        -- Right-aligned columns, then whatever room is left goes to the
        -- label.  Fewer columns means wider gaps, which is the whole reason
        -- the catch table went from three columns to two blocks of two.
        local LAYOUT = { [1] = { 152 }, [2] = { 112, 152 },
                         [3] = { 88, 120, 152 } }
        local xs = LAYOUT[#row.cols] or LAYOUT[3]
        local leftmost = xs[1]
        for c = 1, #xs do
          local value = row.cols[c]
          local text = nil
          if type(value) == "number" then
            text = ("%d"):format(math.floor(value + 0.5))
          elseif type(value) == "string" then
            text = value
          end
          if text then
            right(text, xs[c], y)
            if c == 1 then leftmost = xs[1] - Font.width(text) end
          end
        end
        Font.draw(clip(row.text, leftmost - 8 - 8), 8, y)
      elseif row.note then
        right(row.note, W - 8, y)
        Font.draw(clip(row.text, W - 8 - Font.width(row.note) - 8 - 8), 8, y)
      else
        Font.draw(clip(row.text, W - 16), 8, y)
      end
      y = y + ROW_H
    end

    self:drawScrollHints()
    endFrame()
  end

  mod.content.screens:register("DexEntryMenu", { new = Screen.new })

  -- The joins are the reusable part: another mod wanting "where does this
  -- live" should not have to invert the encounter table a second time.
  mod.exports.screen = Screen
  mod.exports.rows = {
    types = typeRows, catch = catchRows, locations = locationRows,
    levelMoves = levelMoveRows, machines = machineRows,
    evolution = evolutionRows,
  }
  mod.exports.picks = evolutionPicks
end
