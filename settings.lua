data:extend({
  {
    type = "int-setting",
    name = "addiction-timer-minutes",
    setting_type = "runtime-global",
    default_value = 60,
    minimum_value = 15,
    maximum_value = 600,
    order = "a"
  },
  {
    type = "int-setting",
    name = "faat-warning-minutes",
    setting_type = "runtime-global",
    default_value = 5,
    minimum_value = 0,
    maximum_value = 600,
    order = "a2"
  },
  {
    type = "bool-setting",
    name = "faat-carryover",
    setting_type = "runtime-global",
    default_value = true,
    order = "b"
  },
  {
    type = "bool-setting",
    name = "faat-lockout",
    setting_type = "runtime-global",
    default_value = false,
    order = "c"
  }
})
