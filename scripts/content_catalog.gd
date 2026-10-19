extends RefCounted
## Validate editable content before constructing gameplay objects.
static func read(path: String) -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("Invalid lesson JSON")
		return {}
	if not data.get("cards") is Dictionary or not data.get("checkpoints") is Array or not data.get("review") is Array:
		push_error("Lesson needs cards, checkpoints and review")
		return {}
	for id in data.cards:
		var card = data.cards[id]
		if not card is Dictionary or not card.get("letters") is Array or card.letters.size()!=2 or card.get("syllable","")!=id or not ResourceLoader.exists(card.get("audio","")):
			push_error("Invalid card or missing audio: "+str(id))
			return {}
	for point in data.checkpoints:
		if not point is Dictionary or not data.cards.has(point.get("card","")) or not point.has("x") or not point.has("guided") or (point.get("glyph","")!="" and not point.has("blob_x")):
			push_error("Invalid checkpoint")
			return {}
		if point.has("choices"):
			if not point.choices is Array or point.choices.size()<2 or point.choices.size()>3 or not point.card in point.choices:
				push_error("Sorting needs two or three choices including the target")
				return {}
			for choice in point.choices:
				if not data.cards.has(choice):
					push_error("Unknown sorting card")
					return {}
	for id in data.review:
		if not data.cards.has(id):
			push_error("Unknown review card: "+str(id))
			return {}
	return data
