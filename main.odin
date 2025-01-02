package main

import "core:fmt"
import "core:math"
import "core:sync"
import "core:thread"
import "core:time"

import glm "core:math/linalg"
import rng "core:math/rand"
import rl "vendor:raylib"

G: f32 : 9.0e-8

WINDOW_WIDTH :: 1920
WINDOW_HEIGHT :: 1080
WINDOW_FPS :: 60

INIT_BODY_COUNT :: 100
MASS: f32 : 100
RADIUS: f32 : 5

BODY_COLOR: rl.Color : {255, 255, 255, 255}

Body :: struct {
	pos: [2]f32,
	vel: [2]f32,
}

Game :: struct {
	bodies: [dynamic]Body,
	mutex:  sync.Mutex,
}

game: Game
camera: rl.Camera2D

calculate_force :: proc(pos_1, pos_2: [2]f32) -> [2]f32 {

	// find the direction to pos_2 from pos_1
	dir := [2]f32{pos_2.x - pos_1.x, pos_2.y - pos_1.y}

	// normalize the direction to multiply it with the force
	dir_normal := glm.normalize(dir)

	// finds the distance between the two bodies
	dist := glm.distance(pos_1, pos_2)

	// checks to see if the distance is greater than 10 so that we dont get tooo wonky physics
	dist = max(dist, RADIUS)

	// returns the scalar value of the force
	return dir_normal * (G * (MASS * MASS) / math.pow(dist, 2))
}

update :: proc(t: ^thread.Thread) {

	for !rl.WindowShouldClose() {
		sync.lock(&game.mutex)

		for &top_body, top_index in game.bodies {
			for low_body, low_index in game.bodies {
				if top_index == low_index do continue

				force := calculate_force(top_body.pos, low_body.pos)
				top_body.vel += force
			}
			top_body.pos += top_body.vel
		}
		sync.unlock(&game.mutex)
		time.sleep(1 / WINDOW_FPS)
	}
}

main :: proc() {

	rl.SetConfigFlags({.FULLSCREEN_MODE})
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "N Body Simulation");defer rl.CloseWindow()
	rl.SetTargetFPS(WINDOW_FPS)

	camera = rl.Camera2D {
		offset   = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2},
		target   = {0, 0},
		zoom     = 1,
		rotation = 1,
	}

	game.bodies = make([dynamic]Body, 0, INIT_BODY_COUNT)

	defer delete(game.bodies)

	for i in 0 ..< INIT_BODY_COUNT {
		body := Body {
			pos = {
				rng.float32_range(-WINDOW_WIDTH / 2, WINDOW_WIDTH / 2),
				rng.float32_range(-WINDOW_HEIGHT / 2, WINDOW_HEIGHT / 2),
			},
		}
		append(&game.bodies, body)
	}

	update_thread := thread.create(update);defer thread.destroy(update_thread)
	update_thread.init_context = context
	update_thread.user_index = 0
	thread.start(update_thread)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground({20, 20, 20, 255})
		rl.BeginMode2D(camera)
		sync.lock(&game.mutex)

		if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
			mouse_pos := rl.GetMousePosition()
			append(
				&game.bodies,
				Body{pos = {mouse_pos.x - WINDOW_WIDTH / 2, mouse_pos.y - WINDOW_HEIGHT / 2}},
			)
			fmt.println(len(game.bodies))
		}

		for body, index in game.bodies {
			rl.DrawPixel(i32(body.pos.x), i32(body.pos.y), BODY_COLOR)
		}

		rl.DrawFPS(-WINDOW_WIDTH / 2, -WINDOW_HEIGHT / 2 + 20)

		sync.unlock(&game.mutex)
		rl.EndMode2D()
		rl.EndDrawing()
	}
}
