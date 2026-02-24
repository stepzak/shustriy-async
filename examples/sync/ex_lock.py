from shustriy_async import EventLoop, Lock
a = 1
lock = Lock()

def task(loop: EventLoop):
    global a
    print("Task started")
    yield lock.acquire()
    if a==1:
        yield loop.sleep(1)
        a+=1
        print("Success task")
    yield lock.release()
    print("Lock released")

def main(loop: EventLoop):
    yield loop.gather(task(loop), task(loop))

if __name__ == '__main__':
    loop = EventLoop()
    loop.run_until_complete(main(loop))
    print(a)