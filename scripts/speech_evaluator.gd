class_name SpeechEvaluator
extends RefCounted
## Future adapters must report uncertainty separately from incorrect reading.
signal evaluated(result: Dictionary)
func is_available() -> bool:
	return false
func evaluate(_expected: String) -> void:
	evaluated.emit({"status": "unavailable", "reason": "Распознавание не подключено"})
func cancel() -> void:
	pass
