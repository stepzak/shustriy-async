from shustriy_async import EventLoop, Event

def consumer(n: int, event: Event):
    print(f"Consumer {n} waiting")
    yield event.wait()
    print(f"Consumer {n} done")

def producer(event: Event, loop: EventLoop):
    yield loop.sleep(1)
    print(f"Producing event...")
    event.set()

def main(loop: EventLoop):
    event = Event()
    tasks = [
        consumer(i, event) for i in range(3)
    ]
    tasks.append(producer(event, loop))
    yield loop.gather(*tasks)

if __name__ == "__main__":
    loop = EventLoop()
    loop.run_until_complete(main(loop))