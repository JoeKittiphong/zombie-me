extends RefCounted

const CELL_SIZE := 6.0
const EMPTY := []
var humans: Dictionary = {}
var zombies: Dictionary = {}
var queries := 0
var candidate_checks := 0

func rebuild(player: CharacterBody3D, citizens: Array) -> void:
	for bucket in humans.values():
		bucket.clear()
	for bucket in zombies.values():
		bucket.clear()
	insert(player)
	for actor in citizens:
		insert(actor)

func insert(actor: CharacterBody3D) -> void:
	if not actor.zombie and (actor.infected or actor.busy):
		return
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
					if not actor.zombie:
						continue
				elif actor.infected or actor.busy:
					continue
				var candidate: float = pos.distance_squared_to(actor.position)
				if candidate < distance:
					distance = candidate
					best = actor
	return best
