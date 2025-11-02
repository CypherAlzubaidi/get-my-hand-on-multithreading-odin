package bernoulli_dist
import "core:fmt"
import "core:math/rand"
Generate :: proc(p: f32) -> bool {

	if rand.float32() < p {
		return true
	}
	return false

}
