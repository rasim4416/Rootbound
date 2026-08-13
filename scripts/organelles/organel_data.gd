## Static definition for an Organelle type.
##
## Separate from PlantData — Organelles are not Nanobots.
class_name OrganelData
extends Resource

enum OrganelleRole {
	PRODUCER,
	SYNTHESIZER,
	OTHER,
}

@export var organelle_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var organelle_role: OrganelleRole = OrganelleRole.OTHER

@export_group("Economy")
## Bio-Energy spent in the Fabricator for one unit (shop may override).
@export var build_cost: int = 0

@export_group("Installation")
## Seconds from placement until the organelle becomes active.
@export var build_time: float = 5.0

@export_group("Integrity")
@export var max_health: float = 100.0

@export_group("ATP Production")
## ATP granted per second while mature (PRODUCER).
@export var atp_per_second: float = 0.0

@export_group("Protein Synthesis")
## Seconds between synthesis attempts (SYNTHESIZER).
@export var production_interval: float = 10.0
## ATP spent per successful protein synthesis.
@export var protein_atp_cost: int = 10
## Protein produced when unlocked.
@export var protein: ProteinData

@export_group("Runtime")
@export var runtime_scene: PackedScene


func is_producer() -> bool:
	return organelle_role == OrganelleRole.PRODUCER


func is_synthesizer() -> bool:
	return organelle_role == OrganelleRole.SYNTHESIZER
