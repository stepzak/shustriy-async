from shustriy_async import EventLoop, Lock
a = 1
lock = Lock()

def task(loop: EventLoop):
    global a
    yield lock.acquire()
    if a==1:
        yield loop.sleep(1)
        a+=1
        print("Success task")
    yield lock.release()
    print("Lock released")

if __name__ == '__main__':
    loop = EventLoop()
    t1 = loop.create_task(task(loop))
    t2 = loop.create_task(task(loop))
    loop.run()
    print(a)