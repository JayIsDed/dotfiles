-- input.lua — desktop box: high-sens mouse compensation, numlock on.

hl.config({
  input = {
    kb_layout = "us",
    numlock_by_default = true,
    follow_mouse = 1,
    mouse_refocus = false,
    sensitivity = -0.3,
  },
  binds = {
    workspace_back_and_forth = false,
    allow_workspace_cycles = true,
    pass_mouse_when_bound = false,
  },
})
