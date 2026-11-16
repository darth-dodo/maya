Fixed: music or video another app was playing can resume after a turn with Maya: once the mic closes and Maya is silent, the Talk hook suspends its AudioContext and sets the audio session back to "auto"
Added: JS tests for the Talk hook's pure helpers (`node --test test/js/*_test.mjs`), run in CI's format job
