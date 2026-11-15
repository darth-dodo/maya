## MODIFIED Requirements

### Requirement: Hand-written locations
The `locations` table SHALL list Littleroot Town, Route 101, Oldale Town, Route 103, Route 102, Petalburg City, Route 104, Petalburg Woods and Rustboro City with badges required 0, and Route 116, Rusturf Tunnel, Route 105, Route 106 and Dewford Town with badges required 1. Every other location stays unlisted, so it is past the Spoiler horizon (fail closed). Every deploy reloads the table from the committed file.

#### Scenario: Locations up to Rustboro City
- **WHEN** the committed data is imported
- **THEN** exactly those fourteen locations exist, each with a badges required value

#### Scenario: Through Dewford after badge 1
- **WHEN** Progress has badge 1
- **THEN** Route 104 and Dewford Town are inside the Spoiler horizon and Mauville City is not

#### Scenario: Dewford waits for badge 1
- **WHEN** Progress has 0 badges
- **THEN** Dewford Town and Route 116 are not inside the Spoiler horizon
