# A single ruler. Sliders are moral character (-3..3); skills are aptitudes (0..3).
class_name Ruler
extends RefCounted

var name: String = "Unnamed"
var age: int = 20
var upbringing: String = ""
var origin_advisor: String = ""

var sliders: Dictionary = {
	"temperament": 0,   # cruel(-) .. merciful(+)
	"purse": 0,         # greedy(-) .. charitable(+)
	"bearing": 0,       # proud(-) .. humble(+)
	"trust": 0,         # paranoid(-) .. trusting(+)
	"faith": 0,         # zealous(-) .. worldly(+)
	"vengefulness": 0,  # vengeful(-) .. forgiving(+)
	"temperance": 0,    # hedonist(-) .. ascetic(+)
	"valor": 0,         # craven(-) .. brave(+)
	"wrath": 0,         # wrathful(-) .. calm(+)
	"appetite": 0,      # lustful(-) .. chaste(+)
}

var skills: Dictionary = {
	"cunning": 0,
	"charm": 0,
	"martial": 0,
	"stewardship": 0,
	"learning": 0,
}

func describe() -> String:
	return "%s (mar%d cun%d cha%d stw%d)" % [name, skills.martial, skills.cunning, skills.charm, skills.stewardship]
