import time

from shustriy_async import EventLoop

def task1():
    yield loop.sleep(1)
    return "A"

def task2():
    yield loop.sleep(0.5)
    return "B"

def main():
    now = time.perf_counter()
    results = yield loop.gather(task1(), task2())
    print(time.perf_counter() - now)
    print(results)

loop = EventLoop()
loop.create_task(main())
loop.run()