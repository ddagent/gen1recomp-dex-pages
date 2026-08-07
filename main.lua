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

  local ids = {}
  for id in pairs(balls) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b)
    local ra, rb = balls[a], balls[b]
    local ma = ra and ra.autoCatch and -1 or (ra and ra.randMax or 255)
    local mb = rb and rb.autoCatch and -1 or (rb and rb.randMax or 255)
    if ma ~= mb then return ma > mb end
    return a < b
  end)

  -- Two reasons this says CHANCE rather than carrying a % in each cell:
  -- columns are 32px apart and "100%" is exactly 32px, so per-cell signs
  -- make 95 and 100 touch -- and the Game Boy charmap has no % glyph at
  -- all, so one printed as a blank space on hardware.
  out[#out + 1] = { text = "CHANCE PER THROW", head = true }
  -- The header's own left cell stays empty: a label there would sit under
  -- the FULL column, which is the collision this layout exists to avoid.
  out[#out + 1] = { text = "", head = true, cols = { "FULL", "1HP", "SLP" } }
  local always = {}
  for _, id in ipairs(ids) do
    local record = balls[id]
    local name = (data.items and data.items[id] and data.items[id].name)
      or (id:gsub("_", " "))
    -- A ball that always works has nothing to compare, and its 100% is the
    -- widest cell on the page; it earns its keep as one line at the bottom.
    if record and record.autoCatch then
      always[#always + 1] = name
    else
      local full = pct(id, record, maxHp, nil)
      local low = pct(id, record, 1, nil)
      local slp = pct(id, record, 1, "SLP")
      if full then
        out[#out + 1] = { text = shortBall(name), cols = { full, low, slp } }
      end
    end
  end
  out[#out + 1] = { text = "" }
  for _, name in ipairs(always) do
    out[#out + 1] = { text = name .. " always" }
    out[#out + 1] = { text = "works." }
  end
  out[#out + 1] = { text = "SLP/FRZ help most" }
  out[#out + 1] = { text = "at low HP." }
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
    build = evolutionRows },
}

-- ------------------------------------------------------------------ setup

return function(mod)
  mod.options:define({
    -- LEFT/RIGHT is the default because it is purely additive: A and B still
    -- close the page exactly as they always have, so nobody's muscle memory
    -- breaks and the vanilla dex is reachable with the vanilla inputs.
    { key = "page_button", label = "DEX PAGE BUTTON", type = "choice",
      default = "dpad",
      choices = { { "LEFT/RIGHT", "dpad" }, { "A CYCLES", "cycle" },
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
    if page.vanilla or not page.build then self.rows = nil; return end
    local ok, rows = pcall(page.build, self.game.data, self.def)
    -- A page that throws shows as empty rather than taking the dex down
    -- with it; the other pages and the vanilla page keep working.
    self.rows = (ok and type(rows) == "table") and rows
      or { { text = "No data." } }
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
      if mode == "cycle" then
        local pages = self:pages()
        -- A wraps forward and closes off the last page, so it can never
        -- trap the player on a page with no way out
        if self.index >= #pages then
          self.game.stack:pop()
          if self.onDone then self.onDone() end
        else
          self:step(1)
        end
      else
        self.game.stack:pop()
        if self.onDone then self.onDone() end
      end
      return
    end
    if mode ~= "off" then
      if input:wasPressed("right") then self:step(1); return end
      if input:wasPressed("left") then self:step(-1); return end
      if self.rows then
        if input:wasPressed("down") then
          self.scroll = math.min(self:maxScroll(), self.scroll + ROWS)
        elseif input:wasPressed("up") then
          self.scroll = math.max(0, self.scroll - ROWS)
        end
      end
    end
  end

  -- No < > arrows: the Game Boy charmap has no glyph for either, so they
  -- printed as nothing at all.  "2/7" already says where you are.
  function Screen:drawFooter(pages)
    if #pages < 2 then return end
    local budget = W - 16
    local last = math.floor(self:maxScroll() / ROWS) + 1
    -- A one-screen page has no scroll to report, and "1/1" beside the
    -- title reads as part of the title
    if last > 1 then
      local counter = ("%d/%d"):format(math.floor(self.scroll / ROWS) + 1, last)
      right(counter, W - 8, FOOTER_Y)
      budget = budget - Font.width(counter) - 8
    end
    local label = ("%d/%d %s"):format(self.index, #pages, self:page().title)
    Font.draw(clip(label, budget), 8, FOOTER_Y)
  end

  function Screen:draw()
    local pages = self:pages()
    local page = pages[math.min(self.index, #pages)] or PAGES[1]
    if page.vanilla then
      -- Nothing is drawn over the vanilla page.  A footer here sits right
      -- under the last line of the description -- close enough to read as
      -- the description being cut off -- and the engine draws entry text as
      -- far down as y=132, which is where the footer would be.
      self.vanilla:draw()
      endFrame()
      return
    end
    if not self.rows then self:build() end

    startFrame()
    -- Title first, then the species name gets whatever is left: PIKACHU and
    -- TYPE MATCHUP are 19 characters together and the row holds 18.
    local title = page.title
    right(title, W - 8, 4)
    Font.draw(clip(self.def and self.def.name or "?",
                   W - 16 - Font.width(title) - 8), 8, 4)
    love.graphics.rectangle("fill", 0, 18, W, 1)

    local y = ROW_Y0
    for i = self.scroll + 1, math.min(#self.rows, self.scroll + ROWS) do
      local row = self.rows[i]
      if row.cols then
        -- The catch table: three right-aligned columns, then whatever room
        -- is left goes to the ball's name.
        local xs = { 88, 120, 152 }
        local leftmost = xs[1]
        for c = 1, 3 do
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

    self:drawFooter(pages)
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
end
