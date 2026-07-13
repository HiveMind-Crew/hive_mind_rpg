class_name EncounterRewardData
extends Resource
## Authored, persistent payout for one meaningful encounter.

@export var reward_id: StringName = &""
@export_range(1, 99, 1) var skill_points: int = 1


func is_valid() -> bool:
	return reward_id != StringName() and skill_points > 0
