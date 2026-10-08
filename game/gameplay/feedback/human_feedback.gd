extends Node3D

const POOL_SIZE := 6
var labels: Array[Label3D] = []
var sources: Array[CharacterBody3D] = []
var lifetimes: Array[float] = []
var voices: Array[AudioStreamPlayer3D] = []
var slot := 0
var cue_cooldown := 0.0
var enabled := true
var player: CharacterBody3D

func configure(controlled: CharacterBody3D) -> void:
	player = controlled
	var alarm := make_alarm()
	for index in range(POOL_SIZE):
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 32
		label.pixel_size = 0.008
		label.outline_size = 7
		label.modulate = Color("fff1bd")
		label.hide()
		add_child(label)
		labels.append(label)
		sources.append(null)
		lifetimes.append(0.0)
		var voice := AudioStreamPlayer3D.new()
		voice.stream = alarm
		voice.max_distance = 30.0
		voice.unit_size = 5.0
		voice.volume_db = -12.0
		add_child(voice)
		voices.append(voice)
	set_process(false)

func show_cue(body: CharacterBody3D, text: String, alarming: bool) -> void:
	if not enabled or not is_instance_valid(player) or player.position.distance_squared_to(body.position) > 900.0:
		return
	if cue_cooldown > 0.0:
		return
	cue_cooldown = 0.3
	sources[slot] = body
	lifetimes[slot] = 1.4
	labels[slot].text = text
	labels[slot].position = body.position+Vector3(0,2.25,0)
	labels[slot].show()
	if alarming:
		voices[slot].position = body.position
		voices[slot].play()
	slot = (slot+1)%POOL_SIZE
	set_process(true)

func _process(delta: float) -> void:
	cue_cooldown = maxf(cue_cooldown-delta,0.0)
	var active := false
	for index in range(POOL_SIZE):
		if lifetimes[index] <= 0.0:
			continue
		lifetimes[index] -= delta
		if lifetimes[index] > 0.0 and is_instance_valid(sources[index]):
			labels[index].position = sources[index].position+Vector3(0,2.25,0)
			active = true
		else:
			labels[index].hide()
			sources[index] = null
	if not active and cue_cooldown <= 0.0:
		set_process(false)

func make_alarm() -> AudioStreamWAV:
	# A short two-note placeholder; replace with voiced clips without changing AI.
	var samples := 4800
	var bytes := PackedByteArray()
	bytes.resize(samples*2)
	for index in range(samples):
		var time := float(index)/16000.0
		var frequency := 740.0 if time < 0.15 else 980.0
		var envelope := sin(PI*float(index)/samples)
		var value := int(sin(TAU*frequency*time)*envelope*7000.0)
		bytes.encode_s16(index*2,value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 16000
	stream.data = bytes
	return stream
