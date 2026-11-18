## MODIFIED Requirements

### Requirement: Allowed locations fail closed
A location SHALL be allowed only when it is in the `locations` table and its badges required is at most the badges earned. A location not in the table SHALL NOT be allowed.

#### Scenario: Rustboro City at 0 badges
- **WHEN** Progress has 0 badges and the location is Rustboro City
- **THEN** it is allowed

#### Scenario: Location needing a badge
- **WHEN** Progress has 0 badges and a location requires 1 badge
- **THEN** it is not allowed, and with 1 badge it is allowed

#### Scenario: Unlisted location
- **WHEN** the location is Route 111, which is not in the table
- **THEN** it is not allowed for 0, 1, 2 or 3 badges
