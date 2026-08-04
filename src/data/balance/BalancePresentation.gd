class_name BalancePresentation
extends RefCounted

## Presentation floor helpers — Steam S10.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S10 §11
##
## Lit materials + emission so ships/stations read on screenshots without AAA art.

## Soft key light albedo scale when using shaded mode.
const HULL_METALLIC: float = 0.35
const HULL_ROUGHNESS: float = 0.55
const ENGINE_EMISSION_ENERGY: float = 2.2
const ACCENT_EMISSION_ENERGY: float = 0.85
const STATION_EMISSION_ENERGY: float = 0.4
const GATE_EMISSION_ENERGY: float = 1.1
const PROJECTILE_EMISSION_ENERGY: float = 3.0

## Rim / fresnel-ish boost via emission from albedo.
const EMISSION_FROM_ALBEDO: float = 0.12


## Shaded hull body material (player / hostile / traffic).
static func hull_material(albedo: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_color = albedo
	mat.metallic = HULL_METALLIC
	mat.roughness = HULL_ROUGHNESS
	mat.emission_enabled = true
	mat.emission = albedo * EMISSION_FROM_ALBEDO
	mat.emission_energy_multiplier = ACCENT_EMISSION_ENERGY
	return mat


## Bright engine glow (still readable at range).
static func engine_material(albedo: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_color = albedo
	mat.metallic = 0.1
	mat.roughness = 0.4
	mat.emission_enabled = true
	mat.emission = albedo
	mat.emission_energy_multiplier = ENGINE_EMISSION_ENERGY
	return mat


## Canopy / accent glass-ish.
static func accent_material(albedo: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_color = albedo
	mat.metallic = 0.2
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = albedo * 0.4
	mat.emission_energy_multiplier = ACCENT_EMISSION_ENERGY
	return mat


## Station module — lit with mild emission so docks pop against starfield.
static func station_material(albedo: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_color = albedo
	mat.metallic = 0.45
	mat.roughness = 0.65
	mat.emission_enabled = true
	mat.emission = albedo * 0.15
	mat.emission_energy_multiplier = STATION_EMISSION_ENERGY
	return mat


## Gate ring / beacon.
static func gate_material(albedo: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_color = albedo
	mat.metallic = 0.5
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = albedo
	mat.emission_energy_multiplier = GATE_EMISSION_ENERGY
	return mat


## Projectile / muzzle / flash — unshaded emissive (VFX stay snappy).
static func vfx_material(albedo: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = albedo
	mat.emission_enabled = true
	mat.emission = albedo
	mat.emission_energy_multiplier = PROJECTILE_EMISSION_ENERGY
	return mat
