extends TextureButton



var card_id = 0 # Angka buat nentuin ini hewan apa

var front_texture # Wadah buat nyimpen gambar hewan

var back_texture = preload("res://assets/cardBack_blue3.png")



func flip_to_front():

	var tween = create_tween()

	# Efek 'pop' sedikit

	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.05)

	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.05)

	texture_normal = front_texture

	disabled = true



func flip_to_back():

	# Goyang dikit (shaking) buat nandain kalau salah

	modulate = Color.WHITE

	texture_normal = back_texture

	disabled = false



func flip_to_back_error():

	var tween = create_tween()

	# Goyang dikit (shaking) dan warna merah

	tween.tween_property(self, "modulate", Color.RED, 0.1)

	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

	texture_normal = back_texture

	disabled = false
