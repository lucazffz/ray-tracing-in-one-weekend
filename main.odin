package main

import "core:fmt"
import "core:log"
import "core:math"
import linalg "core:math/linalg"
import rand "core:math/rand"
import "core:os"

Color :: [3]f32
Point3 :: [3]f32
Vector3 :: [3]f32

HitRecord :: struct {
	t:          f32,
	p:          Point3,
	// will always face in the direction of the intersecting ray
	normal:     Vector3,
	mat:        ^Material,
	// weather or not the normal points outside or inside
	front_face: bool,
}

hit_record_set_face_normal :: proc(rec: ^HitRecord, r: Ray, outward_normal: Vector3) {
	// make so that the normal always points against the ray
	// sets the record normal vector
	// NOTE: the parameter `outward_normal` is assumed to be unit length
	front_face: bool
	normal: Vector3
	if linalg.dot(r.dir, outward_normal) > 0 {
		// ray is inside the sphere
		normal = -outward_normal
		front_face = false
	} else {
		// ray is outside the sphere
		normal = outward_normal
		front_face = true
	}

	rec.front_face = front_face
	rec.normal = normal
}

Hittable :: struct {
	hit: proc(h: ^Hittable, r: Ray, t: Interval) -> (HitRecord, bool),
}

Ray :: struct {
	origin: Point3,
	dir:    Vector3,
}

Sphere :: struct {
	using hittable: Hittable,
	center:         Point3,
	radius:         f32,
	mat:            ^Material,
}

Interval :: struct {
	min: f32,
	max: f32,
}

INFINITY :: math.F32_MAX
NEG_INFINITY :: math.F32_MIN


interval_size :: proc(i: Interval) -> f32 {
	return i.max - i.min
}

interval_contains :: proc(i: Interval, x: f32) -> bool {
	return i.min <= x && x <= i.max
}

interval_surrounds :: proc(i: Interval, x: f32) -> bool {
	return i.min <= x && x < i.max
}

interval_clamp :: proc(i: Interval, x: f32) -> f32 {
	if x < i.min do return i.min
	if x > i.max do return i.max
	return x
}

UNIVERSE :: Interval {
	min = NEG_INFINITY,
	max = INFINITY,
}
EMPTY :: Interval {
	min = INFINITY,
	max = NEG_INFINITY,
}

vector3_random :: proc(min, max: f32) -> Vector3 {
	return Vector3 {
		rand.float32() * (max - min) + min,
		rand.float32() * (max - min) + min,
		rand.float32() * (max - min) + min,
	}
}

vector3_random_in_unit_sphere :: proc() -> Vector3 {
	for {
		p := vector3_random(-1, 1)
		// I assume we use squared length to avoid the sqrt operation
		// since length will be compared against 1
		lensq := linalg.length2(p)
		// constant pulled out of ass
		if 1e-20 < lensq && lensq <= 1 do return p / linalg.sqrt(lensq)
	}
}

vector3_random_on_hemisphere :: proc(normal: Vector3) -> Vector3 {
	on_unit_sphere := vector3_random_in_unit_sphere()
	if linalg.dot(on_unit_sphere, normal) > 0 do return on_unit_sphere
	return -on_unit_sphere
}

vector3_is_near_zero :: proc(vector: Vector3) -> bool {
	s: f32 = 1e-8
	return vector.x < s && vector.y < s && vector.z < s
}

ray_at :: proc(r: Ray, t: f32) -> Point3 {
	return r.origin + r.dir * t
}


hit :: proc(hittables: []^Hittable, r: Ray, t: Interval) -> (HitRecord, bool) {
	closest_so_far := t.max
	hit_anything: bool
	rec: HitRecord

	for &h in hittables {
		if temp_rec, hit := h->hit(r, Interval{t.min, closest_so_far}); hit {
			hit_anything = true
			closest_so_far = temp_rec.t
			rec = temp_rec

		}
	}

	return rec, hit_anything
}

sphere_hit :: proc(h: ^Hittable, r: Ray, t: Interval) -> (rec: HitRecord, hit: bool) {
	s := cast(^Sphere)h
	oc := s.center - r.origin
	a := linalg.length2(r.dir)
	h := linalg.dot(r.dir, oc)
	c := linalg.length2(oc) - s.radius * s.radius
	discriminant := h * h - a * c

	if discriminant < 0 do return // no real solution found, did not hit

	d_sqrt := linalg.sqrt(discriminant)

	// find the nearest root that lies in the acceptable range
	root := (h - d_sqrt) / a
	if !interval_surrounds(t, root) {
		root = (h + d_sqrt) / a
		if !interval_surrounds(t, root) do return
	}

	rec.t = root
	rec.p = ray_at(r, rec.t)
	rec.mat = s.mat
	// devide by radius to normalize normal vector
	outward_normal := (rec.p - s.center) / s.radius
	hit_record_set_face_normal(&rec, r, outward_normal)

	hit = true
	return
}


main :: proc() {
	material_ground := Lambertian {
		mat = Material{scatter = lambertian_scatter},
		albedo = Color{0.8, 0.8, 0},
	}
	material_center := Lambertian {
		mat = Material{scatter = lambertian_scatter},
		albedo = Color{0.1, 0.2, 0.5},
	}
	material_left := Dielectric {
		mat = Material{scatter = dielectric_scatter},
		refraction_index = 1.5,
	}
	material_right := Metal {
		mat = Material{scatter = metal_scatter},
		albedo = Color{0.8, 0.6, 0.2},
		fuzz_factor = 1,
	}
	material_bubble := Dielectric {
		mat = Material{scatter = dielectric_scatter},
		refraction_index = 1.5,
	}


	world := []^Hittable {
		&Sphere {
			hittable = Hittable{sphere_hit},
			center = Point3{0, -100.5, 0.5},
			radius = 100,
			mat = &material_ground,
		},
		&Sphere {
			hittable = Hittable{sphere_hit},
			center = Point3{0, 0, -1.2},
			radius = 0.5,
			mat = &material_center,
		},
		&Sphere {
			hittable = Hittable{sphere_hit},
			center = Point3{-1, 0, -1},
			radius = 0.5,
			mat = &material_left,
		},
		&Sphere {
			hittable = Hittable{sphere_hit},
			center = Point3{1, 0, -1},
			radius = 0.5,
			mat = &material_right,
		},
		&Sphere {
			hittable = Hittable{sphere_hit},
			center = Point3{-1, 0, -1},
			radius = 0.4,
			mat = &material_bubble,
		},
	}

	cam := Camera {
		origin            = Point3{0, 0, 0},
		image_width       = 900,
		aspect_ratio      = 16.0 / 9.0,
		focal_length      = 1.0,
		samples_per_pixel = 100,
		max_depth         = 100,
	}


	context.logger = log.create_console_logger()

	handle, err := os.open("build/output.ppm", os.O_RDWR)
	if err != nil {
		log.fatal("Could not open file: ", err)
		return
	}
	defer os.close(handle)

	image_width := camera_image_width(&cam)
	image_height := camera_image_height(&cam)
	buffer := make(ImageBuffer, image_height * image_width)
	defer delete(buffer)

	camera_render(&cam, world, buffer)
	write_image_buffer_to_file(handle, &buffer, &cam)

	write_image_buffer_to_file :: proc(handle: os.Handle, buffer: ^ImageBuffer, camera: ^Camera) {
		image_width := camera_image_width(camera)
		image_height := camera_image_height(camera)
		str := fmt.tprintfln("P3\n%d %d \n255", image_width, image_height)
		os.write_string(handle, str)

		for j in 0 ..< image_height {
			for i in 0 ..< image_width {
				color := buffer[i + j * image_width]
				color = color_linear_to_gamma(color)
				// ensure color is in valid range between 0 and 255
				intensity := Interval{0, 0.999}
				rbyte := int(256 * interval_clamp(intensity, color.r))
				gbyte := int(256 * interval_clamp(intensity, color.g))
				bbyte := int(256 * interval_clamp(intensity, color.b))
				str := fmt.tprintf("%d %d %d ", rbyte, gbyte, bbyte)
				os.write_string(handle, str)
			}

			os.write_string(handle, "\n")
		}
	}

	color_linear_to_gamma :: proc(color: Color) -> Color {
		// apply a linear to gamma transform for gamma 2
		color := color
		if color.r < 0 do color.r = 0
		if color.g < 0 do color.g = 0
		if color.b < 0 do color.b = 0
		return linalg.sqrt(color)
	}
}
