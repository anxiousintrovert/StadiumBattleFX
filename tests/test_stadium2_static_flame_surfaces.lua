local appearance

package.preload["mods.STADIUM_BATTLE_FX.lib.stadium2.importer"] = function()
  return {
    loadModel=function() return appearance end,
    modelsEnabled=function() return true end,
    available=function() return true end,
  }
end

local identity = {
  {1,0,0,0},
  {0,1,0,0},
  {0,0,1,0},
  {0,0,0,1},
}
package.preload["mods.STADIUM_BATTLE_FX.lib.stadium2.build"] = function()
  return {
    bindMatrices=function(bones)
      local draw,pivot={},{}
      for index=1,#bones do draw[index],pivot[index]=identity,identity end
      return draw,pivot
    end,
  }
end
package.preload["mods.STADIUM_BATTLE_FX.lib.stadium2.sampler"] = function()
  return {
    uvScale=function() return 1,1 end,
    wrap=function() return "clamp","clamp" end,
  }
end

local Api = assert(loadfile("lib/stadium2/model_pack_api.lua"))()

local function primitive(texture, marker)
  return {
    tex=texture, texAnim=-1, marker=marker,
    vertCount=1, indexCount=0,
    px={0},py={0},pz={0},nx={0},ny={1},nz={0},bone={1},uv={0,0},index={},
  }
end

local function baseModel(count, flameIndices)
  local prims={}
  for index=1,count do prims[index]=primitive(1,"ordinary-" .. index) end
  for _,index in ipairs(flameIndices) do prims[index]=primitive(index,"flame-" .. index) end
  local textures={}
  for index=1,count do textures[index]={w=1,h=1,rgba=string.char(index,0,0,255)} end
  return {
    boneCount=1,parent={0},restT={0,0,0},restR={0,0,0},restS={1,1,1},
    prims=prims,textures=textures,auxAnims={},
  }
end

local function check(species, count, indices)
  appearance={
    boneCount=1,bones={{parent=-1,t={0,0,0},r={0,0,0},s={1,1,1}}},
    textures={{w=1,h=1,rgba=string.char(255,255,255,255)}},prims={},height=1,
  }
  local model,err=Api.hybridModel(species,"normal",baseModel(count,indices))
  assert(model,err)
  assert(#model.prims==#indices,
    ("species %d should restore %d static flame surfaces, got %d")
      :format(species,#indices,#model.prims))
  for position,index in ipairs(indices) do
    local prim=model.prims[position]
    assert(prim.marker=="flame-" .. index)
    assert(prim.tex==1+position,"each restored surface must own its copied texture")
    assert(model.textures[prim.tex].rgba:byte(1)==index)
  end
end

check(77,3,{2,3})
check(78,5,{4,5})
check(146,7,{5,7})

appearance={
  boneCount=1,bones={{parent=-1,t={0,0,0},r={0,0,0},s={1,1,1}}},
  textures={{w=1,h=1,rgba=string.char(255,255,255,255)}},prims={},height=1,
}
local unaffected=assert(Api.hybridModel(76,"normal",baseModel(3,{2,3})))
assert(#unaffected.prims==0,"ordinary species must not inherit flame surfaces")

local function checkStableMaterialLayout(species)
  appearance={
    boneCount=1,bones={{parent=-1,t={0,0,0},r={0,0,0},s={1,1,1}}},
    textures={{w=1,h=1,rgba=string.char(32,64,96,255)}},prims={},height=1,
  }
  local base=baseModel(2,{})
  base.prims[2].marker="effect"
  base.prims[2].fxFrames={1}
  local model,err=Api.hybridModel(species,"normal",base)
  assert(model,err)
  assert(#model.prims==2,
    ("species %d must retain stable Stadium 1 topology"):format(species))
  assert(model.prims[1].marker=="ordinary-1")
  assert(model.prims[2].marker=="effect",
    "the effect primitive must be appended exactly once")
  assert(model.prims[2].tex==2 and model.prims[2].fxFrames[1]==2,
    "the effect primitive must use its copied Stadium 1 texture set")
end

for _,species in ipairs({6,8,9,16,17,18}) do
  checkStableMaterialLayout(species)
end

do
  local base=baseModel(23,{})
  base.boneCount=23
  base.parent,base.restT,base.restR,base.restS={},{},{},{}
  appearance={boneCount=23,bones={},textures={{w=1,h=1,rgba=string.char(255,255,255,255)}},prims={},height=1}
  for bone=1,23 do
    base.parent[bone]=0
    local at=(bone-1)*3
    base.restT[at+1],base.restT[at+2],base.restT[at+3]=0,0,0
    base.restR[at+1],base.restR[at+2],base.restR[at+3]=0,0,0
    base.restS[at+1],base.restS[at+2],base.restS[at+3]=1,1,1
    appearance.bones[bone]={parent=-1,t={0,0,0},r={0,0,0},s={1,1,1}}
  end
  local function cannonPrimitive(left,right)
    return {
      tex=1,texAnim=-1,vertCount=2,indexCount=0,
      px={0,0},py={0,0},pz={0,0},nx={0,0},ny={1,1},nz={0,0},
      bone={left,right},uv={0,0,0,0},index={},
    }
  end
  base.prims[22]=cannonPrimitive(18,22)
  base.prims[23]=cannonPrimitive(19,23)
  local model,err=Api.hybridModel(9,"shiny",base)
  assert(model,err)
  assert(model.prims[22].bone[1]==17 and model.prims[22].bone[2]==21)
  assert(model.prims[23].bone[1]==17 and model.prims[23].bone[2]==21,
    "Blastoise cannon geometry must remain on the shoulder roots")
  assert(model.prims[22].py[1]==45 and model.prims[23].py[1]==45,
    "Blastoise cannon mounts must retain their upper-shell offset")
end

return true
