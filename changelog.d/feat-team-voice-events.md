Added: Team changes as Events: `deposited`, `withdrawn`, `set_lead`, `set_team` and `set_level`, each one undoable Event, with a `slot` detail to pick one of two same-species members (team-voice part A).
Added: A Team change that changes nothing writes no Event, and a repeated deposit or withdraw inside 2 minutes is logged once.
