local files = {
  "animation_routing", "build", "cache", "discovery", "effect_renderer",
  "extract", "fragment", "fx", "handler_registry", "import_screen",
  "importer", "layout", "materials", "model_handlers", "model_pack_api",
  "pack", "palette", "render_contract", "renderer", "rom", "sampler",
  "texture_parity", "vertex_semantics", "effects/dynamic_object",
  "effects/dynamic_object_manifest", "render_callbacks/dual_texture_material",
  "render_callbacks/flame", "render_callbacks/phase5_geometry",
}

for _, name in ipairs(files) do
  local path = "lib/stadium2/" .. name .. ".lua"
  local chunk, err = loadfile(path)
  assert(chunk, path .. ": " .. tostring(err))
end

print("ok embedded Stadium 2 module syntax")
