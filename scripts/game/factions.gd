class_name Factions
extends RefCounted
## Names and roles of the Foundation's Mobile Task Forces and the Chaos
## Insurgency's cells (constant data, not game state). Each round picks one
## of each; escapees and, later, reinforcement waves belong to them.

const MTF_UNITS: Array[Dictionary] = [
	{"designation": "Epsilon-11", "nickname": "Nine-Tailed Fox", "role": "Internal security and containment breaches"},
	{"designation": "Nu-7", "nickname": "Hammer Down", "role": "Heavy military operations"},
	{"designation": "Beta-7", "nickname": "Maz Hatters", "role": "Biological and hazardous anomalies"},
	{"designation": "Alpha-1", "nickname": "Red Right Hand", "role": "High-priority assignments"},
	{"designation": "Eta-10", "nickname": "See No Evil", "role": "Visual and perception-based anomalies"},
	{"designation": "Delta-4", "nickname": "Minutemen", "role": "Rapid response operations"},
	{"designation": "Zeta-9", "nickname": "Mole Rats", "role": "Underground and enclosed-space exploration"},
]

## The kinds of Chaos Insurgency groups.
const CI_GROUPS: Array[Dictionary] = [
	{"name": "Military Cells", "role": "Combat units responsible for raids, sabotage, assaults on Foundation facilities, and recovering anomalous assets."},
	{"name": "Research and Development (R&D) Cells", "role": "Groups that develop equipment, conduct experiments, and work with anomalous technology."},
	{"name": "Delta Command", "role": "The central leadership structure of the Chaos Insurgency."},
]

const CI_CELLS: Array[Dictionary] = [
	{"designation": "CI-01", "nickname": "Iron Fist", "role": "Heavy assault"},
	{"designation": "CI-02", "nickname": "Black Hawk", "role": "Infiltration and espionage"},
	{"designation": "CI-03", "nickname": "Dead Signal", "role": "Communications disruption"},
	{"designation": "CI-04", "nickname": "Rogue Cell", "role": "Standard raids"},
	{"designation": "CI-05", "nickname": "Broken Arrow", "role": "Demolition and sabotage"},
	{"designation": "CI-06", "nickname": "Gravekeepers", "role": "Anomalous asset recovery"},
	{"designation": "CI-07", "nickname": "Red Harvest", "role": "Large-scale offensive operations"},
	{"designation": "CI-08", "nickname": "Ghost Protocol", "role": "Covert operations"},
	{"designation": "CI-09", "nickname": "Last Resort", "role": "Emergency deployments"},
	{"designation": "CI-10", "nickname": "Black Crown", "role": "Elite operations"},
]


## e.g. 'Epsilon-11 "Nine-Tailed Fox"'
static func unit_name(unit: Dictionary) -> String:
	if unit.is_empty():
		return ""
	return '%s "%s"' % [unit.designation, unit.nickname]
