## ADDED Requirements

### Requirement: One entry point routes every request

`factory:ask <request>` SHALL classify a request from Abhishek into exactly one route (Bug, Feature, Later, Experiment, Question, Gated, Ambiguous; table in design.md) and SHALL name the route, the reason and the next command before it creates anything.

#### Scenario: Route announced first
- **WHEN** Abhishek runs `factory:ask "the Talk button sticks on iPad"`
- **THEN** the first output names the route, the one-line reason and the next command, before any file, Issue or comment is created

#### Scenario: Exactly one route
- **WHEN** any request is routed
- **THEN** exactly one route from the table is chosen; a request that fits two routes takes the Ambiguous route

### Requirement: Bug route files a direct Issue

A production defect with evidence SHALL become one GitHub Issue labelled `bug` and `ready-for-agent` with the evidence, a "done when", an estimate and out of scope, without a spec PR. `project-manager` SHALL set Kind, Estimate and Status on Project 1, and a milestone when the defect belongs to a block. Without evidence, the request SHALL NOT be filed as a bug.

#### Scenario: Smoke check failure
- **WHEN** Abhishek runs `factory:ask "production answers are empty since this morning, smoke run 123 failed"`
- **THEN** one `bug` Issue exists quoting the run link, with a "done when" such as "the smoke check is green twice in a row", an estimate and board fields set, and the skill prints `factory:build #N`
- **AND** no OpenSpec change, spec PR or PHASE_2.md line is created

#### Scenario: Bug without evidence
- **WHEN** the request is "I think voice is slow sometimes" with no log, run or screenshot
- **THEN** no Issue is created; the skill asks for evidence or offers the Question route with `mix maya.latency`

### Requirement: Feature route goes through the plan station

New features, blocks and spec changes SHALL go through `factory:plan`. The skill SHALL NOT file an Issue for them by hand and SHALL NOT leave the spec to the builder. A change that alters PRODUCT.md SHALL go to `grill-with-docs` first, which owns intake interviews.

#### Scenario: New feature
- **WHEN** Abhishek runs `factory:ask "Maya should read out the next gym's type weaknesses"`
- **THEN** the skill runs the stack check and hands off to `factory:plan` with a proposed change id
- **AND** no Issue exists until the spec PR is open

#### Scenario: Product change
- **WHEN** the request changes who Maya is for or what PRODUCT.md promises
- **THEN** the skill hands off to `grill-with-docs` before `factory:plan`

### Requirement: Later route writes one PHASE_2.md line

An idea for later SHALL become one line in PHASE_2.md with the date and Abhishek's words, and SHALL NOT become an Issue.

#### Scenario: Idea for later
- **WHEN** Abhishek runs `factory:ask "later: a shiny hunting counter"`
- **THEN** PHASE_2.md gains one line like `- Shiny hunting counter (2026-11-15: "later: a shiny hunting counter")`
- **AND** no Issue, OpenSpec change or experiment row is created

### Requirement: Experiment route records a candidate, never a skill edit

A factory process improvement with a measurable hypothesis SHALL become one row in the Candidates list of `docs/factory/experiments.md` (date, change, metric from `metrics.csv`, hypothesis, Abhishek's words). The skill SHALL NOT edit a skill, allowlist or CI file. A process idea without a metric SHALL take the Ambiguous route and ask which metric it should move. `factory:improve` SHALL prefer a candidate whose metric is the worst metric when it opens its next experiment.

#### Scenario: Measurable process change
- **WHEN** Abhishek runs `factory:ask "builders keep hitting permission prompts on mix test, allowlist it"`
- **THEN** experiments.md Candidates gains one row with metric `permission_prompts` and a hypothesis
- **AND** `.claude/settings.json` and every skill file are unchanged

#### Scenario: Improve picks it up
- **WHEN** the next `factory:improve` run finds `permission_prompts` is the worst metric and a candidate names it
- **THEN** that candidate becomes the experiment and its row leaves Candidates

### Requirement: Questions are answered, not filed

A question about the code, status or plans SHALL be answered in the session and SHALL create nothing.

#### Scenario: Status question
- **WHEN** Abhishek runs `factory:ask "what is left before Block 7?"`
- **THEN** the skill answers, citing `factory:recap` or `next-task` output, and points to `factory:dashboard` (#104) for a visual view
- **AND** no Issue, comment, file or line is written

### Requirement: Gated requests need an explicit yes and an ADR

A request that needs something outside the frozen stack, a paid service or a new dependency SHALL run `settled-architecture` and SHALL ask Abhishek. On yes it SHALL hand off to `factory:plan` with an ADR task in `docs/adr/`. On no it SHALL offer the Later route.

#### Scenario: Paid service
- **WHEN** Abhishek runs `factory:ask "use ElevenLabs for a nicer voice"`
- **THEN** the skill names the conflict (TTS is settled as Voxtral TTS 3; this is another, paid vendor) and asks: plan it with an ADR, park it in PHASE_2.md, or drop it
- **AND** nothing is created before the answer

#### Scenario: Yes recorded
- **WHEN** Abhishek answers "yes, plan it"
- **THEN** the hand-off to `factory:plan` carries his words and the date, and the change's tasks include writing the ADR

### Requirement: Ask only routing questions

The skill SHALL ask only questions whose answer changes the route: build now or later, paid or stack change approved, which block or milestone, which metric. It SHALL ask at most two, using AskUserQuestion with options when the answers are a short list. It SHALL NOT interview for requirements (that is `grill-with-docs` and `openspec-propose`).

#### Scenario: Ambiguous request
- **WHEN** Abhishek runs `factory:ask "Mudkip facts on the homepage"`
- **THEN** the skill asks one question with the options "build now (factory:plan)" and "later (PHASE_2.md)", then follows the answer

### Requirement: Decision recorded with date and words

Every route that creates something SHALL record the date and Abhishek's words: in the Issue body (Bug), in a comment on the Issue once `factory:plan` creates it (Feature, Gated), in the PHASE_2.md line (Later), or in the Candidates row (Experiment). Every repo edit SHALL follow the factory conventions (branch, conventional commit, changelog fragment, PR) and the skill SHALL never merge.

#### Scenario: Feature decision on the Issue
- **WHEN** `factory:plan` creates Issue #N for a request routed by `factory:ask`
- **THEN** #N has a comment like `Routed by factory:ask on 2026-11-15: "<words>"`

#### Scenario: Writing rules
- **WHEN** the skill writes any line, Issue or comment
- **THEN** the text uses inclusive language, writes "Pokémon" with é, and has no em or en dashes
