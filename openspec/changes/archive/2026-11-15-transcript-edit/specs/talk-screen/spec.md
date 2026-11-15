# Spec Delta

## ADDED Requirements

### Requirement: Pending Question with countdown
After STT returns a non-empty transcript, the Talk screen SHALL show it in a pending Guest bubble `#pending-question` with a visible countdown `#pending-countdown` and the hint "Tap to edit". The countdown SHALL show the seconds left as text; its animation SHALL NOT move when the Guest prefers reduced motion. When the countdown ends untouched, the bubble SHALL become the Guest's turn and the Question goes to the agent.

#### Scenario: Countdown shown
- **WHEN** STT returns "where do I catch Ralts?" and the countdown is 2000 ms
- **THEN** `#pending-question` contains "where do I catch Ralts?" and `#pending-countdown` contains "2"
- **AND** after the countdown the conversation shows a `.turn` with that Question and `#pending-question` is gone

#### Scenario: Reduced motion
- **WHEN** the Guest prefers reduced motion
- **THEN** `#pending-countdown` has no running animation and still shows the seconds left as text

### Requirement: Tap to edit
Tapping `#pending-question` during the countdown SHALL stop the countdown and open `#edit-form` with `#edit-input` prefilled with the transcript, a Send button `#edit-send` and a Cancel button `#edit-cancel`, each at least 44 by 44 CSS px. Send SHALL send the edited text, trimmed, as the Question. Cancel SHALL discard the Question and close the editor. Empty text or text over 300 characters SHALL NOT be sent.

#### Scenario: Edit and send
- **WHEN** STT returns "where do I catch rawls" and the Guest taps the bubble, changes the text to "where do I catch Ralts?" and taps `#edit-send`
- **THEN** the countdown stopped on the tap, the agent is asked "where do I catch Ralts?" and the stored turn has that Question

#### Scenario: Cancel
- **WHEN** the Guest taps the bubble and then `#edit-cancel`
- **THEN** `#edit-form` and `#pending-question` are gone, the Talk button is `idle`, the agent is not called and no turn is stored

#### Scenario: Empty edit is not sent
- **WHEN** the Guest clears `#edit-input` and taps `#edit-send`
- **THEN** the agent is not called and `#edit-form` stays open

#### Scenario: Targets are large enough
- **WHEN** `#edit-form` is open
- **THEN** `#edit-send` and `#edit-cancel` each measure at least 44 by 44 CSS px

### Requirement: Hold again discards the pending Question
A hold on the Talk button while a Question is pending or being edited SHALL discard it (no agent call, no turn stored) and record a new Question. A hold while Maya speaks SHALL stay a barge-in.

#### Scenario: Hold during the countdown
- **WHEN** a Question is pending and the Guest holds the Talk button and asks "is Zigzagoon on route 101"
- **THEN** the first Question is never sent to the agent and the next pending bubble shows the new transcript

### Requirement: Type instead of speaking
A keyboard button `#type-button` (accessible name "Type a Question", at least 44 by 44 CSS px) next to the Talk button SHALL open `#type-form` with `#type-input`, `#type-send` and `#type-cancel`. Send SHALL send the trimmed text straight to the agent with no STT and no countdown; Cancel SHALL close the form. Empty text or text over 300 characters SHALL NOT be sent. While Maya speaks, sending a typed Question SHALL cut the Answer as a barge-in does.

#### Scenario: Typed Question answered
- **WHEN** the Guest taps `#type-button`, types "How do I earn Roxanne's badge?" and taps `#type-send`
- **THEN** the agent is asked "How do I earn Roxanne's badge?", the Answer is spoken, and the conversation shows that Question as the Guest's turn

#### Scenario: Typed Question too long
- **WHEN** the Guest sends 301 characters from `#type-input`
- **THEN** the agent is not called
