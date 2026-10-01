extends Node
enum Zindex {STANDARD, STONE, OSC, ANTI}
const pallettecols: Dictionary[Zindex, Color] = {
	Zindex.STANDARD: Color.BLACK,
	Zindex.STONE: Color.WHITE * 0.75,
	Zindex.OSC: Color.RED,
	Zindex.ANTI: Color.BLUE,
}

var drawing := false
var paintbrush := Zindex.OSC
var lastmousepos: Vector2
var lastmousegood := false

func reset() -> void:
	var bytes := PackedByteArray()
	for px in 512 ** 2:
		for byte in 6:
			bytes.append(0)
	var image := Image.new()
	image.set_data(512, 512, false, Image.FORMAT_RGB16, bytes)
	var zimage: Image = $DrawingRect.texture.get_image()
	for x in 512:
		for y in 512:
			#var zindex = Zindex.STANDARD
			#var disp = Vector2(x, y) / 256. - Vector2.ONE
			#if disp.length() < 0.5:
				#zindex = Zindex.STONE
			#if (Vector2.ONE - abs(disp)).length() < 2 ** -5.:
				#zindex = Zindex.OSC
			var zval: float = round(zimage.get_pixel(x, y).r * 8) / 8.
			image.set_pixel(x, y, Color(valtostore(0), valtostore(0), zval))
	$SimViewport/SimShader.material.set_shader_parameter("screen", ImageTexture.create_from_image(image))
	for frame in 4:
		await get_tree().process_frame

func valtostore(val: float) -> float:
	#return 0.5 - atan(val) / PI
	return (val + 2) / 4

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
	else:
		var image: Image = $SimTexture.texture.get_image()
		var texture := ImageTexture.create_from_image(image)
		$SimViewport/SimShader.material.set_shader_parameter("screen", texture)

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
	await toggledrawing()
	updatesample()
