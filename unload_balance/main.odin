package main
import bd "./bernoulli_dist"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:slice"
import "core:sync"
import "core:thread"
import "vendor:raylib"

ChunkSize :: 100
ChunkCount :: 100
LightIter :: 100
HeavyIter :: 1000
ProbHeavyWork :: .05


Task :: struct {
	val:    f64,
	heavey: bool,
}


process :: proc(task: ^Task) -> f64 {

	iter: int
	if task.heavey {
		iter = HeavyIter
	} else {
		iter = LightIter
	}


	result: f64 = task.val

	for i in 0 ..< iter {
		result = math.sin(math.cos(result))
	}

	return result
}

generate_data_sets :: proc() -> [4][ChunkSize]Task {


	chunks: [4][ChunkSize]Task

	for outer in 0 ..< 4 {
		for inner in 0 ..< ChunkSize {
			v_dist := rand.float64_uniform(-1, 1)
			h_dist := bd.Generate(0.2)
			chunks[outer][inner] = Task {
				val    = v_dist,
				heavey = h_dist,
			}
		}

	}

	return chunks
}


Master_thread :: struct {
	cv:           sync.Atomic_Cond,
	mtx:          sync.Atomic_Mutex,
	done_count:   int,
	worker_count: int,
}

Master_Init :: proc(mt: ^Master_thread, workers: int) {

	mt.done_count = 0
	mt.worker_count = workers
}

M_DoneFlag :: proc(mt: ^Master_thread) {

	notification: bool = false

	sync.atomic_mutex_lock(&mt.mtx)
	defer sync.atomic_mutex_unlock(&mt.mtx)

	mt.done_count = +1

	if mt.done_count == mt.worker_count {
		//sync.atomic_cond_signal(&mt.cv)
		notification = true
	}

	if notification {
		sync.atomic_cond_signal(&mt.cv)
	}
}

M_WaitForAllDone :: proc(mt: ^Master_thread) {
	sync.atomic_mutex_lock(&mt.mtx)
	defer sync.atomic_mutex_lock(&mt.mtx)

	for (mt.done_count != mt.worker_count) {
		sync.atomic_cond_wait(&mt.cv, &mt.mtx)
		mt.done_count = 0
	}
}

////////////////////////////////////////////////// Worker start //////////////////////////////////////////////////
Worker :: struct {
	master:      ^Master_thread,
	thread:      thread.Thread,
	mtx:         sync.Atomic_Mutex,
	cv:          sync.Atomic_Cond,
	dying:       bool,
	accumlation: f64,
	input:       []Task,
}

Init_Worker :: proc(worker: ^Worker) {
	worker.dying = false
	worker.accumlation = 0.0
}

Set_Job :: proc(worker: ^Worker, data: []int) {
	sync.atomic_mutex_lock(&worker.mtx)
	defer sync.atomic_mutex_unlock(&worker.mtx)
	worker.input = data
	sync.atomic_cond_signal(&worker.cv)
}

Kill :: proc(worker: ^Worker) {
	sync.atomic_mutex_lock(&worker.mtx)
	defer sync.atomic_mutex_unlock(&worker.mtx)
	sync.atomic_cond_signal(&worker.cv)

}

Worker_ProcessData :: proc(worker: ^Worker) {
	for task in worker.input {
		worker.accumlation += process(worker.input[])
	}
}

Run_Worker :: proc(worker: ^Worker) {
	sync.atomic_mutex_lock(&worker.mtx)
	defer sync.atomic_mutex_unlock(&worker.mtx)
	for (true) {
		for (slice.is_empty(worker.input) || worker.dying) {

			if (worker.dying) {
				break
			}

		}
	}

}


////////////////////////////////////////////////// Worker end //////////////////////////////////////////////////


main :: proc() {
	fmt.println("Hellope!")
}
