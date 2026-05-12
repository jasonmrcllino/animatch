extends Control

# --- 1. VARIABEL & KONFIGURASI ---
var music_enabled = true
var sfx_enabled = true
var high_score = 0
var score = 0
var moves = 0
var sidebar_open = false
var total_pairs = 4 
var pairs_found = 0
var current_difficulty_pairs = 4
var current_peek_time = 3.0
var match_label: Label

@onready var music_slider = $CanvasLayer/PopupLayer/VBoxContainer/MusicSlider
@onready var sfx_slider = $CanvasLayer/PopupLayer/VBoxContainer/SfxSlider
@onready var sfx_flip = $SfxFlip
@onready var sfx_match = $SfxMatch
@onready var sfx_error = $SfxError
@onready var music_player = $MusicPlayer
@onready var sidebar = $CanvasLayer/Sidebar
@onready var menu_button = $CanvasLayer/SafeWrapper/VBoxContainer/MenuButton
@onready var tab_bar = $CanvasLayer/SafeWrapper/VBoxContainer/TabBar
@onready var score_label = $CanvasLayer/SafeWrapper/VBoxContainer/ScoreLabel
@onready var grid = $CanvasLayer/SafeWrapper/VBoxContainer/PanelContainer/CenterContainer/CardGrid
@onready var btn_play = $CanvasLayer/SafeWrapper/VBoxContainer/HBoxContainer/Retry 
@onready var btn_settings = $CanvasLayer/SafeWrapper/VBoxContainer/HBoxContainer/Settings
@onready var popup_layer = $CanvasLayer/PopupLayer
@onready var popup_title = $CanvasLayer/PopupLayer/VBoxContainer/PopupTitle
@onready var user_name_label = $CanvasLayer/PopupLayer/VBoxContainer/UserName
@onready var overlay = $CanvasLayer/Overlay

var card_scene = preload("res://card.tscn")


var animal_images = [
	"res://assets/elephant.png",
	"res://assets/giraffe.png",
	"res://assets/hippo.png",
	"res://assets/monkey.png",
	"res://assets/panda.png",
	"res://assets/parrot.png",
	"res://assets/penguin.png",
	"res://assets/pig.png",
	"res://assets/rabbit.png",
	"res://assets/snake.png"
]

# --- Tambahan Dictionary Nama Hewan ---
var animal_names = {
	0: "GAJAH",
	1: "JERAPAH",
	2: "KUDA NIL",
	3: "MONYET",
	4: "PANDA",
	5: "BEO",
	6: "PENGUIN",
	7: "BABI",
	8: "KELINCI",
	9: "ULAR"
}

var flipped_cards = []

# --- 2. FUNGSI UTAMA (READY) ---
func _ready():
	print("Game Dimulai!")
	
	# Reset UI State
	overlay.hide()
	overlay.modulate.a = 0 
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE # Biar tembus kliknya
	popup_layer.hide()
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	tab_bar.clear_tabs()
	tab_bar.add_tab("Easy")
	tab_bar.add_tab("Medium")
	tab_bar.add_tab("Hard")
	
	tab_bar.tab_selected.connect(_on_tab_selected)
	menu_button.pressed.connect(_toggle_sidebar)
	
	btn_play.pressed.connect(func(): setup_game(current_difficulty_pairs, current_peek_time))
	
	$CanvasLayer/Sidebar/VBoxContainer/BtnExit.pressed.connect(func(): get_tree().quit())
	$CanvasLayer/Sidebar/VBoxContainer/BtnReset.pressed.connect(func():
		_toggle_sidebar() 
		setup_game(current_difficulty_pairs, current_peek_time)
	)

	if has_node("CanvasLayer/Sidebar/VBoxContainer/BtnProfile"):
		$CanvasLayer/Sidebar/VBoxContainer/BtnProfile.pressed.connect(func():
			_toggle_sidebar()
			show_popup("profile")
		)

	btn_settings.pressed.connect(func():
		show_popup("settings")
	)
	
	$CanvasLayer/PopupLayer/VBoxContainer/BtnClosePopup.pressed.connect(close_popup)
	
	music_slider.value_changed.connect(func(value):
		music_player.volume_db = value
		# Kalau value paling kecil, mute musiknya
		music_player.playing = (value > -40)
	)
	
	sfx_slider.value_changed.connect(func(value):
		sfx_flip.volume_db = value
		sfx_match.volume_db = value
		sfx_error.volume_db = value
	)
	
	setup_game(4, 3.0)

# --- 3. LOGIKA GAME ---
func setup_game(num_pairs, peek_time):
	# Hentikan semua tween yang mungkin lagi jalan (biar gak bentrok)
	var tweens = get_tree().get_processed_tweens()
	for t in tweens: t.kill()

	for n in grid.get_children():
		n.queue_free()
	
	current_difficulty_pairs = num_pairs
	current_peek_time = peek_time
	total_pairs = num_pairs
	pairs_found = 0
	score = 0
	moves = 0
	flipped_cards.clear()
	score_label.text = "Score: 0 | Moves: 0"
	
	var cards_to_spawn = []
	for i in range(num_pairs):
		cards_to_spawn.append(i)
		cards_to_spawn.append(i)
	
	cards_to_spawn.shuffle()
	
	for id in cards_to_spawn:
		var new_card = card_scene.instantiate()
		new_card.card_id = id
		new_card.front_texture = load(animal_images[id])
		grid.add_child(new_card)
		new_card.pressed.connect(_on_card_pressed.bind(new_card))
	
	peek_cards_custom(peek_time)

func peek_cards_custom(duration):
	# 1. Matikan klik saat ngintip
	for card in grid.get_children():
		card.disabled = true 
		card.flip_to_front()
	
	await get_tree().create_timer(duration).timeout 
	
	# 2. Tutup dan AKTIFKAN KEMBALI kliknya
	for card in grid.get_children():
		if is_instance_valid(card):
			card.flip_to_back()
			card.disabled = false # Ini yang bikin kartu bisa diklik lagi

# --- 4. LOGIKA MATCHING ---
func _on_card_pressed(card):
	if flipped_cards.size() < 2 and not card in flipped_cards:
		if sfx_enabled: sfx_flip.play()
		card.flip_to_front()
		flipped_cards.append(card)
		
		if flipped_cards.size() == 2:
			moves += 1
			score_label.text = "Score: " + str(score) + " | Moves: " + str(moves)
			check_match()

func check_match():
	await get_tree().create_timer(0.6).timeout
	
	if flipped_cards.size() == 2:
		if flipped_cards[0].card_id == flipped_cards[1].card_id:
			if sfx_enabled: sfx_match.play()
			score += 100
			pairs_found += 1
			score_label.text = "Score: " + str(score) + " | Moves: " + str(moves)
			
			# --- TAMBAHAN: Munculin popup nama hewan ---
			show_animal_match_popup(flipped_cards[0].card_id)
			
			flipped_cards[0].disabled = true
			flipped_cards[1].disabled = true
			if pairs_found == total_pairs:
				win_game()
		else:
			if sfx_enabled: sfx_error.play()
			flipped_cards[0].flip_to_back_error()
			flipped_cards[1].flip_to_back_error()
			flipped_cards[0].disabled = false
			flipped_cards[1].disabled = false
	
	flipped_cards.clear()

# --- 5. UI & NAVIGASI ---
func _toggle_sidebar():
	var tween = create_tween().set_parallel(true)
	if sidebar_open:
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tween.tween_property(sidebar, "position:x", -450, 0.3).set_trans(Tween.TRANS_SINE)
		tween.tween_property(overlay, "modulate:a", 0.0, 0.3)
		await tween.finished
		overlay.hide()
	else:
		overlay.show()
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		tween.tween_property(sidebar, "position:x", 0, 0.3).set_trans(Tween.TRANS_SINE)
		tween.tween_property(overlay, "modulate:a", 1.0, 0.3)
	
	sidebar_open = !sidebar_open

func _on_tab_selected(tab_index):
	var pairs = 4
	var p_time = 3.0
	if tab_index == 1:
		pairs = 6
		p_time = 2.0
	elif tab_index == 2:
		pairs = 10
		p_time = 1.0
	setup_game(pairs, p_time)

func win_game():
	if sfx_enabled:
		$SfxWin.play()
	
	var is_new_record = false
	if score > high_score:
		high_score = score
		is_new_record = true
	
	# Biar jelas, bar atas tulis skor ronde ini aja
	score_label.text = "GAME CLEAR! Score: " + str(score)
	
	# Kirim info ke popup
	show_popup("win")

func show_popup(type: String):
	# Tampilkan popupnya dulu
	popup_layer.show()
	popup_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Sembunyiin slider secara default
	music_slider.hide()
	sfx_slider.hide()
	
	# MAKSA WARNA TEKS ISINYA
	user_name_label.add_theme_color_override("font_color", Color("#4A4F41"))
	
	if type == "profile":
		popup_title.set_text("USER PROFILE")
		user_name_label.text = "1. Jason Marcellino Heldy (231011400197)\n" + \
							"2. Rashid Tegar Prihandoko (231011403391)\n" + \
							"3. Tata Astelia Cahyani (231011400206)\n\n" + \
							"Teknik Informatika - UNPAM"
							
	elif type == "settings":
		popup_title.set_text("GAME SETTINGS")
		user_name_label.text = "Adjust Music & SFX Volume:" 
		music_slider.show()
		sfx_slider.show()

	elif type == "win":
		popup_title.set_text("CONGRATULATIONS!")
		user_name_label.text = "Ronde Selesai!\n\n" + \
							"Skor Lu: " + str(score) + "\n" + \
							"Rekor Tertinggi: " + str(high_score) + "\n" + \
							"Total Langkah: " + str(moves)
	
	# Animasi muncul
	popup_layer.scale = Vector2(0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(popup_layer, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK)

func close_popup():
	var tween = create_tween()
	tween.tween_property(popup_layer, "scale", Vector2(0.8, 0.8), 0.1)
	await tween.finished
	popup_layer.hide()
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

func toggle_music():
	music_enabled = !music_enabled
	if music_enabled:
		music_player.play()
	else:
		music_player.stop()
	show_popup("settings") # Refresh teks popup biar kelihatan ON/OFF nya

func toggle_sfx():
	sfx_enabled = !sfx_enabled
	show_popup("settings") # Refresh teks popup

func _on_overlay_gui_input(event):
	# Jika ada klik mouse atau sentuhan layar di area kosong (overlay)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if sidebar_open:
			_toggle_sidebar() # Tutup sidebarnya

func show_animal_match_popup(id):
	# Kita pake PopupTitle buat nampilin "MATCH!" 
	# dan User_Name_Label buat nampilin nama hewannya
	popup_title.set_text("MATCH!")
	user_name_label.text = "\nItu adalah:\n[ " + animal_names.get(id, "Hewan") + " ]"
	
	# Sembunyiin slider volume kalo lagi nampil ini
	music_slider.hide()
	sfx_slider.hide()
	
	popup_layer.show()
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE # Biar gak ganggu klik kartu selanjutnya
	
	# Animasi muncul bentar terus ilang sendiri (1 detik)
	popup_layer.scale = Vector2(0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(popup_layer, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_BACK)
	
	await get_tree().create_timer(1.0).timeout
	
	if popup_title.text == "MATCH!": # Biar gak nutup popup Profile/Settings kalo gak sengaja buka
		popup_layer.hide()
