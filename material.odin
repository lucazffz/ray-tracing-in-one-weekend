package main

import linalg "core:math/linalg"
import rand "core:math/rand"

Material :: struct {
	scatter: proc(m: ^Material, r: Ray, rec: HitRecord) -> (Ray, Color, bool),
}

Lambertian :: struct {
	using mat: Material,
	albedo:    Color,
}

Metal :: struct {
	using mat:   Material,
	albedo:      Color,
	fuzz_factor: f32, // 0 <= fuzz_factor <= 1
}

Dielectric :: struct {
	using mat:        Material,
	refraction_index: f32, // index of refraction
}

metal_scatter :: proc(
	m: ^Material,
	r: Ray,
	rec: HitRecord,
) -> (
	scattered_ray: Ray,
	attenuation: Color,
	scattered: bool,
) {
	metal_mat := cast(^Metal)m
	reflected :=
		linalg.normalize(linalg.reflect(r.dir, rec.normal)) +
		(metal_mat.fuzz_factor * vector3_random_in_unit_sphere())
	scattered_ray = Ray {
		origin = rec.p,
		dir    = reflected,
	}

	attenuation = metal_mat.albedo
	// large fuzz factors might lead to the ray being reflected into
	// the object, then we consider the ray to be absorbed
	scattered = linalg.dot(scattered_ray.dir, rec.normal) > 0
	return
}


lambertian_scatter :: proc(
	m: ^Material,
	r: Ray,
	rec: HitRecord,
) -> (
	scattered_ray: Ray,
	attenuation: Color,
	scattered: bool,
) {
	lambertian_mat := cast(^Lambertian)m
	scatter_dir := rec.normal + vector3_random_in_unit_sphere()
	// if normal and random vec is opposite scatter_dir will be zero
	// which will cause issues later on
	if vector3_is_near_zero(scatter_dir) do scatter_dir = rec.normal
	scattered_ray = Ray {
		origin = rec.p,
		dir    = scatter_dir,
	}

	attenuation = lambertian_mat.albedo
	scattered = true
	return
}

dielectric_scatter :: proc(
	m: ^Material,
	r: Ray,
	rec: HitRecord,
) -> (
	scattered_ray: Ray,
	attenuation: Color,
	scattered: bool,
) {
	mat := cast(^Dielectric)m

	attenuation = Color{1, 1, 1}
	ref_idx: f32 = 1.0 / mat.refraction_index if rec.front_face else mat.refraction_index

	unit_dir := linalg.normalize(r.dir)

	// total internal reflection might occur at certain angles 
	// (refracted sin_theta is greater than 1) meaning no refraction will happen

	// NOTE: normal and unit_dir are normalized so dont need to divide by length
	cos_theta := linalg.min(linalg.dot(-unit_dir, rec.normal), 1.0) // dot product def
	sin_theta := linalg.sqrt(1.0 - cos_theta * cos_theta) // trig identity

	dir: Vector3
	cannot_refract := ref_idx * sin_theta > 1.0
	// glass has reflectivity that depends on the angle of incidence
	should_reflect := reflectance(cos_theta, ref_idx) > rand.float32()

	if cannot_refract || should_reflect do dir = linalg.reflect(unit_dir, rec.normal)
	else do dir = linalg.refract(unit_dir, rec.normal, ref_idx)

	scattered_ray = Ray {
		dir    = dir,
		origin = rec.p,
	}

	scattered = true
	return

	reflectance :: proc(cosine: f32, ref_idx: f32) -> f32 {
		// Use Schlick's approximation for reflectance.
		r0 := (1.0 - ref_idx) / (1.0 + ref_idx)
		r0 = r0 * r0
		return r0 + (1.0 - r0) * linalg.pow(1.0 - cosine, 5)
	}
}
