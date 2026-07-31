extends GutTest

## Entity / Person shapes and shipped standing content — Alpha A2.


func test_entity_requires_standing_in_range() -> void:
	var entity: Entity = Entity.new()
	entity.id = &"fixture_entity"
	entity.display_name = "Fixture"
	entity.default_player_standing = 500.0
	var joined: String = "\n".join(entity.validation_errors())
	assert_string_contains(joined, "default_player_standing")

	entity.default_player_standing = BalanceStanding.DEFAULT_STANDING
	entity.dock_refusal_threshold = BalanceStanding.DEFAULT_DOCK_REFUSAL_THRESHOLD
	assert_eq(entity.validation_errors().size(), 0)


func test_entity_rejects_bad_relationship_link() -> void:
	var entity: Entity = Entity.new()
	entity.id = &"fixture_entity_links"
	entity.display_name = "Fixture"
	var link: EntityLink = EntityLink.new()
	link.target_id = &""
	link.relation_type = &"not_a_relation"
	entity.relationship_links = [link] as Array[EntityLink]
	var joined: String = "\n".join(entity.validation_errors())
	assert_string_contains(joined, "target_id")
	assert_string_contains(joined, "relation_type")


func test_person_requires_entity_and_rank() -> void:
	var person: Person = Person.new()
	person.id = &"fixture_person"
	person.display_name = "Fixture"
	var joined: String = "\n".join(person.validation_errors())
	assert_string_contains(joined, "primary_entity_id")
	assert_string_contains(joined, "rank")

	person.primary_entity_id = &"entity_reach_authority"
	person.rank = Person.RANK_MID
	assert_eq(person.validation_errors().size(), 0)


func test_shipped_entities_and_people_meet_alpha_caps() -> void:
	var entities: Array[StringName] = ContentLibrary.ids_in(&"entities")
	var people: Array[StringName] = ContentLibrary.ids_in(&"people")
	assert_eq(entities.size(), 4, "A2 ships 4 entities")
	assert_eq(people.size(), 12, "A2 ships 12 people")
	assert_lte(entities.size(), Balance.CONTENT_BUDGET[&"entities"])
	assert_lte(people.size(), Balance.CONTENT_BUDGET[&"people"])


func test_shipped_standing_content_has_no_problems() -> void:
	var problems: PackedStringArray = ContentLibrary.problems()
	assert_eq(problems.size(), 0, "content problems:\n  %s" % "\n  ".join(problems))


func test_alpha_controllers_wire_to_entities() -> void:
	var alpha: StarSystem = ContentLibrary.item(&"system_alpha") as StarSystem
	assert_eq(alpha.held_by, &"entity_reach_authority")
	var port: Station = ContentLibrary.item(&"station_alpha_port") as Station
	assert_eq(port.controller_entity_id, &"entity_reach_authority")
	var beta: StarSystem = ContentLibrary.item(&"system_beta") as StarSystem
	assert_eq(beta.held_by, &"entity_beta_syndicate")
	var gamma: StarSystem = ContentLibrary.item(&"system_gamma") as StarSystem
	assert_eq(gamma.held_by, &"entity_gamma_collective")


func test_entity_link_known_relations() -> void:
	assert_true(EntityLink.KNOWN_RELATIONS.has(EntityLink.RELATION_ALLIED))
	assert_true(EntityLink.KNOWN_RELATIONS.has(EntityLink.RELATION_RIVAL))
	assert_true(EntityLink.KNOWN_RELATIONS.has(EntityLink.RELATION_MEMBER_OF))
