extends Node
enum Zindex {STANDARD, STONE, OSC}

var drawing = true
var paintbrush = Zindex.STONE

func reset():
	var bytes = PackedByteArray()
	for px in 512 ** 2:
		for byte in 6:
			bytes.append(0)
	var image = Image.new()
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
			var zval = round(zimage.get_pixel(x, y).r * 8) / 8.
			image.set_pixel(x, y, Color(valtostore(0), valtostore(0), zval))
	$SimViewport/SimShader.material.set_shader_parameter("screen", ImageTexture.create_from_image(image))
	for frame in 4:
		await get_tree().process_frame

func valtostore(val: float):
	#return 0.5 - atan(val) / PI
	return (val + 2) / 4

func _process(_delta: float):
	if drawing:
		var image = $DrawingRect.texture.get_image()
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var mousepos = get_viewport().get_mouse_position()
			for x in range(mousepos.x - 8, mousepos.x + 9):
				for y in range(mousepos.y - 8, mousepos.y + 9):
					image.set_pixel(x, y, Color.RED * (paintbrush * 0.125))
			$DrawingRect.texture.set_image(image)
		$DrawingShader.material.set_shader_parameter("screen", $DrawingRect.texture)
	else:
		var image = $SimTexture.texture.get_image()
		var texture = ImageTexture.create_from_image(image)
		$SimViewport/SimShader.material.set_shader_parameter("screen", texture)

func startdrawing():
	var bytes = PackedByteArray()
	for px in 512 ** 2:
		for byte in 1:
			bytes.append(0)
	var image = Image.new()
	image.set_data(512, 512, false, Image.FORMAT_R8, bytes)
	$DrawingRect.texture.set_image(image)

func toggledrawing():
	if drawing:
		await reset()
	drawing = not drawing
	$DrawingRect.visible = drawing
	$DrawingShader.visible = drawing

func _input(event: InputEvent):
	if event.is_action_pressed("drawtoggle"):
		toggledrawing()
	if event.is_action_pressed("palette"):
		paintbrush = (paintbrush + 1) % 3

func _ready():
	startdrawing()
	await toggledrawing()
