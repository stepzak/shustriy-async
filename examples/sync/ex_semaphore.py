from shustriy_async import EventLoop, Semaphore

sem = Semaphore(2)

def task(n: int, loop: EventLoop):
    print(f"Task {n} started")
    yield sem.acquire()
    print(f"Task {n} doing smart stuff")
    yield loop.sleep(1)
    print(f"Task {n} done")
    yield sem.release()

def main(loop: EventLoop):
    tasks = [task(i, loop) for i in range(6)]
    yield loop.gather(*tasks)

if __name__ == "__main__":
    loop = EventLoop()
    loop.run_until_complete(main(loop))
