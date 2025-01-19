package main

import "core:fmt"
import "core:log"
import linalg "core:math/linalg"
import rand "core:math/rand"
import "core:os"

// need to be dynamically allocated since image dimensions are not 
// known at compile time, easiest way to do that is to 
// allocate 1-dim array of size width * height and index it 
// by [i + j * width]
ImageBuffer :: []Color

Camera :: struct {
	origin:            Point3,
	image_width:       int,
	aspect_ratio:      f32,
	focal_length:      f32,
	samples_per_pixel: int,
	max_depth:         int,
}

camera_image_width :: proc(c: ^Camera) -> int {
	return c.image_width
}

camera_image_height :: proc(c: ^Camera) -> int {
	height := int(f32(c.image_width) / c.aspect_ratio)
	if height < 1 do return 1
	return height
}

@(private = "file")
ImageInfo :: struct {
	viewport_height:     f32,
	viewport_width:      f32,
	viewport_u:          Vector3,
	viewport_v:          Vector3,
	pixel_delta_u:       Vector3,
	pixel_delta_v:       Vector3,
	viewport_upper_left: Point3,
	pixel00_loc:         Point3,
}

@(private = "file")
image_info_create :: proc(c: ^Camera) -> ImageInfo {
	image_width := camera_image_width(c)
	image_height := camera_image_height(c)
	// viewport widths less than one are ok since they are real valued
	// dont use ASPECT_RATIO when computing since its ideal aspect between
	// width and height not the actual due to rounding 
	// (width and height are integers)
	viewport_height: f32 = 2.0
	viewport_width := viewport_height * f32(image_width) / f32(image_height)

	// calculate vectors across the horizontal and down the vertical 
	// viewport edges
	viewport_u := Vector3{viewport_width, 0, 0}
	viewport_v := Vector3{0, -viewport_height, 0}
	pixel_delta_u := viewport_u / f32(image_width)
	pixel_delta_v := viewport_v / f32(image_height)
	viewport_upper_left :=
		c.origin - Vector3{0, 0, c.focal_length} - viewport_u / 2 - viewport_v / 2

	// offset by half pixel spacing to center in viewport
	// pixel00_loc is the center point of the top left pixel, why use center 
	// and not top left corner? IDK
	pixel00_loc := viewport_upper_left + 0.5 * (pixel_delta_u + pixel_delta_v)
	return ImageInfo {
		viewport_height = viewport_height,
		viewport_width = viewport_width,
		viewport_u = viewport_u,
		viewport_v = viewport_v,
		pixel_delta_u = pixel_delta_u,
		pixel_delta_v = pixel_delta_v,
		viewport_upper_left = viewport_upper_left,
		pixel00_loc = pixel00_loc,
	}
}


camera_render :: proc(c: ^Camera, world: []^Hittable, image: ImageBuffer) {
	image_width := camera_image_width(c)
	image_height := camera_image_height(c)
	info := image_info_create(c)

	for j := 0; j < image_height; j += 1 {
		fmt.printf("\rScanlines remaining: %d   ", image_height - j)
		os.flush(os.stdout)
		for i := 0; i < image_width; i += 1 {
			pixel_color := Color{}
			for sample in 0 ..< c.samples_per_pixel {
				r := get_ray(c, i, j)
				pixel_color += color_ray(r, c.max_depth, world)
			}

			pixel_color /= f32(c.samples_per_pixel)
			image[i + j * image_width] = pixel_color
		}

	}

	fmt.print("\rDone                     \n")

	color_ray :: proc(r: Ray, depth: int, world: []^Hittable) -> Color {
		if depth <= 0 do return Color{}

		// due to floating imprecision the randomly reflected ray might 
		// be slightly inside the sphere causing the ray to hit the sphere again, 
		// therefore offset the intersection interval slightly
		if rec, hit := hit(world, r, Interval{0.001, INFINITY}); hit {
			if scattered_ray, attenuation, scattered := rec.mat->scatter(r, rec); scattered {
				return attenuation * color_ray(scattered_ray, depth - 1, world)

			} else do return Color{}
		} else {
			// ---background
			normalized_dir := linalg.vector_normalize(r.dir)
			// scale unit dir from -1 < vector < 1 to 0 < vec < 1
			a := 0.5 * (normalized_dir.y + 1)

			// linear interpolation
			// val = (1-a)*startValue + 1*endValue, 0 < a < 1
			return (1 - a) * Color{1, 1, 1} + a * Color{0.5, 0.7, 1}
		}
	}

	get_ray :: proc(cam: ^Camera, i, j: int) -> Ray {
		// construct a camera ray from the camera orgin directed
		// at a randomly sampled point around the pixel location i, j
		offset := sample_square()
		info := image_info_create(cam)
		pixel_sample :=
			info.pixel00_loc +
			((f32(i) + offset.x) * info.pixel_delta_u) +
			((f32(j) + offset.y) * info.pixel_delta_v)

		dir := pixel_sample - cam.origin
		return Ray{origin = cam.origin, dir = dir}

		sample_square :: proc() -> Vector3 {
			// return the vector to a random point in the unit square
			return Vector3{rand.float32() - 0.5, rand.float32() - 0.5, 0}

		}
	}
}
