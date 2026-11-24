# A single 0-10 meter: icon + name + bar + numeric value. Configured per-instance via exports.
extends HBoxContainer
class_name MeterBar

@export var meter_name: String = "Treasury"
@export var icon: String = "•"
@export var fill_color: Color = Color.GOLD

@onready var icon_label: Label = $Icon
@onready var name_label: Label = $NameLabel
@onready var bar: ProgressBar = $Bar
@onready var value_label: Label = $ValueLabel

func _ready() -> void:
	icon_label.text = icon
	name_label.text = meter_name
	bar.min_value = 0.0
	bar.max_value = 10.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(150, 22)
	add_theme_constant_override("separation", 8)
	value_label.add_theme_font_size_override("font_size", 18)
	# Inset track (the empty part): a recessed, ink-bordered channel.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.7, 0.62, 0.46)
	track.set_border_width_all(1)
	track.border_color = Color(0.34, 0.24, 0.14)
	track.set_corner_radius_all(5)
	track.set_content_margin_all(2)
	bar.add_theme_stylebox_override("background", track)
	# Colored fill (gold / ember / violet), rounded to sit inside the track.
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)

func set_value(v: int) -> void:
	bar.value = float(v)
	value_label.text = str(v)
