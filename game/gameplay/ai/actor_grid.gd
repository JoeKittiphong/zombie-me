extends RefCounted

const CELL_SIZE := 6.0
const EMPTY := []
var humans: Dictionary = {}
var zombies: Dictionary = {}
var infected: Dictionary = {}
var research_bodies: Dictionary = {}
var queries := 0
var candidate_checks := 0
var sample_cursor := 0
var maximum_odor_strength := 1.0
var maximum_noise_strength := 1.0

func collect_zombies(pos: Vector3, radius: float, output: Array[CharacterBody3D]) -> void:
	# Approximate crowd senses have a hard work bound; exact nearest() stays available for bites.
	queries += 1
	sample_cursor += 17
	output.clear()
	var center := Vector2i(floori(pos.x/CELL_SIZE),floori(pos.z/CELL_SIZE))
	var rings := ceili((radius+2.0)/CELL_SIZE)
	collect_cell(center,pos,radius,output)
	for ring in range(1,rings+1):
		for dx in range(-ring,ring+1):
			for dz in range(-ring,ring+1):
				if absi(dx) != ring and absi(dz) != ring:
					continue
				collect_cell(center+Vector2i(dx,dz),pos,radius,output)
				if output.size() >= 64:
					return

func collect_cell(cell: Vector2i, pos: Vector3, radius: float, output: Array[CharacterBody3D]) -> void:
	var bucket: Array = zombies.get(cell,EMPTY)
	var count := mini(bucket.size(),16)
	for index in range(count):
		var actor: CharacterBody3D = bucket[(index+sample_cursor)%bucket.size()]
		candidate_checks += 1
		if actor.zombie and not actor.dead and pos.distance_squared_to(actor.position) <= radius*radius:
			output.append(actor)
			if output.size() >= 64:
				return

func rebuild(player: CharacterBody3D, citizens: Array) -> void:
	maximum_odor_strength = 0.0
	maximum_noise_strength = 0.0
	for bucket in humans.values():
		bucket.clear()
	for bucket in zombies.values():
		bucket.clear()
	for bucket in infected.values():
		bucket.clear()
	for bucket in research_bodies.values():
		bucket.clear()
	insert(player)
	for actor in citizens:
		insert(actor)

func insert(actor: CharacterBody3D) -> void:
	if actor.dead:
		if actor.zombie:
			var corpse_cell := Vector2i(floori(actor.position.x/CELL_SIZE),floori(actor.position.z/CELL_SIZE))
			if not research_bodies.has(corpse_cell):
				research_bodies[corpse_cell] = []
			research_bodies[corpse_cell].append(actor)
		return
	var index_cell := Vector2i(floori(actor.position.x/CELL_SIZE),floori(actor.position.z/CELL_SIZE))
	if actor.can_be_cured():
		if not infected.has(index_cell):
			infected[index_cell] = []
		infected[index_cell].append(actor)
	if not actor.zombie and not actor.can_be_hunted():
		return
	if actor.zombie:
		maximum_odor_strength = maxf(maximum_odor_strength,clampf(actor.odor_strength,0.0,2.0))
		maximum_noise_strength = maxf(maximum_noise_strength,clampf(actor.noise_strength,0.0,2.0))
	var cells: Dictionary = zombies if actor.zombie else humans
	var cell := Vector2i(floori(actor.position.x/CELL_SIZE),floori(actor.position.z/CELL_SIZE))
	if not cells.has(cell):
		cells[cell] = []
	cells[cell].append(actor)

func nearest(pos: Vector3, radius: float, want_zombie: bool) -> CharacterBody3D:
	queries += 1
	var cells: Dictionary = zombies if want_zombie else humans
	# Index refresh is staggered; margin covers movement between refreshes.
	var padded := radius+2.0
	var lower := Vector2i(floori((pos.x-padded)/CELL_SIZE),floori((pos.z-padded)/CELL_SIZE))
	var upper := Vector2i(floori((pos.x+padded)/CELL_SIZE),floori((pos.z+padded)/CELL_SIZE))
	var best: CharacterBody3D
	var distance := radius*radius
	for x in range(lower.x,upper.x+1):
		for z in range(lower.y,upper.y+1):
			for actor in cells.get(Vector2i(x,z),EMPTY):
				candidate_checks += 1
				if want_zombie:
					if not actor.zombie or actor.dead:
						continue
				elif not actor.can_be_hunted():
					continue
				var candidate: float = pos.distance_squared_to(actor.position)
				if candidate < distance:
					distance = candidate
					best = actor
	return best

func nearest_infected(pos: Vector3, radius: float) -> CharacterBody3D:
	queries += 1
	var lower := Vector2i(floori((pos.x-radius-2.0)/CELL_SIZE),floori((pos.z-radius-2.0)/CELL_SIZE))
	var upper := Vector2i(floori((pos.x+radius+2.0)/CELL_SIZE),floori((pos.z+radius+2.0)/CELL_SIZE))
	var best: CharacterBody3D
	var distance := radius*radius
	for x in range(lower.x,upper.x+1):
		for z in range(lower.y,upper.y+1):
			for body in infected.get(Vector2i(x,z),EMPTY):
				candidate_checks += 1
				if not body.can_be_cured():
					continue
				var candidate: float = pos.distance_squared_to(body.position)
				if candidate < distance:
					distance = candidate
					best = body
	return best

func nearest_research_body(pos: Vector3, radius: float, progress: RefCounted, researcher: CharacterBody3D) -> CharacterBody3D:
	queries += 1
	var center := Vector2i(floori(pos.x/CELL_SIZE),floori(pos.z/CELL_SIZE))
	var rings := ceili(radius/CELL_SIZE)+1
	var best: CharacterBody3D
	var distance := radius*radius
	var checked := 0
	# Corpses are immobile; bounded rotating samples prevent dense corpse piles from full scans.
	sample_cursor += 17
	for ring in range(rings+1):
		for dx in range(-ring,ring+1):
			for dz in range(-ring,ring+1):
				if ring > 0 and absi(dx) != ring and absi(dz) != ring:
					continue
				var bucket: Array = research_bodies.get(center+Vector2i(dx,dz),EMPTY)
				for index in range(mini(bucket.size(),16)):
					var body: CharacterBody3D = bucket[(index+sample_cursor)%bucket.size()]
					candidate_checks += 1
					checked += 1
					var candidate: float = pos.distance_squared_to(body.position)
					if candidate < distance and progress.can_study(body,researcher):
						distance = candidate
						best = body
					if checked >= 64:
						return best
	return best
