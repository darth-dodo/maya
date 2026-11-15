## ADDED Requirements

### Requirement: Level horizon
The level horizon SHALL be the level of the Next gym leader's ace, or the highest level on the Team when that is higher. With all 8 badges there SHALL be no level horizon. It SHALL be computed without IO from Progress and the ace level passed in.

#### Scenario: Level horizon at 0 badges
- **WHEN** Progress has 0 badges, a Team of Mudkip at level 5, and the Next gym ace level is 15
- **THEN** the level horizon is 15

#### Scenario: Team above the ace
- **WHEN** Progress has 0 badges, a Team of Mudkip at level 20, and the Next gym ace level is 15
- **THEN** the level horizon is 20

#### Scenario: Every badge earned
- **WHEN** Progress has all 8 badges
- **THEN** there is no level horizon
