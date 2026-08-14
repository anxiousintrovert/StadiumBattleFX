-- Versioned, read-only consumer surface for the Gen-1 Stadium 2 model pack.
-- StadiumBattleFX's model provider will depend on this table rather than on
-- the pack's private extractor, cache or renderer modules.
local Importer = require("mods.STADIUM_BATTLE_FX.lib.stadium2.importer")
local Build = require("mods.STADIUM_BATTLE_FX.lib.stadium2.build")
local Sampler = require("mods.STADIUM_BATTLE_FX.lib.stadium2.sampler")

local Api = { version=1, speciesCount=151 }
local hybridCache = {}

local function validSpecies(value)
  local species = math.floor(tonumber(value) or 0)
  if species < 1 or species > Api.speciesCount then return nil end
  return species
end

function Api.variantForMon(mon)
  if not mon then return "normal" end
  if mon.shiny == true then return "shiny" end
  local ok, Stats = pcall(require, "src.pokemon.Stats")
  local shiny = ok and Stats and type(Stats.isShiny) == "function"
    and Stats.isShiny(mon.dvs)
  return shiny and "shiny" or "normal"
end

function Api.modelKey(species, monOrVariant)
  species = validSpecies(species)
  if not species then return nil end
  local variant = type(monOrVariant) == "string"
    and (monOrVariant == "shiny" and "shiny" or "normal")
    or Api.variantForMon(monOrVariant)
  return ("%03d:%s"):format(species, variant), species, variant
end

function Api.available()
  return Importer.modelsEnabled() and Importer.available(Api.speciesCount)
end

function Api.path(species, variant)
  species = validSpecies(species)
  if not species then return nil end
  return Importer.modelPath(species, variant)
end

function Api.read(species, variant)
  species = validSpecies(species)
  if not species then return nil, "species out of Gen 1 range" end
  return Importer.readPack(species, variant)
end

function Api.load(species, variant)
  species = validSpecies(species)
  if not species then return nil, "species out of Gen 1 range" end
  return Importer.loadModel(species, variant)
end

function Api.newRenderer(species, variant, options)
  species = validSpecies(species)
  if not species then return nil, "species out of Gen 1 range" end
  return Importer.newRenderer(species, variant, options)
end

local function baseBones(base)
  if type(base) ~= "table" or type(base.parent) ~= "table"
      or type(base.restT) ~= "table" or type(base.restR) ~= "table"
      or type(base.restS) ~= "table" then return nil end
  local bones = {}
  for i = 1, tonumber(base.boneCount) or 0 do
    local o = (i - 1) * 3
    bones[i] = {
      parent = (base.parent[i] or 0) - 1,
      t = { base.restT[o + 1], base.restT[o + 2], base.restT[o + 3] },
      r = { base.restR[o + 1], base.restR[o + 2], base.restR[o + 3] },
      s = { base.restS[o + 1], base.restS[o + 2], base.restS[o + 3] },
    }
  end
  return bones
end

local function inverse3(m)
  local a,b,c = m[1][1],m[1][2],m[1][3]
  local d,e,f = m[2][1],m[2][2],m[2][3]
  local g,h,i = m[3][1],m[3][2],m[3][3]
  local det = a*(e*i-f*h)-b*(d*i-f*g)+c*(d*h-e*g)
  if math.abs(det) < 0.000000001 then return nil end
  local k = 1 / det
  return {
    {(e*i-f*h)*k,(c*h-b*i)*k,(b*f-c*e)*k},
    {(f*g-d*i)*k,(a*i-c*g)*k,(c*d-a*f)*k},
    {(d*h-e*g)*k,(b*g-a*h)*k,(a*e-b*d)*k},
  }
end

local function mulPoint(m, x, y, z)
  return m[1][1]*x+m[1][2]*y+m[1][3]*z+m[1][4],
    m[2][1]*x+m[2][2]*y+m[2][3]*z+m[2][4],
    m[3][1]*x+m[3][2]*y+m[3][3]*z+m[3][4]
end

local function mulVector(m, x, y, z)
  return m[1][1]*x+m[1][2]*y+m[1][3]*z,
    m[2][1]*x+m[2][2]*y+m[2][3]*z,
    m[3][1]*x+m[3][2]*y+m[3][3]*z
end

local function retargetContext(appearance, base)
  local targetBones = baseBones(base)
  if not targetBones or type(appearance.bones) ~= "table" then return nil end
  local sourceDraw, sourcePivot = Build.bindMatrices(appearance.bones)
  local targetDraw, targetPivot = Build.bindMatrices(targetBones)
  local context = {}
  for i = 1, #appearance.bones do
    local drawInverse, pivotInverse = inverse3(targetDraw[i]), inverse3(targetPivot[i])
    if not drawInverse or not pivotInverse then return nil end
    context[i] = {
      sourceDraw=sourceDraw[i], sourcePivot=sourcePivot[i],
      targetDraw=targetDraw[i], drawInverse=drawInverse,
      targetPivot=targetPivot[i], pivotInverse=pivotInverse,
    }
  end
  return context
end

local copyTable

local function convertPrimitive(source, retarget)
  local uvScaleS,uvScaleT=Sampler.uvScale(source.sampler,source.textureScale)
  local wrapS,wrapT=Sampler.wrap(source.sampler)
  -- Facial animation meshes deliberately extend a little beyond their
  -- texture rectangle. Stadium 1 clamps those border texels; treating the
  -- N64 tile bits as repeat here stamps extra eyes and mouths over the face.
  if tonumber(source.texAnim) and source.texAnim >= 0 then
    wrapS,wrapT="clamp","clamp"
  end
  local prim = {
    tex = source.tex,
    cull = source.cull,
    additive = source.additive,
    texAnim = source.texAnim,
    texMap = source.texMap,
    fxFrames = source.fxFrames,
    vertCount = source.nverts,
    indexCount = source.nidx,
    uv = {},
    index = source.idx,
    px = {}, py = {}, pz = {},
    nx = {}, ny = {}, nz = {},
    bone = {},
    wrapS=wrapS, wrapT=wrapT,
    lighting=source.lighting, decal=source.decal,
  }
  for i = 1, source.nverts do
    prim.uv[i*2-1]=(source.uv[i*2-1] or 0)*uvScaleS
    prim.uv[i*2]=(source.uv[i*2] or 0)*uvScaleT
    local x,y,z = source.pos[i * 3 - 2],source.pos[i * 3 - 1],source.pos[i * 3]
    local nx,ny,nz = source.nrm[i * 3 - 2],source.nrm[i * 3 - 1],source.nrm[i * 3]
    local bone = (source.skin[i] or 0) + 1
    local bind = retarget and retarget[bone]
    if bind then
      local wx,wy,wz = mulPoint(bind.sourceDraw,x,y,z)
      wx,wy,wz = wx-bind.targetDraw[1][4],wy-bind.targetDraw[2][4],wz-bind.targetDraw[3][4]
      x,y,z = mulVector(bind.drawInverse,wx,wy,wz)
      local wnx,wny,wnz = mulVector(bind.sourcePivot,nx,ny,nz)
      nx,ny,nz = mulVector(bind.pivotInverse,wnx,wny,wnz)
      local length = math.sqrt(nx*nx+ny*ny+nz*nz)
      if length > 0 then nx,ny,nz=nx/length,ny/length,nz/length end
    end
    prim.px[i],prim.py[i],prim.pz[i] = x,y,z
    prim.nx[i],prim.ny[i],prim.nz[i] = nx,ny,nz
    -- Stadium 2 DSM4 stores zero-based rigid bone indices. StadiumBattleFX's
    -- CPU rig uses one-based Lua indices.
    prim.bone[i] = (source.skin[i] or 0) + 1
  end
  return prim
end

local function bakeBlastoiseCannons(source, base)
  local prim=copyTable(source)
  prim.px,prim.py,prim.pz={}, {}, {}
  prim.nx,prim.ny,prim.nz={}, {}, {}
  prim.bone={}
  local bones=baseBones(base)
  local draw,pivot=Build.bindMatrices(bones)
  local roots={ [18]=17,[19]=17,[22]=21,[23]=21 }
  local inverse={}
  for _,root in pairs(roots) do
    if not inverse[root] then
      inverse[root]={ draw=inverse3(draw[root]), pivot=inverse3(pivot[root]) }
    end
  end
  for vertex=1,(source.vertCount or 0) do
    local bone=source.bone[vertex]
    local root=roots[bone] or bone
    local x,y,z=source.px[vertex],source.py[vertex],source.pz[vertex]
    local nx,ny,nz=source.nx[vertex],source.ny[vertex],source.nz[vertex]
    if root~=bone then
      local wx,wy,wz=mulPoint(draw[bone],x,y,z)
      -- Seat the barrels on the upper shell rather than across the arms.
      wy=wy+45
      wx,wy,wz=wx-draw[root][1][4],wy-draw[root][2][4],wz-draw[root][3][4]
      x,y,z=mulVector(inverse[root].draw,wx,wy,wz)
      local wnx,wny,wnz=mulVector(pivot[bone],nx,ny,nz)
      nx,ny,nz=mulVector(inverse[root].pivot,wnx,wny,wnz)
      local length=math.sqrt(nx*nx+ny*ny+nz*nz)
      if length>0 then nx,ny,nz=nx/length,ny/length,nz/length end
    end
    prim.px[vertex],prim.py[vertex],prim.pz[vertex]=x,y,z
    prim.nx[vertex],prim.ny[vertex],prim.nz[vertex]=nx,ny,nz
    prim.bone[vertex]=root
  end
  return prim
end

copyTable = function(source)
  local out = {}
  for key,value in pairs(source or {}) do out[key]=value end
  return out
end

local function appendTexture(model, source)
  model.textures[#model.textures+1] = copyTable(source)
  return #model.textures
end

local function slimeTexture(source, body)
  local out=copyTable(source)
  local rgba=source and source.rgba
  local bodyRgba=body and body.rgba
  if type(rgba)~="string" or #rgba%4~=0
      or type(bodyRgba)~="string" or #bodyRgba<4 then return out end
  local br,bg,bb=bodyRgba:byte(1,3)
  local bytes={}
  for at=1,#rgba,4 do
    local r,g,b,a=rgba:byte(at,at+3)
    local hi,lo=math.max(r,g,b),math.min(r,g,b)
    if hi-lo>36 then
      bytes[#bytes+1]=string.char(r,g,b,a)
    else
      local intensity=(r+g+b)/765
      local shade=.62+intensity*.78
      bytes[#bytes+1]=string.char(
        math.min(255,math.floor(br*shade+.5)),
        math.min(255,math.floor(bg*shade+.5)),
        math.min(255,math.floor(bb*shade+.5)),a)
    end
  end
  out.rgba=table.concat(bytes)
  out.image=nil
  return out
end

-- Koffing's callback textures are I4 intensity maps. The standalone Stadium
-- 2 shader interprets intensity as both colour mix and alpha; the shared
-- Stadium 1 renderer expects ordinary RGBA. Materialise that shader contract
-- into the texture so its normal alpha pass can draw a soft cloud instead of
-- an opaque square.
local function gasTexture(source)
  local out = copyTable(source)
  local w,h=tonumber(source and source.w),tonumber(source and source.h)
  local rgba = source and source.rgba
  if type(rgba) ~= "string" or #rgba % 4 ~= 0 then return out end
  local intensities={}
  for at=1,#rgba,4 do intensities[#intensities+1]=rgba:byte(at) or 0 end
  local bytes = {}
  for at = 1, #rgba, 4 do
    local pixel=math.floor((at-1)/4)
    local x,y=pixel%(w or 1),math.floor(pixel/(w or 1))
    local sum,count=0,0
    for oy=-2,2 do for ox=-2,2 do
      local sx,sy=x+ox,y+oy
      if sx>=0 and sy>=0 and sx<(w or 1) and sy<(h or 1) then
        sum=sum+(intensities[sy*(w or 1)+sx+1] or 0)
        count=count+1
      end
    end end
    local intensity=count>0 and sum/count or 0
    local nx=((x+.5)/(w or 1))*2-1
    local ny=((y+.5)/(h or 1))*2-1
    local radial=math.max(0,1-nx*nx-ny*ny)
    local feather=radial*radial
    local alpha = math.max(0, intensity - 62) / 193 * 176 * feather
    bytes[#bytes+1] = string.char(154, 92, 178,
      math.floor(alpha + 0.5))
  end
  out.rgba = table.concat(bytes)
  out.image = nil
  return out
end

local function ghostTexture(source)
  local out=copyTable(source)
  local rgba=source and source.rgba
  if type(rgba)~="string" or #rgba%4~=0 then return out end
  local bytes={}
  for at=1,#rgba,4 do
    local r,g,b,a=rgba:byte(at,at+3)
    local intensity=math.max(r or 0,g or 0,b or 0)
    bytes[#bytes+1]=string.char(
      math.min(255,42+math.floor(intensity*.55)),
      math.min(255,18+math.floor(intensity*.28)),
      math.min(255,62+math.floor(intensity*.68)),
      math.floor((a or 0)*.82))
  end
  out.rgba=table.concat(bytes)
  out.image=nil
  return out
end

local function mirroredTexture(source)
  local out=copyTable(source)
  local w,h=tonumber(source and source.w),tonumber(source and source.h)
  local rgba=source and source.rgba
  if not (w and h and type(rgba)=="string" and #rgba==w*h*4) then return out end
  local rows={}
  for y=0,h-1 do
    local at=y*w*4+1
    local row=rgba:sub(at,at+w*4-1)
    local mirror={}
    for x=w-1,0,-1 do
      local pixel=x*4+1
      mirror[#mirror+1]=row:sub(pixel,pixel+3)
    end
    rows[#rows+1]=row..table.concat(mirror)
  end
  out.w,out.rgba=w*2,table.concat(rows)
  out.image=nil
  return out
end

local function appendStadium1Effects(model, base, appearance, species)
  for _,source in ipairs(base.prims or {}) do
    if type(source.fxFrames) == "table" and #source.fxFrames > 0 then
      local prim = copyTable(source)
      prim.fxFrames = {}
      local frames = source.fxFrames
      local textures = base.textures
      for _,slot in ipairs(frames) do
        local texture=textures[slot]
        if species==92 then texture=ghostTexture(texture) end
        prim.fxFrames[#prim.fxFrames+1] = appendTexture(model,texture)
      end
      prim.tex = prim.fxFrames[1]
      if species==92 then
        for vertex=1,(prim.vertCount or 0) do
          prim.px[vertex]=prim.px[vertex]*1.7
          prim.py[vertex]=prim.py[vertex]*1.7
          prim.pz[vertex]=prim.pz[vertex]*1.7
        end
      end
      model.prims[#model.prims+1] = prim
    end
  end
end

local function appendStadium1StaticEffects(model,base,species)
  -- These fire sheets are ordinary Stadium 1 meshes, separate from the
  -- animated spark billboards below. Stadium 2 routes its equivalents through
  -- renderer callbacks, whose carrier geometry cannot be drawn by the shared
  -- Stadium 1 material pass. Retain the matching Stadium 1 sheets so the
  -- hybrid keeps complete, animated manes, tails, and Moltres wing flames.
  local indices = species==77 and {2,3}
    or species==78 and {4,5}
    or species==146 and {5,7}
  if not indices then return end
  for _,index in ipairs(indices) do
    local source=base.prims and base.prims[index]
    local texture=source and base.textures and base.textures[source.tex]
    if source and texture then
      local prim=copyTable(source)
      prim.tex=appendTexture(model,texture)
      prim.texAnim=-1
      prim.texMap=nil
      model.prims[#model.prims+1]=prim
    end
  end
end

local function callbackCarrier(species, prim)
  local dynamicSpecies = {
    [77]=true, [78]=true, [92]=true, [109]=true, [110]=true,
    [144]=true, [146]=true,
  }
  return dynamicSpecies[species] and prim.lighting == false
    and prim.callbackOffset ~= nil and (prim.nverts or 0) >= 4
end

local function gasCarrier(species, prim)
  return species == 109 and callbackCarrier(species,prim)
end

local function compatibilityGas(source, firstVertex)
  local out = copyTable(source)
  out.nverts,out.nidx = 4,6
  out.pos,out.uv,out.nrm,out.skin,out.idx = {},{},{},{},{1,2,3,1,3,4}
  firstVertex = firstVertex or 1
  for i=1,4 do
    local sourceVertex=firstVertex+i-1
    for c=1,3 do out.pos[(i-1)*3+c]=source.pos[(sourceVertex-1)*3+c] end
    for c=1,2 do out.uv[(i-1)*2+c]=source.uv[(sourceVertex-1)*2+c] end
    for c=1,3 do out.nrm[(i-1)*3+c]=source.nrm[(sourceVertex-1)*3+c] end
    out.skin[i]=source.skin[sourceVertex]
  end
  out.fxFrames={}
  out.cull=false
  out.additive=false
  out.gasEffect=true
  return out
end

local function stadium1MaterialLayout(species)
  -- Stadium 2's dual-texture callback splits these bodies into many transient
  -- display-list pieces. StadiumBattleFX has a single-texture material pass,
  -- so retain Stadium 1's equivalent primitive topology and apply Stadium 2's
  -- same-numbered texture slots. This keeps the face/body attached correctly
  -- while retaining the Stadium 2 (including shiny) palette.
  return species == 6 or species == 8 or species == 9
    or species == 16 or species == 17 or species == 18
    or species == 88 or species == 109 or species == 110
end

local function splitGrimerEyeAndArms(source)
  local eye,body=copyTable(source),copyTable(source)
  eye.index,body.index={},{}
  for at=1,#(source.index or {}),3 do
    local a,b,c=source.index[at],source.index[at+1],source.index[at+2]
    if a and b and c then
      local eyeTriangle=source.bone[a]==33 or source.bone[b]==33 or source.bone[c]==33
      local target=eyeTriangle and eye.index or body.index
      target[#target+1],target[#target+2],target[#target+3]=a,b,c
    end
  end
  eye.indexCount=#eye.index
  eye.wrapS,eye.wrapT="clamp","clamp"
  body.indexCount=#body.index
  body.tex=7
  body.texAnim=-1
  body.texMap=nil
  body.wrapS,body.wrapT="repeat","repeat"
  return eye,body
end

function Api.validateAppearance(model)
  if type(model) ~= "table" then return false, "appearance model missing" end
  local bones, textures = tonumber(model.boneCount) or 0, #(model.textures or {})
  if bones < 1 or textures < 1 then return false, "appearance skeleton or textures missing" end
  for primIndex, prim in ipairs(model.prims or {}) do
    local vertices = tonumber(prim.nverts) or 0
    if vertices < 1 then return false, ("primitive %d has no vertices"):format(primIndex) end
    if #(prim.pos or {}) < vertices * 3 or #(prim.uv or {}) < vertices * 2
        or #(prim.nrm or {}) < vertices * 3 or #(prim.skin or {}) < vertices then
      return false, ("primitive %d has truncated vertex data"):format(primIndex)
    end
    for _, bone in ipairs(prim.skin or {}) do
      if bone < 0 or bone >= bones then
        return false, ("primitive %d references bone %d outside 0..%d")
          :format(primIndex, bone, bones - 1)
      end
    end
    for _, index in ipairs(prim.idx or {}) do
      if index < 1 or index > vertices then
        return false, ("primitive %d index %d outside 1..%d")
          :format(primIndex, index, vertices)
      end
    end
    local function textureValid(index)
      return type(index) == "number" and index >= 1 and index <= textures
    end
    if not textureValid(prim.tex) then
      return false, ("primitive %d base texture is out of range"):format(primIndex)
    end
    for _, index in pairs(prim.texMap or {}) do
      if not textureValid(index) then
        return false, ("primitive %d animated texture is out of range"):format(primIndex)
      end
    end
    for _, index in ipairs(prim.fxFrames or {}) do
      if not textureValid(index) then
        return false, ("primitive %d effect texture is out of range"):format(primIndex)
      end
    end
  end
  return true
end

-- Stadium 1 owns the auxiliary animation clock, while each Stadium 2
-- primitive owns the value->texture-slot table. The games use the same value
-- domain for all affected Gen 1 species; verify that contract rather than
-- assuming texture table positions match.
function Api.validateTextureChannels(appearance, stadium1)
  if type(appearance) ~= "table" or type(stadium1) ~= "table" then
    return false, "appearance and Stadium 1 animation model required"
  end
  for primIndex, prim in ipairs(appearance.prims or {}) do
    local channel = tonumber(prim.texAnim)
    if channel and channel >= 0 and prim.texMap then
      for auxIndex, aux in ipairs(stadium1.auxAnims or {}) do
        local stream = aux.channels and aux.channels[channel + 1]
        for _, value in ipairs(stream or {}) do
          if prim.texMap[value] == nil then
            return false, ("primitive %d channel %d has no Stadium 2 texture "
              .. "for Stadium 1 value %d (aux %d)")
              :format(primIndex, channel, value, auxIndex)
          end
        end
      end
    end
  end
  return true
end

-- Build the appearance-only hybrid consumed by StadiumBattleFX's public
-- model-source API. All animation and gameplay metadata remains on `base`.
function Api.hybridModel(species, variant, base)
  species = validSpecies(species)
  if not species then return nil, "species out of Gen 1 range" end
  if type(base) ~= "table" then return nil, "Stadium 1 animation model required" end
  variant = variant == "shiny" and "shiny" or "normal"
  local key = species .. ":" .. variant
  local hit = hybridCache[key]
  if hit and hit._stadium1Base == base then return hit end

  local appearance, err = Importer.loadModel(species, variant)
  if not appearance then return nil, err end
  local valid, validationErr = Api.validateAppearance(appearance)
  if not valid then return nil, "invalid Stadium 2 appearance: " .. tostring(validationErr) end
  local textureValid, textureErr = Api.validateTextureChannels(appearance, base)
  if not textureValid then
    return nil, "incompatible Stadium 2 texture animation: " .. tostring(textureErr)
  end
  if appearance.boneCount ~= base.boneCount then
    return nil, ("rig mismatch: Stadium 1 has %d bones, Stadium 2 has %d")
      :format(base.boneCount or -1, appearance.boneCount or -1)
  end

  local model = {}
  for name, value in pairs(base) do model[name] = value end
  model.prims = {}
  model.textures = {}
  for textureIndex,texture in ipairs(appearance.textures or {}) do
    local translated=texture
    if species==89 and textureIndex>=4 and textureIndex<=9 then
      translated=slimeTexture(texture,appearance.textures[2])
    end
    model.textures[#model.textures+1] = copyTable(translated)
  end
  local retarget = retargetContext(appearance,base)
  if stadium1MaterialLayout(species) then
    for primIndex,prim in ipairs(base.prims or {}) do
      if type(prim.fxFrames)=="table" and #prim.fxFrames>0 then
        -- Effect primitives need their Stadium 1 animation texture sets and
        -- are appended once, after the appearance geometry. Treating their
        -- base slot as a Stadium 2 material creates a second corrupt copy.
      elseif (species==88 or species==89) and (primIndex==2 or primIndex==3) then
        -- These callback-owned decal fragments become detached floor cards
        -- when the Stadium 2 material program is absent. The actual animated
        -- eyes are primitives 7 and 8 below.
      else
      local translated=copyTable(prim)
      if species==9 and (primIndex==22 or primIndex==23) then
        translated=bakeBlastoiseCannons(prim,base)
      end
      translated.wrapS=(species==88 or species==89)
        and (((species==89 and (primIndex==5 or primIndex==6))
          or primIndex<=3) and "clamp" or "repeat") or "clamp"
      translated.wrapT=translated.wrapS
      if (species==109 or species==110) and primIndex==4 then
        translated.wrapS="mirroredrepeat"
        translated.wrapT="clamp"
      end
      if species==109 and primIndex==2 then
        translated.wrapS="mirroredrepeat"
        translated.wrapT="clamp"
      end
      if species==109 and primIndex==4 then
        translated.tex=appendTexture(model,mirroredTexture(appearance.textures[18]))
        translated.texAnim=-1
        translated.texMap=nil
        translated.wrapS,translated.wrapT="clamp","clamp"
        for vertex=1,(translated.vertCount or 0) do
          local x,y=translated.px[vertex],translated.py[vertex]
          translated.uv[vertex*2-1]=math.max(0,math.min(1,(x+105)/210))
          translated.uv[vertex*2]=math.max(0,math.min(1,(-21-y)/91))
        end
      end
      if species==89 and primIndex==4 then
        -- Muk's fourth Stadium 1 primitive is body geometry. Stadium 2 slot
        -- four is the callback's black combiner input, while slot two is the
        -- authored purple body fill used by the equivalent Stadium 2 parts.
        translated.tex=2
        translated.texAnim=-1
        translated.texMap=nil
      end
      if species==89 and (primIndex==5 or primIndex==6) then
        translated.wrapS="mirroredrepeat"
        translated.wrapT="clamp"
      end
      if species==88 and primIndex==8 then
        local eye,body=splitGrimerEyeAndArms(translated)
        if eye.indexCount>0 then model.prims[#model.prims+1]=eye end
        if body.indexCount>0 then model.prims[#model.prims+1]=body end
      else
        model.prims[#model.prims+1]=translated
      end
      end
    end
    if species==109 then
      for _,prim in ipairs(appearance.prims or {}) do
        if gasCarrier(species,prim) then
          local gasFrames={}
          for frame=prim.tex,math.min(#appearance.textures,prim.tex+7) do
            gasFrames[#gasFrames+1]=appendTexture(model,gasTexture(appearance.textures[frame]))
          end
          for firstVertex=1,(prim.nverts or 0),4 do
            if firstVertex+3<=prim.nverts then
              local gas=compatibilityGas(prim,firstVertex)
              gas.fxFrames=gasFrames
              gas.tex=gasFrames[1]
              gas.effectPhase=math.floor((firstVertex-1)/4)
              local converted=convertPrimitive(gas,retarget)
              converted.gasEffect=true
              converted.effectPhase=gas.effectPhase
              model.prims[#model.prims+1]=converted
            end
          end
        end
      end
    end
  else
    for i, prim in ipairs(appearance.prims or {}) do
      if prim.effect ~= "fire" and not callbackCarrier(species,prim) then
        local converted=convertPrimitive(prim,retarget)
        if species==35 and i==3 then
          converted.wrapS="mirroredrepeat"
          converted.wrapT="clamp"
        elseif species==90 and i==7 then
          converted.wrapS="mirroredrepeat"
          converted.wrapT="clamp"
        end
        model.prims[#model.prims+1] = converted
      elseif gasCarrier(species,prim) then
        local gasFrames={}
        for frame=prim.tex,math.min(#appearance.textures,prim.tex+7) do
          gasFrames[#gasFrames+1]=appendTexture(model,gasTexture(appearance.textures[frame]))
        end
        -- The callback carrier is eighteen consecutive four-vertex cards,
        -- one for each emitter bone. Keep them separate so each follows its
        -- own Stadium 1 animated transform.
        for firstVertex=1,(prim.nverts or 0),4 do
          if firstVertex+3 <= prim.nverts then
            local gas=compatibilityGas(prim,firstVertex)
            gas.fxFrames=gasFrames
            gas.tex=gasFrames[1]
            gas.effectPhase=math.floor((firstVertex-1)/4)
            model.prims[#model.prims+1]=convertPrimitive(gas,retarget)
            model.prims[#model.prims].gasEffect=true
            model.prims[#model.prims].effectPhase=gas.effectPhase
          end
        end
      end
    end
  end
  appendStadium1StaticEffects(model,base,species)
  appendStadium1Effects(model,base,appearance,species)
  model.primCount = #model.prims
  model.texCount = #model.textures
  model.height = appearance.height
  model.floor = appearance.floor
  model.radius = appearance.radius
  model.variant = variant
  model.appearanceSource = "stadium2"
  model._stadium1Base = base
  model._stadium2Appearance = appearance
  model.bindRetargeted = retarget ~= nil
  hybridCache[key] = model
  return model
end

function Api.keepHybrid(species, variant)
  return Importer.loadModel(validSpecies(species), variant)
end

function Api.invalidateHybrids()
  hybridCache = {}
  Importer.releaseModels()
end

function Api.capabilities()
  return {
    geometry = true,
    normalTextures = true,
    shinyTextures = true,
    stadium1Animations = true,
    stadium1MoveRouting = true,
    stadium1Attachments = true,
    battleProvider = "STADIUM_BATTLE_FX:modelSources",
  }
end

function Api.hybridSupported(species)
  species = validSpecies(species)
  return species ~= nil
end

return Api
