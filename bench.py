import time
from src.event_loop import EventLoop

def make_task(name, steps, loop):
    def coro():
        for i in range(steps):
            yield loop.sleep(0)
    return coro()

def run_my_loop(num_tasks, steps_per_task):
    loop = EventLoop()
    start = time.perf_counter()

    for i in range(num_tasks):
        gen = make_task(f"Task-{i}", steps_per_task, loop)
        loop.create_task(gen)

    loop.run()

    end = time.perf_counter()
    return end - start

if __name__ == "__main__":
    num_tasks = 10_000
    steps = 10

    duration = run_my_loop(num_tasks, steps)
    total_ops = num_tasks * steps
    print(f"Мой loop: {num_tasks} задач × {steps} шагов = {total_ops} операций")
    print(f"Время: {duration:.4f} сек")
    print(f"Операций/сек: {total_ops / duration:.0f}")