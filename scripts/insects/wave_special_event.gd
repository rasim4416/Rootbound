## Editor-only special event marker. WaveManager does not read this.
class_name WaveSpecialEvent
extends Resource

enum Kind {
	BOSS_SPAWN,
	ELITE_BURST,
	ENEMY_RUSH,
	HEALING_WAVE,
	MUTATION,
}

@export var kind: Kind = Kind.BOSS_SPAWN
@export var time: float = 0.0
@export var label: String = ""


func kind_name() -> String:
	match kind:
		Kind.BOSS_SPAWN:
			return "Boss Spawn"
		Kind.ELITE_BURST:
			return "Elite Burst"
		Kind.ENEMY_RUSH:
			return "Enemy Rush"
		Kind.HEALING_WAVE:
			return "Healing Wave"
		Kind.MUTATION:
			return "Mutation"
		_:
			return "Event"
