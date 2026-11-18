Added: "Maya, humor 60": `set_setting` changes the Humor dial by voice (0 to 100) and says "Humor set to 60 percent."; spoilers and other Dials, or a value out of range, are refused
Changed: after a write, the rest of the turn uses a system prompt built from the new Progress
Changed: the honesty check catches a "set to" or Dial change claim when no `log_event` or `set_setting` ran
