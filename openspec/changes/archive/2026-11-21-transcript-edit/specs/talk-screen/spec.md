# Spec Delta

## ADDED Requirements

### Requirement: Pending Question with countdown
After STT returns a non-empty transcript, the Talk screen SHALL show it in a pending Guest bubble `#pending-question` with its text in `#edit-input` and a countdown `#pending-countdown` with the hint "Tap to edit" and the seconds as text. The countdown animation SHALL NOT move under reduced motion. When it ends untouched the bubble stays as the asked Question until the Answer shows as a turn.

#### Scenario: Countdown shown
- **WHEN** STT returns "where do I catch Ralts?" and the countdown is 2000 ms
- **THEN** `#pending-question` shows "where do I catch Ralts?" and `#pending-countdown` contains "2"
- **AND** after the Answer the conversation shows a `.turn` with that Question and `#pending-question` is gone

#### Scenario: Reduced motion
- **WHEN** the Guest prefers reduced motion
- **THEN** `#pending-countdown` has no running animation and still shows the seconds as text

### Requirement: Tap to edit
`#edit-input` SHALL be a text field, so a tap focuses it in the same gesture and the phone keyboard opens. Focusing it during the countdown SHALL stop the countdown and show `#edit-send` and `#edit-cancel` in `#edit-form`, each at least 44 by 44 CSS px. Send SHALL send the edited text, trimmed, as a new Question; Cancel SHALL discard it. Empty text or text over 300 characters SHALL NOT be sent.

#### Scenario: Edit and send
- **WHEN** STT returns "where do I catch rawls", the Guest taps the text, changes it to "where do I catch Ralts?" and taps `#edit-send`
- **THEN** the countdown stopped on the tap, the agent is asked "where do I catch Ralts?" and the stored turn has that Question

#### Scenario: Cancel
- **WHEN** the Guest taps the text and then `#edit-cancel`
- **THEN** `#pending-question` is gone, the Talk button is `idle`, no Answer is spoken and no turn is stored

#### Scenario: Empty edit is not sent
- **WHEN** the Guest clears `#edit-input` and taps `#edit-send`
- **THEN** no new Question is sent and `#edit-form` stays open

#### Scenario: Targets are large enough
- **WHEN** the Question is open to edit
- **THEN** `#edit-send` and `#edit-cancel` each measure at least 44 by 44 CSS px

### Requirement: Hold again discards the pending Question
A hold on the Talk button while a Question is in its countdown or being edited SHALL discard it (its Answer never spoken, no turn stored) and record a new Question. A hold while Maya speaks SHALL stay a barge-in.

#### Scenario: Hold during the countdown
- **WHEN** a Question is pending and the Guest holds the Talk button and asks "is Zigzagoon on route 101"
- **THEN** the first Question's Answer is never spoken and the next pending bubble shows the new transcript

### Requirement: Type instead of speaking
A keyboard button `#type-button` (accessible name "Type a Question", at least 44 by 44 CSS px) next to the Talk button SHALL focus `#type-input` in `#type-form` in the same tap, with `#type-send` and `#type-cancel`. Send SHALL send the trimmed text to the agent with no STT and no countdown; Cancel SHALL close the form. Empty text or over 300 characters SHALL NOT be sent. A typed Question while Maya speaks SHALL cut her Answer.

#### Scenario: Typed Question answered
- **WHEN** the Guest taps `#type-button`, types "How do I earn Roxanne's badge?" and taps `#type-send`
- **THEN** the agent is asked "How do I earn Roxanne's badge?", the Answer is spoken, and the conversation shows that Question as the Guest's turn

#### Scenario: Typed Question too long
- **WHEN** the Guest sends 301 characters from `#type-input`
- **THEN** the agent is not called
