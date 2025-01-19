package main

import linalg "core:math/linalg"

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
