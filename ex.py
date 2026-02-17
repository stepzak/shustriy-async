from src.event_loop import EventLoop

def child():
    print("Дочерняя задача старт")
    yield loop.sleep(0.2)
    print("Дочерняя задача завершена")
    return "наишустрейший цикл событий"

def parent():
    print("Родительская задача старт")
    child_gen = child()
    child_task = loop.create_task(child_gen)
    result = yield child_task
    print("Результат:", result)

if __name__ == "__main__":
    loop = EventLoop()
    loop.create_task(parent())
    loop.run()