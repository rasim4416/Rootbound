## Editor-only stats / warnings for authored WaveData. Does not affect gameplay.
class_name WaveDesignerStats
extends RefCounted


static func enemy_count(wave: WaveData) -> int:
	if wave == null:
		return 0
	return wave.build_spawn_queue().size()


static func spawn_path_count(wave: WaveData) -> int:
	if wave == null:
		return 0
	var seen: Dictionary = {}
	if not wave.spawn_entries.is_empty():
		for e: WaveSpawnEntry in wave.spawn_entries:
			if e == null or e.insect_data == null:
				continue
			var pid: StringName = e.path_id if e.path_id != &"" else wave.path_id
			seen[pid] = true
	elif enemy_count(wave) > 0:
		seen[wave.path_id] = true
	return seen.size()


static func last_spawn_at(wave: WaveData) -> float:
	if wave == null:
		return 0.0
	if not wave.spawn_entries.is_empty():
		var last: float = 0.0
		for e: WaveSpawnEntry in wave.spawn_entries:
			if e == null or e.insect_data == null or e.count <= 0:
				continue
			var interval: float = e.resolve_interval(wave.spawn_interval)
			var end_t: float = maxf(e.start_time, 0.0) + float(maxi(e.count - 1, 0)) * interval
			if end_t > last:
				last = end_t
		return last
	var n: int = maxi(wave.insect_count, 0)
	if n <= 1:
		return 0.0
	return float(n - 1) * maxf(wave.spawn_interval, 0.0)


static func estimated_duration(wave: WaveData) -> float:
	if wave == null:
		return 0.0
	return maxf(wave.delay_before_wave, 0.0) + last_spawn_at(wave)


static func estimated_reward(wave: WaveData) -> int:
	if wave == null:
		return 0
	var total: int = 0
	for insect: InsectData in wave.build_spawn_queue():
		if insect != null:
			total += insect.biomass_reward + wave.reward_bonus
	return total


static func warnings(wave: WaveData, valid_path_ids: Array[StringName]) -> PackedStringArray:
	var out := PackedStringArray()
	if wave == null:
		out.append("No wave")
		return out
	var count: int = enemy_count(wave)
	if count <= 0:
		out.append("No enemies")
	if count > 80:
		out.append("Too many enemies")
	if estimated_duration(wave) > 180.0:
		out.append("Extremely long wave")
	if not wave.spawn_entries.is_empty():
		for e: WaveSpawnEntry in wave.spawn_entries:
			if e == null:
				continue
			if e.insect_data == null:
				out.append("Group missing enemy")
				continue
			var pid: StringName = e.path_id if e.path_id != &"" else wave.path_id
			if pid == &"":
				out.append("No spawn path")
			elif not valid_path_ids.is_empty() and not valid_path_ids.has(pid):
				out.append("Invalid spawn path")
			if e.resolve_interval(wave.spawn_interval) <= 0.05 and e.count > 8:
				out.append("Spawn interval very low")
	elif count > 0 and wave.path_id != &"" and not valid_path_ids.is_empty() and not valid_path_ids.has(wave.path_id):
		out.append("Invalid spawn path")
	return out


static func list_label(wave: WaveData, index: int) -> String:
	if wave == null:
		return "Wave %d  (null)" % (index + 1)
	var warn: String = ""
	if enemy_count(wave) <= 0:
		warn = "  ⚠"
	var name: String = wave.display_name
	if name.is_empty():
		name = "Wave %d" % wave.wave_number
	return "%s  x%d  %.1fs  paths:%d%s" % [
		name,
		enemy_count(wave),
		estimated_duration(wave),
		spawn_path_count(wave),
		warn
	]


## One spawn job for offline simulation (time, insect, path).
static func spawn_events(wave: WaveData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if wave == null:
		return out
	if not wave.spawn_entries.is_empty():
		for e: WaveSpawnEntry in wave.spawn_entries:
			if e == null or e.insect_data == null:
				continue
			var interval: float = e.resolve_interval(wave.spawn_interval)
			var pid: StringName = e.path_id if e.path_id != &"" else wave.path_id
			var n: int = maxi(e.count, 0)
			for i: int in range(n):
				out.append({
					"time": maxf(e.start_time, 0.0) + float(i) * interval,
					"insect": e.insect_data,
					"path_id": pid,
				})
		return out
	var insects: Array[InsectData] = wave.build_spawn_queue()
	var interval_legacy: float = maxf(wave.spawn_interval, 0.0)
	for i: int in range(insects.size()):
		out.append({
			"time": float(i) * interval_legacy,
			"insect": insects[i],
			"path_id": wave.path_id,
		})
	return out


static func composition(wave: WaveData) -> Dictionary:
	var counts: Dictionary = {}
	if wave == null:
		return counts
	for insect: InsectData in wave.build_spawn_queue():
		if insect == null:
			continue
		var id: StringName = insect.insect_id
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


static func spawn_density_buckets(wave: WaveData, bucket_s: float = 1.0) -> PackedInt32Array:
	var buckets := PackedInt32Array()
	if wave == null or bucket_s <= 0.0:
		return buckets
	var events: Array[Dictionary] = spawn_events(wave)
	if events.is_empty():
		return buckets
	var last: float = 0.0
	for ev: Dictionary in events:
		last = maxf(last, float(ev.get("time", 0.0)))
	var n: int = maxi(int(ceil(last / bucket_s)) + 1, 1)
	buckets.resize(n)
	for ev: Dictionary in events:
		var idx: int = clampi(int(floor(float(ev.get("time", 0.0)) / bucket_s)), 0, n - 1)
		buckets[idx] = buckets[idx] + 1
	return buckets


static func estimated_path_seconds(
	insect: InsectData,
	speed_mult: float,
	cell_count: int,
	cell_size_px: float
) -> float:
	var speed: float = 1.0
	if insect != null:
		speed = maxf(insect.move_speed * maxf(speed_mult, 0.01), 1.0)
	else:
		speed = maxf(80.0 * maxf(speed_mult, 0.01), 1.0)
	if cell_count >= 2 and cell_size_px > 0.0:
		return float(cell_count) * cell_size_px / speed
	# Fallback when no path: treat 10 cells at 64px as a coarse travel time.
	return 10.0 * 64.0 / speed


static func _path_cell_count(map: EditorMapData, path_id: StringName) -> int:
	if map == null:
		return 0
	var p: EditorPathData = map.find_path(path_id)
	if p != null and p.cells.size() >= 2:
		return p.cells.size()
	if not map.paths.is_empty() and map.paths[0] != null:
		return map.paths[0].cells.size()
	return 0


static func peak_concurrent(wave: WaveData, map: EditorMapData = null) -> int:
	var events: Array[Dictionary] = spawn_events(wave)
	if events.is_empty():
		return 0
	var speed_mult: float = 1.0
	if wave != null:
		speed_mult = wave.speed_multiplier
		if map != null:
			speed_mult *= map.level_speed_multiplier
	var cell_px: float = 64.0
	if map != null:
		cell_px = maxf(map.cell_size.x, 1.0)
	var marks: Array[Vector2] = []
	for ev: Dictionary in events:
		var insect: InsectData = ev.get("insect") as InsectData
		var pid: StringName = ev.get("path_id") as StringName
		var cells: int = _path_cell_count(map, pid)
		var t0: float = float(ev.get("time", 0.0))
		var travel: float = estimated_path_seconds(insect, speed_mult, cells, cell_px)
		marks.append(Vector2(t0, 1.0))
		marks.append(Vector2(t0 + travel, -1.0))
	marks.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		if a.x == b.x:
			return a.y > b.y
		return a.x < b.x
	)
	var cur: int = 0
	var peak: int = 0
	for m: Vector2 in marks:
		cur += int(m.y)
		if cur > peak:
			peak = cur
	return peak


static func simulate(wave: WaveData, map: EditorMapData = null) -> Dictionary:
	var enemies: int = enemy_count(wave)
	var duration: float = estimated_duration(wave)
	var reward: int = estimated_reward(wave)
	var events: Array[Dictionary] = spawn_events(wave)
	var peak: int = peak_concurrent(wave, map)
	var comp: Dictionary = composition(wave)
	var diff: float = difficulty_score(wave, map, enemies, duration, peak)
	return {
		"enemies": enemies,
		"duration": duration,
		"reward": reward,
		"spawn_events": events.size(),
		"composition": comp,
		"peak_concurrent": peak,
		"difficulty": diff,
	}


static func difficulty_score(
	wave: WaveData,
	map: EditorMapData,
	enemies: int = -1,
	duration: float = -1.0,
	peak: int = -1
) -> float:
	if wave == null:
		return 0.0
	if enemies < 0:
		enemies = enemy_count(wave)
	if duration < 0.0:
		duration = estimated_duration(wave)
	if peak < 0:
		peak = peak_concurrent(wave, map)
	var events: Array[Dictionary] = spawn_events(wave)
	if enemies <= 0:
		return 0.0
	var hp_mass: float = 0.0
	var speed_sum: float = 0.0
	var core_sum: float = 0.0
	var tank_elite: int = 0
	var hp_mult: float = wave.hp_multiplier
	var speed_mult: float = wave.speed_multiplier
	var core_mult: float = wave.core_damage_multiplier
	if map != null:
		hp_mult *= map.level_hp_multiplier
		speed_mult *= map.level_speed_multiplier
		core_mult *= map.level_core_damage_multiplier
	for ev: Dictionary in events:
		var insect: InsectData = ev.get("insect") as InsectData
		if insect == null:
			continue
		hp_mass += insect.max_health * hp_mult
		speed_sum += insect.move_speed * speed_mult
		core_sum += insect.attack_damage * core_mult
		if insect.insect_role == InsectData.InsectRole.TANK or insect.insect_role == InsectData.InsectRole.SPECIAL:
			tank_elite += 1
	var n: float = float(enemies)
	var count_f: float = n / 20.0
	var hp_f: float = (hp_mass / n) / 50.0
	var speed_f: float = (speed_sum / n) / 80.0
	var dmg_f: float = (core_sum / n) / 10.0
	var tank_f: float = float(tank_elite) / n
	var peak_f: float = float(peak) / 8.0
	var dur_f: float = duration / 60.0
	var raw: float = (
		count_f * 2.4
		+ hp_f * 2.0
		+ speed_f * 1.2
		+ dmg_f * 1.0
		+ tank_f * 2.0
		+ peak_f * 1.6
		+ dur_f * 0.5
	)
	return clampf(raw, 0.0, 10.0)


static func composition_text(comp: Dictionary) -> String:
	if comp.is_empty():
		return "—"
	var parts: PackedStringArray = PackedStringArray()
	for id: Variant in comp.keys():
		parts.append("%s ×%d" % [String(id), int(comp[id])])
	parts.sort()
	return ", ".join(parts)


static func preview_text(wave: WaveData, map: EditorMapData = null) -> String:
	var sim: Dictionary = simulate(wave, map)
	return (
		"Enemies %d  ·  Duration %.1fs  ·  Reward %d\nSpawn events %d  ·  Peak ~%d  ·  Difficulty %.1f / 10\n%s"
		% [
			int(sim["enemies"]),
			float(sim["duration"]),
			int(sim["reward"]),
			int(sim["spawn_events"]),
			int(sim["peak_concurrent"]),
			float(sim["difficulty"]),
			composition_text(sim["composition"] as Dictionary),
		]
	)
