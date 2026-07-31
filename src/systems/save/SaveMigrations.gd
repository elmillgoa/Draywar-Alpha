extends RefCounted

## The version seam — Alpha A0.
##
## Schema version 1 is the only schema this build has ever written, so the
## registered steps table is empty. The walk, refusals, and injectability of
## steps for tests are real — `tests/test_save_service.gd` proves the seam by
## handing in made-up steps.
##
## When a later contract bumps the schema, add one entry keyed by the version
## it upgrades **from**. Saves may be broken freely until release.

const SaveSchema = preload("res://src/systems/save/SaveSchema.gd")


## Every migration this build knows, keyed by the version it upgrades from.
##
## Empty at A0 (schema v1 only). A function rather than a constant because a
## `Callable` cannot live in a `const`.
static func registered_steps() -> Dictionary[int, Callable]:
	return {}


## Brings an envelope up to the current schema, or explains why it cannot be.
static func apply(envelope_data: Dictionary, steps: Dictionary[int, Callable]) -> SaveResult:
	if not SaveSchema.has_version(envelope_data):
		return SaveResult.failed(
			(
				"the file does not say which schema version it is. Nothing else in it "
				+ "can be trusted, so it is not read."
			)
		)

	var version: int = SaveSchema.version_of(envelope_data)
	if version > SaveSchema.CURRENT_VERSION:
		return SaveResult.failed(
			(
				(
					"the file is schema version %d; this build reads version %d. It was "
					% [version, SaveSchema.CURRENT_VERSION]
				)
				+ "written by a newer build of Draywar. Saves are not read backwards."
			)
		)

	if version == SaveSchema.CURRENT_VERSION:
		var current: SaveResult = SaveResult.new()
		current.envelope = envelope_data
		current.schema_version = version
		return current

	return _walk(envelope_data, version, steps)


## Runs migration steps in order until the envelope reaches the current schema.
static func _walk(
	envelope_data: Dictionary, from_version: int, steps: Dictionary[int, Callable]
) -> SaveResult:
	var current: Dictionary = envelope_data
	var at: int = from_version

	while at < SaveSchema.CURRENT_VERSION:
		if not steps.has(at):
			return SaveResult.failed(
				(
					(
						"the file is schema version %d and this build reads version %d, "
						% [at, SaveSchema.CURRENT_VERSION]
					)
					+ "but no migration from %d is registered. Saves may be broken " % at
					+ "freely until release, so this is expected during the build: "
					+ "start a new career rather than repairing the file."
				)
			)

		var step: Callable = steps[at]
		var produced: Variant = step.call(current)
		if typeof(produced) != TYPE_DICTIONARY:
			return SaveResult.failed(
				(
					(
						"the migration from schema version %d returned a %s instead of an "
						% [at, type_string(typeof(produced))]
					)
					+ "envelope."
				)
			)

		var next: Dictionary = produced
		if not SaveSchema.has_version(next):
			return SaveResult.failed(
				(
					"the migration from schema version %d returned an envelope with no " % at
					+ "version field. Every step states the version it produced."
				)
			)

		var reached: int = SaveSchema.version_of(next)
		if reached <= at:
			return SaveResult.failed(
				(
					(
						"the migration from schema version %d produced version %d. A step "
						% [at, reached]
					)
					+ "must raise the version, or the walk never ends."
				)
			)

		current = next
		at = reached

	var result: SaveResult = SaveResult.new()
	result.envelope = current
	result.schema_version = at
	return result
