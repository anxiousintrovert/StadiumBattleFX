-- Focused visual regression viewer for the three callback-heavy Gen 1 models.
-- Launch with:
--   love "C:\stadium animations\StadiumBattleFX\tools\hybrid_model_viewer"

local WORKSPACE = os.getenv("STADIUM_WORKSPACE") or [[C:/stadium animations]]
local SBFX = WORKSPACE .. "/StadiumBattleFX"
local APPDATA = assert(os.getenv("APPDATA"), "APPDATA is unavailable")
local S1_CACHE = APPDATA .. "/pokemon-love2d/stadium_battle_fx/models/v5"
local S1_PACK_ROOT = os.getenv("S1_PACK_ROOT")
-- The external SBFX cache builder writes the same relative Stadium 2 cache
-- tree used by the embedded importer. Point this at a temporary builder output
-- when validating a native-pose conversion; retain the old save root as a
-- convenience for existing appearance-only developer caches.
local S2_CACHE = os.getenv("S2_CACHE_ROOT") or (APPDATA .. "/pokemon-love2d")
local TRACE = os.getenv("S2_VIEWER_TRACE")
-- Forward declaration: the package searcher below closes over this namespace.
local namespace
local function trace(message)
  if not TRACE then return end
  local file=io.open(TRACE,"ab")
  if file then file:write(tostring(message),"\n"); file:close() end
end
trace("main")

-- Resolve the embedded Stadium 2 namespace directly to this checkout so the
-- viewer exercises the exact bridge shipped inside StadiumBattleFX.
table.insert(package.loaders or package.searchers, 1, function(name)
  local relative = name:match("^mods%.STADIUM_BATTLE_FX%.lib%.stadium2%.(.+)$")
  if not relative then return nil end
  local path = SBFX .. "/lib/stadium2/" .. relative:gsub("%.", "/") .. ".lua"
  local chunk, err = loadfile(path)
  -- Embedded Stadium 2 modules are factory chunks: their vararg is the SBFX
  -- namespace.  `require` invokes loaders without it, so adapt them here.
  if chunk then return function() return chunk(namespace) end end
  return "\n\t" .. tostring(err)
end)

-- Point the importer's cache reads at the real Gen1Recomp save directory.
local fsRead, fsInfo = love.filesystem.read, love.filesystem.getInfo
local function s2Path(path)
  if type(path) == "string" and path:match("^stadium2_gen1_model_pack/") then
    return S2_CACHE .. "/" .. path
  end
end
love.filesystem.read = function(path, ...)
  local disk = s2Path(path)
  if disk then
    local file = io.open(disk, "rb")
    if not file then return nil, "missing " .. disk end
    local bytes = file:read("*a")
    file:close()
    return bytes, #bytes
  end
  return fsRead(path, ...)
end
love.filesystem.getInfo = function(path, kind)
  local disk = s2Path(path)
  if disk then
    local file = io.open(disk, "rb")
    if not file then return nil end
    local size = file:seek("end")
    file:close()
    if kind and kind ~= "file" then return nil end
    return { type="file", size=size, modtime=0 }
  end
  return fsInfo(path, kind)
end

local modules = {}
namespace = {
  mod = {
    read = function(_, path)
      local cachePath = type(path) == "string" and path:match("^cache/(stadium2_gen1_model_pack/.+)$")
      if cachePath then
        local file = io.open(S2_CACHE .. "/" .. cachePath, "rb")
        if not file then return nil end
        local bytes = file:read("*a")
        file:close()
        return bytes
      end
      local species = path:match("(%d%d%d)%.dsm$")
      if not species then return nil end
      local file = io.open(S1_CACHE .. "/" .. species .. ".dsm", "rb")
      if not file then return nil end
      local bytes = file:read("*a")
      file:close()
      return bytes
    end,
  },
  log = {
    warn=function(_,fmt,...) print("WARN " .. tostring(fmt):format(...)) end,
    error=function(_,fmt,...) print("ERROR " .. tostring(fmt):format(...)) end,
  },
}
function namespace.require(name)
  if modules[name] ~= nil then return modules[name] end
  if name == "ModStorage" then
    modules[name]={
      bytes=function(key)
        if not S1_PACK_ROOT then return nil end
        local species=key:match("(%d+)$")
        local chunk=species and loadfile(S1_PACK_ROOT .. "/" .. ("%03d.lua"):format(species))
        local record=chunk and chunk()
        return record and record.bytes
      end,
      bundled=function(relative)
        return namespace.mod:read(relative)
      end,
    }
    return modules[name]
  end
  if name == "StadiumInstall" then
    modules[name]={ready=function() return S1_PACK_ROOT ~= nil end}
    return modules[name]
  end
  if name == "StadiumModelSources" then
    modules[name]={decorate=function(_,_,base) return base end,keep=function() end,invalidate=function() end}
    return modules[name]
  end
  local chunk = assert(loadfile(SBFX .. "/lib/" .. name .. ".lua"))
  modules[name] = chunk(namespace)
  return modules[name]
end

local Mat4 = namespace.require("Mat4")
trace("mat4-loaded")
local StadiumPack = namespace.require("StadiumPack")
trace("pack-loaded")
local StadiumRig = namespace.require("StadiumRig")
trace("rig-loaded")
local StadiumRender = namespace.require("StadiumRender")
trace("render-loaded")
local Hybrid = require("mods.STADIUM_BATTLE_FX.lib.stadium2.model_pack_api")
trace("modules-loaded")

-- Representative prior failures: callback flame, cannon attachment, and gas.
local targets = {
  { species=4, name="CHARMANDER" },
  { species=9, name="BLASTOISE" },
  { species=109, name="KOFFING" },
}
local requested=os.getenv("S2_VIEWER_SPECIES")
if requested then
  local custom={}
  for value in requested:gmatch("%d+") do
    local species=math.max(1,math.min(151,tonumber(value)))
    custom[#custom+1]={species=species,name=("SPECIES %03d"):format(species)}
    if #custom==3 then break end
  end
  if #custom==3 then targets=custom end
end
local app = { variant=os.getenv("S2_VIEWER_VARIANT")=="shiny" and "shiny" or "normal",
  paused=false, time=0, yaw=tonumber(os.getenv("S2_VIEWER_YAW")) or 0.22,
  entries={}, error=nil, draws=0, capturePending=false }

local function release()
  for _, entry in ipairs(app.entries) do
    if entry.rig then entry.rig:release() end
  end
  app.entries = {}
  StadiumPack.invalidate()
  Hybrid.invalidateHybrids()
end

local function loadModels()
  trace("load-models")
  release()
  app.error = nil
  for _, target in ipairs(targets) do
    trace("base-" .. target.species)
    local base, baseErr = StadiumPack.load(target.species, "normal")
    if not base then app.error = tostring(baseErr); return end
    local model, hybridErr
    if os.getenv("S2_VIEWER_FORCE_S1") == "1" then model=base
    else model,hybridErr=Hybrid.hybridModel(target.species,app.variant,base) end
    trace("hybrid-" .. target.species)
    if not model then app.error = tostring(hybridErr); return end
    local only=target.species==88 and tonumber(os.getenv("S2_VIEWER_GRIMER_PRIM"))
    if only then
      local selected=model.prims[only]
      model.prims=selected and {selected} or {}
      model.primCount=#model.prims
    end
    local onlySpecies=tonumber(os.getenv("S2_VIEWER_ONLY_SPECIES"))
    local onlyPrim=tonumber(os.getenv("S2_VIEWER_ONLY_PRIM"))
    local hideSpecies=tonumber(os.getenv("S2_VIEWER_HIDE_SPECIES"))
    local hidePrim=tonumber(os.getenv("S2_VIEWER_HIDE_PRIM"))
    if hideSpecies==target.species and hidePrim then
      table.remove(model.prims,hidePrim)
      model.primCount=#model.prims
    end
    if onlySpecies==target.species and onlyPrim then
      local selected=model.prims[onlyPrim]
      model.prims=selected and {selected} or {}
      model.primCount=#model.prims
    end
    local onlyBone=tonumber(os.getenv("S2_VIEWER_ONLY_BONE"))
    if onlySpecies==target.species and onlyBone and model.prims[1] then
      local source=model.prims[1]
      local filtered={}
      for at=1,#(source.index or {}),3 do
        local a,b,c=source.index[at],source.index[at+1],source.index[at+2]
        if a and b and c and (source.bone[a]==onlyBone
            or source.bone[b]==onlyBone or source.bone[c]==onlyBone) then
          filtered[#filtered+1],filtered[#filtered+2],filtered[#filtered+3]=a,b,c
        end
      end
      source.index=filtered
      source.indexCount=#filtered
    end
    local koffingBone=target.species==109 and tonumber(os.getenv("S2_VIEWER_KOFFING_BONE"))
    if koffingBone then
      local source=model.prims[5]
      if source then
        local filtered={}
        for at=1,#source.index,3 do
          local a,b,c=source.index[at],source.index[at+1],source.index[at+2]
          if a and b and c and (source.bone[a]==koffingBone
              or source.bone[b]==koffingBone or source.bone[c]==koffingBone) then
            filtered[#filtered+1],filtered[#filtered+2],filtered[#filtered+3]=a,b,c
          end
        end
        source.index=filtered;source.indexCount=#filtered
        model.prims={source};model.primCount=1
      end
    end
    local rig = StadiumRig.new(model)
    trace("rig-" .. target.species)
    if not rig then app.error = "Could not construct GPU rig for " .. target.name; return end
    -- A native-pose hybrid supplies its own action contexts. A failed pose
    -- decode leaves the Stadium 1 fallback model and its original contexts.
    local idle=(model.ctx and model.ctx[1] and model.ctx[1]~=StadiumPack.NONE)
      and (model.ctx[1]+1) or 1
    app.entries[#app.entries+1] = { target=target, model=model, rig=rig, anim=idle }
  end
end

local function cycleAnimation(delta)
  for _, entry in ipairs(app.entries) do
    local count=#(entry.model.anims or {})
    if count > 0 then
      entry.anim=((entry.anim-1+delta)%count)+1
    end
  end
  app.time=0
end

local function posedBounds(entry, bodyOnly)
  local minX,maxX,minY,maxY,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge,math.huge,-math.huge
  local count=0
  for _,part in ipairs(entry.rig.parts or {}) do
    local prim=part.prim or {}
    local effect=prim.additive or prim.gasEffect
      or (type(prim.fxFrames)=="table" and #prim.fxFrames>0)
    if not bodyOnly or not effect then
      for _,row in ipairs(part.rows or {}) do
        local x,y,z=row[1],row[2],row[3]
        if x and y and z then
          minX,maxX=math.min(minX,x),math.max(maxX,x)
          minY,maxY=math.min(minY,y),math.max(maxY,y)
          minZ,maxZ=math.min(minZ,z),math.max(maxZ,z)
          count=count+1
        end
      end
    end
  end
  if count==0 and bodyOnly then return posedBounds(entry,false) end
  if count==0 then return nil end
  return minX,maxX,minY,maxY,minZ,maxZ
end

local function modelMatrix(entry, x)
  local targetHeight = 2.25
  local model=entry.model
  local minX,maxX,minY,maxY,minZ,maxZ=posedBounds(entry,true)
  if minX then
    local height=math.max(.001,maxY-minY)
    local scale=targetHeight/height
    local centerX=(minX+maxX)*.5
    local centerZ=(minZ+maxZ)*.5
    return Mat4.mul(Mat4.translate(x,0,0),Mat4.mul(Mat4.rotateY(app.yaw),
      Mat4.mul(Mat4.scale(scale,scale,scale),
        Mat4.translate(-centerX,-minY,-centerZ))))
  end
  local root = tonumber(model.rootScale) or 1
  local height = math.max(0.001, tonumber(model.height) or 1)
  local scale = root * targetHeight / height
  local floorLift = -(tonumber(model.floor) or 0) * targetHeight / height
  return Mat4.mul(Mat4.translate(x, floorLift, 0),
    Mat4.mul(Mat4.rotateY(app.yaw), Mat4.scale(scale, scale, scale)))
end

function love.load()
  trace("love-load")
  love.graphics.setBackgroundColor(0.035,0.04,0.055,1)
  loadModels()
  trace("love-loaded")
end

function love.update(dt)
  if not app.paused then
    app.time = app.time + math.min(dt, 0.1)
    if not os.getenv("S2_VIEWER_YAW") then app.yaw = app.yaw + dt * 0.08 end
  end
  for _, entry in ipairs(app.entries) do
    local frames = entry.model.anims[entry.anim] and entry.model.anims[entry.anim].frames or 1
    local viewerFrame=tonumber(os.getenv("S2_VIEWER_FRAME"))
    local poseFrame=viewerFrame or (app.time * 30 % math.max(1,frames))
    entry.rig:pose(os.getenv("S2_VIEWER_BIND")=="1" and nil or entry.anim,
      poseFrame, true)
    entry.rig:skin(app.yaw)
    entry.rig:textures(entry.model.anims[entry.anim] and entry.model.anims[entry.anim].aux)
  end
end

function love.keypressed(key)
  if key == "space" then app.paused = not app.paused end
  if key == "r" then app.time=0; loadModels() end
  if key == "s" then app.variant=app.variant=="normal" and "shiny" or "normal"; loadModels() end
  if key == "left" then app.yaw=app.yaw-0.18 end
  if key == "right" then app.yaw=app.yaw+0.18 end
  if key == "q" then cycleAnimation(-1) end
  if key == "e" then cycleAnimation(1) end
  if key == "escape" then love.event.quit() end
  if key == "f12" then love.graphics.captureScreenshot("hybrid-model-viewer.png") end
end

function love.draw()
  if app.draws == 0 then trace("first-draw") end
  local g=love.graphics
  local w,h=g.getDimensions()
  g.setColor(0.08,0.09,0.12,1)
  g.rectangle("fill",0,h*0.72,w,h*0.28)
  g.setColor(0.16,0.17,0.21,1)
  for i=1,3 do g.ellipse("fill",w*(i*2-1)/6,h*0.69,w*0.12,h*0.035) end

  if not app.error then
    local projection=Mat4.perspective(math.rad(36),w/h,0.1,100)
    local view=Mat4.lookAt({0,2.0,8.3},{0,1.05,0},{0,1,0})
    if StadiumRender.begin(Mat4.mul(projection,view)) then
      for i,entry in ipairs(app.entries) do
        entry.rig:draw(modelMatrix(entry,(i-2)*2.75))
      end
      StadiumRender.finish()
    end
  end

  g.setColor(0.94,0.95,1,1)
  g.print("STADIUM 2 NATIVE POSES / SBFX RENDERER",24,20)
  g.setColor(0.7,0.74,0.84,1)
  g.print(("variant: %s   Q/E animation   S shiny/normal   SPACE pause   LEFT/RIGHT rotate   R reload   F12 screenshot"):format(app.variant),24,46)
  for i,target in ipairs(targets) do
    g.setColor(0.9,0.91,0.96,1)
    local entry=app.entries[i]
    local mode=entry and (entry.model.stadium2NativePose and "S2 NATIVE POSE" or "S1 FALLBACK") or "NOT LOADED"
    local animation=entry and entry.model.anims and entry.model.anims[entry.anim]
    local caption=target.name .. "\n" .. mode
      .. (animation and ("  " .. (animation.name or ("ANIM " .. entry.anim))) or "")
    g.printf(caption,w*(i-1)/3,h-68,w/3,"center")
  end
  if app.error then
    g.setColor(1,0.35,0.3,1)
    g.printf(app.error,80,h*0.42,w-160,"center")
  end
  app.draws=app.draws+1
  local capture=os.getenv("S2_VIEWER_CAPTURE")
  if capture and app.draws>=8 and not app.capturePending then
    app.capturePending=true
    love.graphics.captureScreenshot(function(data)
      trace("capture-callback")
      local encoded=data:encode("png")
      local file=assert(io.open(capture,"wb"))
      file:write(encoded:getString())
      file:close()
      love.event.quit()
    end)
  end
end
