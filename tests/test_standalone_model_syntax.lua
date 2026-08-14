local files = {
  "lib/Mat4.lua",
  "lib/StadiumRender.lua",
  "lib/StadiumModelRom.lua",
  "lib/StadiumFragment.lua",
  "lib/StadiumFx.lua",
  "lib/StadiumBuild.lua",
  "lib/StadiumInstall.lua",
  "lib/StadiumPack.lua",
  "lib/StadiumRig.lua",
  "lib/StadiumMon.lua",
  "lib/StadiumModels.lua",
  "lib/StadiumModelProvider.lua",
  "lib/StadiumModelApi.lua",
  "lib/BattleProviders.lua",
  "lib/BattleArtCompat.lua",
  "lib/BattleHost.lua",
}

for _, path in ipairs(files) do
  local chunk, err = loadfile(path)
  assert(chunk, path .. " did not compile: " .. tostring(err))
end

print("ok standalone Stadium model/runtime syntax")

