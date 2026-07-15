class_name EncounterRewardData
extends Resource
## Authored, one-shot skill-point payout for one meaningful encounter (issue
## #60). Attach one to an EncounterRoom's reward_data to award skill points the
## first time that room is cleared. `reward_id` is the persistent completion key
## (SaveManager milestone id): it must be unique per rewarding encounter so a
## paid reward can never be farmed by dying and re-clearing the room.

@export var reward_id: StringName = &""
@export_range(1, 99, 1) var skill_points: int = 1


func is_valid() -> bool:
	return reward_id != StringName() and skill_points > 0
