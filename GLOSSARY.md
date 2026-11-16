# Maya

Maya is a talking, spoiler-free companion for one player of Pokémon Emerald: the player holds a button, asks out loud, and hears a short answer that fits their progress.

## Language

### The conversation

**Question**:
One spoken request from the player, captured while the talk button is held.
_Avoid_: prompt, query, message

**Answer**:
Maya's reply to one Question: 2 to 3 spoken sentences, also shown as text.
_Avoid_: response, reply, output

**Answer time**:
The time from the player releasing the talk button to the first sound of the Answer.
_Avoid_: latency (unqualified), response time

**Talk button**:
The single hold-to-talk control on Maya's screen; holding it records a Question.
_Avoid_: mic button, push-to-talk button

**Conversation**:
The full history of Questions and Answers shown on Maya's screen as a scrolling chat.
_Avoid_: chat log, transcript, thread

**Guest**:
One browser's signed session; owns one Conversation and one Progress.
_Avoid_: user, account, session id (in Maya's speech)

### The player's game

**Progress**:
What Maya knows about the player's save: badges earned, team, PC box, and current location.
_Avoid_: state, save data, profile

**PC box**:
Where a catch goes when the Team already has 6, as in the game. Kept in Progress, never shown on the trainer card.
_Avoid_: storage, bench

**Team**:
The Pokémon currently in the player's party, with their levels.
_Avoid_: party (in Maya's speech), roster

**Next gym**:
The first gym whose badge the player has not earned yet.
_Avoid_: current gym, upcoming gym

**Trainer card**:
The card at the top of the Talk screen showing the Guest's Progress: location, Next gym with its type, Team and badge count. It never shows anything past the Next gym.
_Avoid_: HUD, header, profile card

**Spoiler horizon**:
The edge of what Maya may talk about: everything up to and including the Next gym, nothing past it.
_Avoid_: spoiler limit, safe zone

**Spoiler**:
Any fact about the game past the Spoiler horizon: places, trainers, Pokémon, items or story.
_Avoid_: leak

**Event**:
A moment the player tells Maya about ("I just earned Roxanne's badge", "Mudkip evolved") that changes their Progress.
_Avoid_: update, log entry, "beat" or "defeat" (say "earned the badge")

### What Maya knows

**Fact**:
A piece of game information that comes from Maya's own data (Pokémon, moves, encounters, trainers, Walkthrough notes), never from the model's memory.
_Avoid_: knowledge, info

**Walkthrough note**:
A short, original note about one location saying what is there and where to go next, tagged with the badges needed to reach it.
_Avoid_: guide, walkthrough text

### Maya's character

**Dial**:
One setting of Maya's personality, as a percentage: humor, honesty, sass, spoilers and Mudkip hype.
_Avoid_: setting, slider, parameter

**Humor dial**:
The one Dial the player changes by voice ("humor 60 percent"), which Maya confirms out loud.
_Avoid_: joke level

**Spoilers dial**:
Fixed at 0; it can never be raised, so the Spoiler horizon always holds.
_Avoid_: spoiler mode

**Catchphrase**:
"Mudkip would approve.", the line Maya uses after good news or a solid plan.
_Avoid_: tagline, slogan
