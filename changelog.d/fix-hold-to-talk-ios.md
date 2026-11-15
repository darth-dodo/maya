Fixed: holding the Talk button on iPhone no longer ends early: the trainer card stays full while recording, and server re-renders no longer reset the button's state mid-hold
Fixed: the microphone is released when each hold ends, so the phone's mic indicator goes off between Questions
Added: each hold logs how it ended (`pointerup` or `pointercancel`), how long it was and how long the mic took to open, with no audio or text
