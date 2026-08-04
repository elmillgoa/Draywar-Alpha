extends GutTest

## S10 standing tier colors + glyphs — text remains primary cue.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S10 a11y


func test_every_known_tier_has_color_and_glyph() -> void:
	for tier: StringName in BalanceStanding.KNOWN_TIERS:
		var color: Color = BalanceStanding.tier_color(tier)
		assert_ne(color.a, 0.0, "tier color alpha for %s" % tier)
		var glyph: String = BalanceStanding.tier_glyph(tier)
		assert_false(glyph.is_empty(), "tier glyph for %s" % tier)


func test_hostile_and_friendly_are_not_identical_colors() -> void:
	var friendly: Color = BalanceStanding.tier_color(BalanceStanding.TIER_FRIENDLY)
	var hostile: Color = BalanceStanding.tier_color(BalanceStanding.TIER_HOSTILE)
	assert_false(
		(
			is_equal_approx(friendly.r, hostile.r)
			and is_equal_approx(friendly.g, hostile.g)
			and is_equal_approx(friendly.b, hostile.b)
		),
		"friendly and hostile must differ"
	)


func test_hated_not_pure_red_green_pair_with_revered() -> void:
	## Colorblind-safe intent: not only R/G channel opposition.
	var hated: Color = BalanceStanding.tier_color(BalanceStanding.TIER_HATED)
	var revered: Color = BalanceStanding.tier_color(BalanceStanding.TIER_REVERED)
	assert_gt(hated.b, 0.5, "hated uses violet (blue channel), not pure red")
	assert_gt(revered.b, 0.5, "revered uses cyan/blue, not pure green")


func test_glyphs_differ_across_negative_band() -> void:
	assert_ne(
		BalanceStanding.tier_glyph(BalanceStanding.TIER_UNFRIENDLY),
		BalanceStanding.tier_glyph(BalanceStanding.TIER_HOSTILE)
	)
	assert_ne(
		BalanceStanding.tier_glyph(BalanceStanding.TIER_HOSTILE),
		BalanceStanding.tier_glyph(BalanceStanding.TIER_HATED)
	)


func test_unknown_tier_falls_back_to_neutral() -> void:
	var color: Color = BalanceStanding.tier_color(&"not_a_tier")
	assert_eq(color, BalanceStanding.TIER_COLOR_NEUTRAL)
	assert_eq(BalanceStanding.tier_glyph(&"not_a_tier"), BalanceStanding.TIER_GLYPH_NEUTRAL)
