extends Node
enum Zindex {STANDARD, STONE, OSC, ANTI}
const pallettecols: Dictionary[Zindex, Color] = {
	Zindex.STANDARD: Color.BLACK,
	Zindex.STONE: Color.WHITE * 0.75,
	Zindex.OSC: Color.RED,
	Zindex.ANTI: Color.BLUE,
}

const SIZE := 512

var drawing := false
var paintbrush := Zindex.OSC
var lastmousepos: Vector2
var lastmousegood := false
var sim_ready := false
var state_texture := Texture2DRD.new()
var read_index := 0
var write_index := 1

func reset() -> void:
	var bytes := _state_bytes()
	read_index = 0
	write_index = 1
	RenderingServer.call_on_render_thread(_upload_state.bind(bytes))
	await get_tree().process_frame

func _state_bytes() -> PackedByteArray:
	var zimage: Image = $DrawingRect.texture.get_image()
	var bytes := PackedByteArray()
	bytes.resize(SIZE * SIZE * 16)
	var i := 0
	for y in SIZE:
		for x in SIZE:
			var kind := round(zimage.get_pixel(x, y).r * 8.0)
			bytes.encode_float(i, 0.0)
			bytes.encode_float(i + 4, 0.0)
			bytes.encode_float(i + 8, kind)
			bytes.encode_float(i + 12, 1.0)
			i += 16
	return bytes

func larpdraw(mousepos: Vector2, image: Image) -> void:
	print(1)
	if not lastmousegood:
		lastmousepos = mousepos
		lastmousegood = true
	var delta := mousepos - lastmousepos
	var line: Array[Vector2]
	var stepper := mousepos
	if min(abs(delta.x), abs(delta.y)) == 0:
		for step in delta.length() + 1:
			line.append(stepper)
			stepper += delta.normalized()
	else:
		for step in abs(delta.x) * abs(delta.y) + 1:
			line.append(stepper)
			for axis in 2:
				if int(step) % int(abs(delta[axis])) == 0:
					stepper[1 - axis] += sign(delta[1 - axis])
	var points: Dictionary[Vector2, bool]
	var radius := 16 if paintbrush == Zindex.STANDARD else 8
	for point in line:
		for x in range(point.x - radius, point.x + radius + 1):
			for y in range(point.y - radius, point.y + radius + 1):
				if (x - point.x) ** 2 + (y - point.y) ** 2 < radius ** 2:
					points[Vector2(x, y)] = true
	for point in points:
		if min(point.x, point.y) >= 0 and max(point.x, point.y) < 512:
			image.set_pixelv(point, Color.RED * (paintbrush * 0.125))
	lastmousepos = mousepos

func _process(_delta: float) -> void:
	if drawing:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var image: Image = $DrawingRect.texture.get_image()
			larpdraw(get_viewport().get_mouse_position(), image)
			$DrawingRect.texture.set_image(image)
		else:
			lastmousegood = false
		$DrawingShader.material.set_shader_parameter("screen", $DrawingRect.texture)
	elif sim_ready:
		_step_simulation()

func startdrawing() -> void:
	var bytes := PackedByteArray()
	for px in 512 ** 2:
		for byte in 1:
			bytes.append(0)
	var image := Image.new()
	image.set_data(512, 512, false, Image.FORMAT_R8, bytes)
	$DrawingRect.texture.set_image(image)

func toggledrawing() -> void:
	lastmousegood = false
	if drawing:
		await reset()
		lastmousegood = false
	drawing = not drawing
	for rect in [$DrawingRect, $DrawingShader, $PalletteSample]:
		rect.visible = drawing

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("drawtoggle"):
		toggledrawing()
	if event.is_action_pressed("paletteup"):
		paintbrush = ((int(paintbrush) + 1) % Zindex.size()) as Zindex
	if event.is_action_pressed("pallettedown"):
		paintbrush = ((int(paintbrush) + Zindex.size() - 1) % Zindex.size()) as Zindex
	if event.is_action_pressed("clear"):
		if not drawing:
			await toggledrawing()
		startdrawing()
	if event.is_action_pressed("magnitoggle"):
		var vismat: ShaderMaterial = $VisualShader.material
		vismat.set_shader_parameter("magnitude", not vismat.get_shader_parameter("magnitude"))
	updatesample()

func updatesample() -> void:
	$PalletteSample.material.set_shader_parameter("samplecol", pallettecols[paintbrush])

func _ready() -> void:
	startdrawing()
	RenderingServer.call_on_render_thread(_initialize_compute_code)
	await get_tree().process_frame
	_bind_display_texture()
	await toggledrawing()
	updatesample()

func _exit_tree() -> void:
	if state_texture:
		state_texture.texture_rd_rid = RID()
	RenderingServer.call_on_render_thread(_free_compute_resources)

func _step_simulation() -> void:
	state_texture.texture_rd_rid = texture_rds[write_index]
	var time := float(Time.get_ticks_msec()) * 0.001
	RenderingServer.call_on_render_thread(_dispatch.bind(read_index, write_index, time))
	var previous := read_index
	read_index = write_index
	write_index = previous

func _bind_display_texture() -> void:
	if texture_rds.is_empty() or not texture_rds[0].is_valid():
		push_error("Wave simulation needs the Forward+ renderer so the field can stay in float32.")
		return
	state_texture.texture_rd_rid = texture_rds[0]
	var mat: ShaderMaterial = $VisualShader.material
	mat.set_shader_parameter("state", state_texture)
	sim_ready = true

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var texture_rds: Array[RID] = []
var read_sets: Array[RID] = []
var write_sets: Array[RID] = []

func _make_image_set(texture_rd: RID, set_index: int) -> RID:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(texture_rd)
	return rd.uniform_set_create([uniform], shader, set_index)

func _initialize_compute_code() -> void:
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		push_error("No rendering device. Switch the project renderer to Forward+.")
		return
	var shader_file: RDShaderFile = load("res://sim_compute.glsl")
	var spirv := shader_file.get_spirv()
	if spirv.compile_error_compute != "":
		push_error(spirv.compile_error_compute)
		return
	shader = rd.shader_create_from_spirv(spirv)
	pipeline = rd.compute_pipeline_create(shader)

	var tf := RDTextureFormat.new()
	tf.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.width = SIZE
	tf.height = SIZE
	tf.depth = 1
	tf.array_layers = 1
	tf.mipmaps = 1
	tf.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	)
	for i in 2:
		var tex := rd.texture_create(tf, RDTextureView.new(), [])
		rd.texture_clear(tex, Color(0, 0, 0, 1), 0, 1, 0, 1)
		texture_rds.append(tex)
		read_sets.append(_make_image_set(tex, 0))
		write_sets.append(_make_image_set(tex, 1))

func _upload_state(bytes: PackedByteArray) -> void:
	if rd == null:
		return
	for tex in texture_rds:
		rd.texture_update(tex, 0, bytes)

func _dispatch(src: int, dst: int, time: float) -> void:
	if not pipeline.is_valid() or not read_sets[src].is_valid() or not write_sets[dst].is_valid():
		return
	var push := PackedFloat32Array([time, 0.0, 0.0, 0.0])
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, read_sets[src], 0)
	rd.compute_list_bind_uniform_set(compute_list, write_sets[dst], 1)
	rd.compute_list_set_push_constant(compute_list, push.to_byte_array(), push.size() * 4)
	rd.compute_list_dispatch(compute_list, SIZE / 16, SIZE / 16, 1)
	rd.compute_list_end()

func _free_compute_resources() -> void:
	if rd == null:
		return
	for tex in texture_rds:
		if tex.is_valid():
			rd.free_rid(tex)
	for s in read_sets + write_sets:
		if s.is_valid():
			rd.free_rid(s)
	if shader.is_valid():
		rd.free_rid(shader)
	texture_rds.clear()
	read_sets.clear()
	write_sets.clear()
