local wezterm = require("wezterm")
local config = {
  front_end = "WebGpu",
  font = wezterm.font({
    family = "JetBrains Mono",
    harfbuzz_features = { "calt=0", "clig=0", "liga=0" },
  }),
  font_size = 11.5,
  color_scheme = "Chameleon (Gogh)",
  window_decorations = "RESIZE",
  hide_tab_bar_if_only_one_tab = true,
  window_background_opacity = 0.97,
  initial_cols = 120,
  initial_rows = 32,
  window_padding = { left = 8, right = 8, top = 6, bottom = 6 },
  scrollback_lines = 10000,
  default_cursor_style = "BlinkingBar",
  cursor_blink_rate = 500,
  audible_bell = "Disabled",
  window_close_confirmation = "NeverPrompt",
  exit_behavior = "CloseOnCleanExit",
  keys = {
    { key = "Enter", mods = "SHIFT", action = wezterm.action.SendString("\x1b[13;2u") },
    { key = "r", mods = "CTRL|SHIFT", action = wezterm.action.ReloadConfiguration },
  },
}
-- Host-only preferences belong beside this file, outside the repository.
local directory = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local local_path = directory .. "/wezterm/local.lua"
local file = io.open(local_path, "r")
if file then
  file:close()
  local apply = dofile(local_path)
  if type(apply) == "function" then apply(config, wezterm) end
end
return config
