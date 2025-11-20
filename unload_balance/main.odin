package main
import bd "./bernoulli_dist"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:slice"
import "core:sync"
import "core:thread"
import "core:time"
import "vendor:raylib"
ChunkSize :: 100
ChunkCount :: 100
LightIter :: 100
HeavyIter :: 1000
ProbHeavyWork :: .05
WorkerCount :: 4
SubSize :: ChunkSize / WorkerCount

Task :: struct {
	val:    f64,
	heavey: bool,
}


process :: proc(is_heavy: bool, task_val: f64) -> f64 {

	iter: int
	if is_heavy {
		iter = HeavyIter
	} else {
		iter = LightIter
	}


	result: f64 = task_val

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
/*
Init_Worker :: proc(worker: ^Worker) {
	worker.dying = false
	worker.accumlation = 0.0
	}*/

Set_Job :: proc(worker: ^Worker, data: []f64) {
	sync.atomic_mutex_lock(&worker.mtx)
	defer sync.atomic_mutex_unlock(&worker.mtx)

	for i := 0; i < len(data); i += 1 {
		worker.input[i].val = data[i]
	}

	sync.atomic_cond_signal(&worker.cv)
}

Kill :: proc(worker: ^Worker) {
	sync.atomic_mutex_lock(&worker.mtx)
	defer sync.atomic_mutex_unlock(&worker.mtx)
	sync.atomic_cond_signal(&worker.cv)

}

Worker_ProcessData :: proc(worker: ^Worker) {
	for task in worker.input {
		worker.accumlation += process(task.heavey, task.val)

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

Accumlate :: proc(arr: [dynamic]^Worker) -> f64 {

	result: f64 = 0
	for i := 0; i < len(arr); i += 1 {
		arr[i].input[i].val = arr[i].input[i].val + arr[i - 1].input[i - 1].val
	}

	result = arr[0].input[0].val

	return result
}

DoTheWork :: proc() -> int {


	tm: time.Stopwatch
	chuncks := generate_data_sets()

	time.stopwatch_start(&tm)


	worker_container := make([dynamic]^Worker, context.temp_allocator)

	for i := 0; i < WorkerCount; i += 1 {
		new_ptr := new(Worker, context.temp_allocator)
		new_ptr.accumlation = 0.0
		new_ptr.dying = false
		new_ptr.master = &mctrl
		append(&worker_container, new_ptr)
		//append(&worker_containe, Worker{dying = false, master = &mctrl, accumlation = 0.0})
	}

	for chunk in chuncks {
		data: []f64
		start: int = 0
		end: int = 25
		for j := 0; j < len(chunk); j += 1 {
			data[j] = chunk[j].val
		}
		for i := 0; i < WorkerCount; i += 1 {
			Set_Job(worker_container[i], data[start:end])
			start = end
			end = end * 2
		}
		M_WaitForAllDone(&mctrl)
	}
	time.stopwatch_stop(&tm)
	fmt.println(" processing took  : ", tm._accumulation)

	fmt.printfln("the outcome : ", Accumlate(worker_container))

	free_all(context.temp_allocator)
	return 0

}


////////////////////////////////////////////////// Worker end //////////////////////////////////////////////////


main :: proc() {
	fmt.println("Hellope!")
}
