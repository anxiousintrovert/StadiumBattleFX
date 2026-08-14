local Rom = require("mods.STADIUM_BATTLE_FX.lib.stadium2.rom")
local Extract = require("mods.STADIUM_BATTLE_FX.lib.stadium2.extract")
local Cache = require("mods.STADIUM_BATTLE_FX.lib.stadium2.cache")
local Palette = require("mods.STADIUM_BATTLE_FX.lib.stadium2.palette")
local Handlers = require("mods.STADIUM_BATTLE_FX.lib.stadium2.model_handlers")
local Pack = require("mods.STADIUM_BATTLE_FX.lib.stadium2.pack")
local Renderer = require("mods.STADIUM_BATTLE_FX.lib.stadium2.renderer")

local Importer = {}

local modRef
local job
local romMeta
local modelCache = {}
local modelOrder = {}
local MODEL_KEEP = 4
local configuredCount = 151
local NATIVE_PICKED = "picked_rom.gb"
local nativePickPending = false
local nativePickBefore = nil
local nativePickLostFocus = false
local nativePickPrevious = nil
local status = {
  state = "idle",
  done = 0,
  total = configuredCount,
  phase = nil,
  error = nil,
  rom = nil,
}

local function platformName()
  return nil
end

local function nativePickerAvailable()
  return false
end

local function pickedFingerprint(path)
  return nil
end

local function clearNativePicker(restore)
  nativePickPending = false
  nativePickBefore = nil
  nativePickLostFocus = false
  if restore and nativePickPrevious then
    status.state = nativePickPrevious.state
    status.phase = nativePickPrevious.phase
    status.error = nativePickPrevious.error
    status.rom = nativePickPrevious.rom
  end
  nativePickPrevious = nil
end

local function openNativePicker()
  return false, "Use the external personalized-pack builder to add Stadium 2 models"
end

local function removePickedFile()
  return false
end

local function fail(stage, reason)
  status.state = "failed"
  status.phase = stage
  status.error = tostring(reason or "unknown error")
  Cache.writeError(("Stage: %s\nReason: %s"):format(stage, status.error))
  if modRef and modRef.log then
    pcall(function() modRef.log:error("stadium2 importer: %s: %s", stage, status.error) end)
  end
  job = nil
  return false, status.error
end

local function setReady()
  status.state = "ready"
  status.done = configuredCount
  status.total = configuredCount
  status.progress = 1
  status.phase = nil
  status.species = nil
  status.error = nil
end

function Importer.bind(mod)
  modRef = mod
  return Importer
end

function Importer.configure(options)
  options = type(options) == "table" and options or {}
  configuredCount = 151
  status.total = configuredCount
  Extract.configure({
    count = configuredCount,
    cache = options.cache,
    shinyPalettes = options.shinyPalettes,
    palettePairs = options.palettePairs,
    meshOnly = true,
    includeUnownForms = false,
  })
  if Cache.available(configuredCount) and status.state ~= "building"
      and status.state ~= "picking" then setReady() end
  return Importer
end

function Importer.status()
  return status
end

function Importer.available(count)
  return Cache.available(count or configuredCount)
end

function Importer.modelsEnabled()
  if modRef and modRef.options and modRef.options.get then
    local ok, value = pcall(modRef.options.get, modRef.options, "stadium2_models")
    if ok and value == false then return false end
  end
  return true
end

function Importer.battleEnabled()
  if modRef and modRef.options and modRef.options.get then
    local ok, value = pcall(modRef.options.get, modRef.options, "stadium2_battle")
    if ok and value == false then return false end
  end
  return true
end

function Importer.shaderStyle()
  if modRef and modRef.options and modRef.options.get then
    local ok, value = pcall(modRef.options.get, modRef.options, "stadium2_shader")
    if ok and value == "cel" then return "cel" end
  end
  return "stadium"
end

local function rendererOptions(options)
  local out = {}
  for key, value in pairs(type(options) == "table" and options or {}) do
    out[key] = value
  end
  if out.shaderStyle == nil then out.shaderStyle = Importer.shaderStyle() end
  -- Existing battle actors observe an option change immediately; this does
  -- not rebuild packs, meshes, shaders, or the active battle scene.
  if out.shaderStyleProvider == nil then out.shaderStyleProvider = Importer.shaderStyle end
  return out
end

function Importer.modelPath(species, variant)
  species = tonumber(species)
  if not species or species < 1 or species > configuredCount then return nil end
  return Cache.path(species, variant)
end

function Importer.readPack(species, variant)
  return Cache.read(species, variant)
end

local function modelKey(species, variant)
  return tostring(variant == "shiny" and "shiny" or "normal") .. ":" .. tostring(species)
end

local function touchModel(key)
  for i = #modelOrder, 1, -1 do
    if modelOrder[i] == key then table.remove(modelOrder, i) end
  end
  modelOrder[#modelOrder + 1] = key
  while #modelOrder > MODEL_KEEP do
    local drop = table.remove(modelOrder, 1)
    local model = modelCache[drop]
    modelCache[drop] = nil
    if model then Pack.release(model) end
  end
end

function Importer.loadModel(species, variant)
  species = math.floor(tonumber(species) or 0)
  if species < 1 or species > configuredCount then return nil, "species out of range" end
  variant = variant == "shiny" and "shiny" or "normal"
  local key = modelKey(species, variant)
  local hit = modelCache[key]
  if hit then
    touchModel(key)
    return hit
  end
  local bytes = Cache.read(species, variant)
  if not bytes then return nil, "model pack unavailable" end
  local model, err = Pack.parse(bytes)
  if not model then return nil, err end
  model.variant = variant
  modelCache[key] = model
  touchModel(key)
  return model
end

function Importer.newRenderer(species, variant, options)
  if not Importer.modelsEnabled() then return nil, "Stadium 2 models disabled" end
  local model, err = Importer.loadModel(species, variant)
  if not model then return nil, err end
  return Renderer.new(model, rendererOptions(options))
end

function Importer.loadSpecial(name)
  local key="special:"..tostring(name)
  local hit=modelCache[key]
  if hit then touchModel(key);return hit end
  local bytes=Cache.readSpecial(name)
  if not bytes then return nil,"special battle pack unavailable" end
  local model,err=Pack.parse(bytes)
  if not model then return nil,err end
  model.variant="normal"
  modelCache[key]=model
  touchModel(key)
  return model
end

function Importer.newSpecialRenderer(name,options)
  local model,err=Importer.loadSpecial(name)
  if not model then return nil,err end
  return Renderer.new(model,rendererOptions(options))
end

function Importer.releaseModels()
  for _, model in pairs(modelCache) do Pack.release(model) end
  modelCache, modelOrder = {}, {}
end

function Importer.parsePack(bytes)
  return Pack.parse(bytes)
end

function Importer.readHandlers(species, variant)
  local bytes = Importer.readPack(species, variant)
  if not bytes then return nil end
  return Handlers.readExtension(bytes)
end

function Importer.handlerInfo(address)
  return Handlers.info(address)
end

function Importer.evaluateHandler(record, phase, runtime)
  return Handlers.evaluate(record, phase, runtime)
end

function Importer.runHandlers(records, phase, runtime, state)
  return Handlers.run(records, phase, runtime, state)
end

function Importer.runModelHandlers(species, variant, phase, runtime, state)
  local extension = Importer.readHandlers(species, variant)
  if not extension then return nil, nil end
  return Handlers.runExtension(extension, phase, runtime, state)
end

function Importer.resolveHandlerPointer(extension, pointer, length)
  return Handlers.resolvePointer(extension, pointer, length)
end

function Importer.beginFrom(bytes, label)
  if job then return false, "Stadium 2 import is already running" end
  if nativePickPending then clearNativePicker(false) end
  local normalized, metaOrErr = Rom.validate(bytes)
  if not normalized then return fail("validating ROM", metaOrErr) end
  Importer.releaseModels()
  local ok, clearErr = Cache.clear(configuredCount)
  if not ok then return fail("preparing cache", clearErr) end
  romMeta = metaOrErr
  status.state = "building"
  status.done = 0
  status.total = configuredCount
  status.progress = 0
  status.phase = "scan"
  status.error = nil
  status.rom = label or "Pokemon Stadium 2 (US)"
  job = Extract.newJob(normalized,
    function(species, normalBytes, shinyBytes)
      return Cache.writePair(species, normalBytes, shinyBytes)
    end,
    function(name,bytes) return Cache.writeSpecial(name,bytes) end)
  job.label = status.rom
  job.md5 = romMeta.md5
  return true
end

local function beginCandidate(candidate, options)
  return false, "Use the external personalized-pack builder to add Stadium 2 models"
end

function Importer.beginPath(path)
  return false, "Use the external personalized-pack builder to add Stadium 2 models"
end

local function pollNativePicker()
  if not nativePickPending then return false end
  local current = pickedFingerprint(NATIVE_PICKED)
  if current and current ~= nativePickBefore then
    clearNativePicker(false)
    local started = beginCandidate({ kind = "love", path = NATIVE_PICKED }, {
      removeAfter = true, label = "Android file picker",
    })
    return started and true or false
  end
  local window = love and love.window
  if window and type(window.hasFocus) == "function" then
    local ok, focused = pcall(window.hasFocus)
    if ok then
      if focused == false then
        nativePickLostFocus = true
      elseif focused == true and nativePickLostFocus then
        clearNativePicker(true)
      end
    end
  end
  return false
end

function Importer.autoImport()
  if Importer.available() then
    setReady()
    return true
  end
  return false, "Use the external personalized-pack builder to add Stadium 2 models"
end

function Importer.request()
  return false, "Use the external personalized-pack builder to add Stadium 2 models"
end

function Importer.step()
  if not job then pollNativePicker() end
  if not job then return false end
  local active = job
  local ok, more = pcall(active.step, active)
  if not ok then return fail("extracting ROM", more) end
  status.done = active.done or 0
  status.total = active.total or configuredCount
  status.progress = active.progress and active:progress()
    or (status.total > 0 and status.done / status.total or 0)
  status.phase = active.buildStage or active.phase
  status.species = active.species
  status.modelSpecies = active.modelSpecies or 0
  status.animatedSpecies = active.animatedSpecies or 0
  status.animationClips = active.animationClips or 0
  if active.error then return fail("building packs", active.error) end
  if more == false then
    if not active.success then return fail("building packs", active.error or "incomplete Stadium 2 import") end
    local finished, markerErr = Cache.finish(romMeta, configuredCount)
    if not finished then return fail("writing completion marker", markerErr) end
    job = nil
    setReady()
    if modRef and modRef.log then
      pcall(function()
        modRef.log:info("stadium2 model pack: built %d/%d Gen 1 species plus Substitute; Stadium 2 animations excluded",
          active.builtCount or 0,configuredCount)
      end)
    end
    return false
  end
  return true
end

function Importer.row()
  return {
    id = "STADIUM2_IMPORTER:rom",
    stadium2Importer = true,
    label = "STADIUM 2 ROM",
    value = function()
      if status.state == "building" then
        return ("%d/%d"):format(status.done or 0, status.total or configuredCount)
      end
      if status.state == "picking" then return "PICKING" end
      if Importer.available() then return "READY" end
      if status.state == "failed" then return "FAILED" end
      return "IMPORT"
    end,
    -- This row opens a screen/activity; it is an action, not a value that
    -- should cycle on Left/Right. Both Gen 1 and Gen 2 option menus give
    -- action rows an explicit `activate` callback on A.
    activate = function()
      if status.state == "building" or status.state == "picking" then return true end
      Importer.request()
      return true
    end,
  }
end

function Importer.appendRow(rows)
  if type(rows) ~= "table" then return rows end
  for _, row in ipairs(rows) do
    if type(row) == "table" and row.stadium2Importer then return rows end
  end
  rows[#rows + 1] = Importer.row()
  return rows
end

Importer.US_MD5 = Rom.US_MD5
Importer.FORMAT = Cache.FORMAT
Importer.NATIVE_PICKED = NATIVE_PICKED
Importer.nativePickerAvailable = nativePickerAvailable
Importer.COUNT = function() return configuredCount end
Importer.shinyPalettesFromTransformSource = Palette.fromTransformSource
Importer.cache = Cache
Importer.rom = Rom
Importer.extract = Extract
Importer.pack = Pack
Importer.renderer = Renderer

return Importer
