from src.event_loop import EventLoop

def task1():
    yield loop.sleep(0.2)
    return "A"

def task2():
    yield loop.sleep(0.1)
    return "B"

def main():
    results = yield loop.gather(task1(), task2())
    print("Результаты:", results)

loop = EventLoop()
loop.create_task(main())
loop.run()