# spoiler-horizon Specification

## Purpose

Decides, from Progress alone and without IO, what Maya may talk about: the Next gym and the locations inside the Spoiler horizon, failing closed for anything unknown.

## Requirements

### Requirement: Next gym
The Next gym SHALL be the first gym, in badge order, whose badge is not in Progress; with all 8 badges there is none.

#### Scenario: No badges
- **WHEN** Progress has 0 badges
- **THEN** the Next gym is badge 1, Roxanne in Rustboro City

#### Scenario: One badge
- **WHEN** Progress has badge 1
- **THEN** the Next gym is badge 2, Brawly

### Requirement: Badges earned
The badges earned SHALL be the number of distinct badges 1 to 8 in Progress.

#### Scenario: Counting badges
- **WHEN** Progress has badges 1 and 1
- **THEN** the badges earned is 1

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
