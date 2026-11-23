extends "res://tools/fnd01/native_capture.gd"

# Use the existing +133 ms sample, when the burst is visible behind the card.
const REWARD_STILL_SAMPLE: int = 2

var _sample_index: int

func _read_frame() -> Image:
	var image: Image = super._read_frame()
	var capture: bool = _sample_index == REWARD_STILL_SAMPLE
	_sample_index += 1
	if capture and image != null and not super._save(image, "reward-acquisition.png"):
		return null
	return image

func _save(_image: Image, _name: String) -> bool:
	return true
