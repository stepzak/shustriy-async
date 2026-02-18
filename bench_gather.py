# benchmark.py
import time
import asyncio
from src.event_loop import EventLoop

# --- Ваш loop ---
def make_my_task(delay, loop):
    def coro():
        yield loop.sleep(delay)
        return 42

    return coro()


def benchmark_my_loop(num_tasks, delay):
    loop = EventLoop()
    coros = [make_my_task(delay, loop) for _ in range(num_tasks)]

    def main():
        results = yield loop.gather(*coros)
        return results

    start = time.perf_counter()
    loop.run_until_complete(main())
    end = time.perf_counter()
    return end - start


# --- Asyncio ---
async def make_async_task(delay):
    await asyncio.sleep(delay)
    return 42


async def benchmark_asyncio(num_tasks, delay):
    tasks = [make_async_task(delay) for _ in range(num_tasks)]
    start = time.perf_counter()
    await asyncio.gather(*tasks)
    end = time.perf_counter()
    return end - start


def run_asyncio(num_tasks, delay):
    return asyncio.run(benchmark_asyncio(num_tasks, delay))


# --- Запуск ---
if __name__ == "__main__":
    num_tasks = 10_000_0
    delay = 0.0001

    print("Запуск бенчмарка...")

    # Ваш loop
    my_time = benchmark_my_loop(num_tasks, delay)

    # Asyncio
    asyncio_time = run_asyncio(num_tasks, delay)

    print("\nРезультаты:")
    print(f"My loop:   {my_time:.4f} сек({num_tasks/my_time:.4f} t/sec)")
    print(f"Asyncio:   {asyncio_time:.4f}({num_tasks/asyncio_time:.4f} t/sec)")
    print(f"Разница:   {abs(my_time - asyncio_time):.4f} сек")
    if my_time < asyncio_time:
        print(f"Мой loop быстрее в {asyncio_time / my_time:.2f} раз")
    else:
        print(f"Asyncio быстрее в {my_time / asyncio_time:.2f} раз")