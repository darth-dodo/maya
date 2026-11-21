## ADDED Requirements

### Requirement: Type reasons from a committed file
`priv/data/type_reasons.json` SHALL hold short, original reason lines, each with `attacker`, `defender`, `multiplier` and `reason`. The import SHALL load it into a `type_reasons` table and SHALL fail, changing no table, when a pair is not in `type_matchups.json` with the same multiplier, names Fairy, appears twice, or has a reason over 60 characters or containing "beat" or "defeat".

#### Scenario: Clean reasons
- **WHEN** the committed data is imported
- **THEN** `type_reasons` has one row per line of `type_reasons.json`

#### Scenario: Wrong direction
- **WHEN** the reason checker reads a fixture with Fire on Water at multiplier 2
- **THEN** it reports the pair as not matching the chart

#### Scenario: Neutral pair, Fairy or banned word
- **WHEN** the checker reads a fixture with Normal on Water, a Fairy row, or the reason "Water can beat Fire"
- **THEN** it reports each row and the import changes no table
