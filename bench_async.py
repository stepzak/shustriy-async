import asyncio
import time

async def make_task_async(name, steps):
    for _ in range(steps):
        await asyncio.sleep(0)

async def run_asyncio_loop(num_tasks, steps_per_task):
    tasks = []
    for i in range(num_tasks):
        tasks.append(make_task_async(f"Task-{i}", steps_per_task))
    await asyncio.gather(*tasks)

def benchmark_asyncio(num_tasks, steps):
    start = time.perf_counter()
    asyncio.run(run_asyncio_loop(num_tasks, steps))
    end = time.perf_counter()
    return end - start

if __name__ == "__main__":
    num_tasks = 10_000
    steps = 10

    duration = benchmark_asyncio(num_tasks, steps)
    total_ops = num_tasks * steps
    print(f"Asyncio: {num_tasks} задач × {steps} шагов = {total_ops} операций")
    print(f"Время: {duration:.4f} сек")
    print(f"Операций/сек: {total_ops / duration:.0f}")