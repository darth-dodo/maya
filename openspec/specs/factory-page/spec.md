# factory-page Specification

## Purpose
The public `/factory` page that explains how Maya is built by an agent-run software factory, with every number taken from the repo.

## Requirements

### Requirement: Public factory page
`/factory` SHALL be public: it answers 200 without a login, opens no LiveView socket, has one `h1` `#factory-heading`, the HTML title "Maya factory", no `noindex` robots meta, and the shared footer `#site-footer` with a link back to `/`.

#### Scenario: Visitor opens the factory page
- **WHEN** a visitor without a login requests `/factory`
- **THEN** the response is 200
- **AND** the page has one `h1`, `#factory-heading`, and the HTML title "Maya factory"
- **AND** the page has no `[data-phx-main]` element
- **AND** `#site-footer` has a link to `/`

#### Scenario: Indexable
- **WHEN** a visitor requests `/factory`
- **THEN** the page has no `meta[name="robots"]` whose content contains "noindex"
- **AND** `/robots.txt` has no line `Disallow: /factory`

### Requirement: Stations
The page SHALL have a section `#stations` listing four stations in order, plan, build, test and review, each as a `.station` with its name and what it produces.

#### Scenario: Four stations in order
- **WHEN** a visitor requests `/factory`
- **THEN** `#stations` has 4 `.station` elements whose names read "Plan", "Build", "Test" and "Review" in that order

### Requirement: Independent gates
The page SHALL have a section `#gates` with `#gate-ci` (CI must pass before merge), `#gate-probe` (the hourly production probe, E3) and `#gate-spoiler` (the CI spoiler gate). `#gate-spoiler` SHALL say the gate is planned until `.github/workflows/ci.yml` has a spoiler job (#40).

#### Scenario: Three gates
- **WHEN** a visitor requests `/factory`
- **THEN** `#gates` contains `#gate-ci`, `#gate-probe` and `#gate-spoiler`, each with non-empty text

#### Scenario: Spoiler gate wording stays honest
- **WHEN** `.github/workflows/ci.yml` has no job whose id contains "spoiler"
- **THEN** `#gate-spoiler` contains the word "planned"

### Requirement: Experiments from the repo
The page SHALL have a table `#experiments` with one row per experiment in `docs/factory/experiments.md`, each showing its id, change in short, metric, baseline, target and status exactly as that file states them. It SHALL show no experiment number that is not in that file.

#### Scenario: Rows match the experiments log
- **WHEN** a visitor requests `/factory`
- **THEN** `#experiments` has one row per id in `docs/factory/experiments.md` (E1 to E4 today)
- **AND** each row's baseline, target and status words equal that file's row (E1: 60%, 100%, kept; E2: 80%, 100%, kept; E3: 1 per 5 PRs, 0, inconclusive; E4: 7 per 27 PRs (4 from the phone), 0 from the phone, running)

### Requirement: Review reward, honestly
The page SHALL have a section `#review-reward` explaining that review findings are scored after merge by what the code did, never by the reviewer, and showing the backfill numbers recorded in `docs/factory/experiments.md`: how many findings led to a tested fix out of all findings, and how many escaped defects no finding flagged. It SHALL call the precision low.

#### Scenario: Backfill shown
- **WHEN** a visitor requests `/factory`
- **THEN** `#review-reward` contains the escaped defect line from `docs/factory/experiments.md` ("2 of 3 escaped defects")
- **AND** it contains the word "low"
- **AND** every number in `#review-reward` appears in the "Review reward backfill" section of `docs/factory/experiments.md`

### Requirement: Flywheel
The page SHALL have a section `#flywheel` explaining the loop: a retro with one lesson after every merge, and every 5 retros one experiment, kept or reverted on its metric, with lessons folded into `docs/factory/LESSONS.md`.

#### Scenario: Flywheel parts
- **WHEN** a visitor requests `/factory`
- **THEN** `#flywheel` contains `#experiments` and `#review-reward`
- **AND** its text names "retro" and "5"

### Requirement: Source links
The page SHALL link to FACTORY.md and the Elixir and Phoenix in 5 minutes explainer on GitHub, and SHALL NOT load any asset from another host.

#### Scenario: Links present
- **WHEN** a visitor requests `/factory`
- **THEN** the page links to `https://github.com/darth-dodo/maya/blob/main/FACTORY.md` and `https://github.com/darth-dodo/maya/blob/main/docs/elixir-phoenix-in-5-minutes.md`
- **AND** every `src` and stylesheet `href` on the page is a relative path

#### Scenario: Inclusive and spoiler-free copy
- **WHEN** a visitor requests `/factory`
- **THEN** the page text contains neither "beat" nor "defeat"
- **AND** names no Hoenn gym leader after Roxanne
