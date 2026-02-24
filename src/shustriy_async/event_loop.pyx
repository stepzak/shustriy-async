import selectors
from collections import deque
import heapq
from .task cimport Task
from .future cimport Future
import socket
from cpython.time cimport PyTime_TimeRaw, PyTime_AsSecondsDouble

cdef double monotonic_seconds():
    return PyTime_AsSecondsDouble(PyTime_TimeRaw())

sock = socket.socket()
sock.setblocking(False)

cdef class _GatherState:
    cdef int total
    cdef int completed
    cdef list results
    cdef Future gather_fut

    def __init__(self, int total, Future gather_fut):
        self.total = total
        self.completed = 0
        self.results = [None] * total
        self.gather_fut = gather_fut

    def on_task_done(self, int index, Task task):
        self.results[index] = task.result()
        self.completed += 1
        if self.completed == self.total:
            self.gather_fut.set_result(self.results)

cdef class TimerEntry:
    cdef public double when
    cdef public Future future
    def __init__(self, double when, Future future):
        self.when = when
        self.future = future

    def __richcmp__(self, other, int op):
        if op == 0:
            return self.when < other.when
        elif op == 2:
            return self.when == other.when
        elif op == 4:
            return self.when > other.when
        return False

cdef class EventLoop:
    cdef object _ready_queue
    cdef list _timers
    cdef bint _running
    cdef object _selector
    cdef object _thread_pool

    def __init__(self):
        self._ready_queue = deque()
        self._timers = []
        self._running = False
        self._selector = selectors.DefaultSelector()

    def create_task(self, object coro, bool schedule = False):
        cdef Task task = Task(coro, self, schedule)
        return task

    def gather(self, *coros):
        if not coros:
            fut = Future()
            fut.set_result([])
            return fut

        cdef int total = len(coros)
        cdef Future gather_fut = Future()
        cdef _GatherState state = _GatherState(total, gather_fut)

        for i, coro in enumerate(coros):
            task = self.create_task(coro, True)
            task.add_done_callback(lambda t, idx=i, st=state: st.on_task_done(idx, t))

        return gather_fut

    cdef void _register_reader(self, object sock, Future fut):
        self._selector.register(sock, selectors.EVENT_READ, ("read", fut))

    cdef void _register_writer(self, object sock, Future fut):
        self._selector.register(sock, selectors.EVENT_WRITE, ("write", fut))

    cpdef void schedule_task(self, Task task):
        self._ready_queue.append(task)

    cdef void _unregister(self, object sock):
        self._selector.unregister(sock)

    cdef Task _get_next_task(self):
        if not self._ready_queue:
            raise IndexError("empty queue")
        return <Task> self._ready_queue.popleft()

    def sock_accept(self, object server_sock):
        cdef Future fut = Future()
        try:
            client, addr = server_sock.accept()
            client.setblocking(False)
            fut.set_result((client, addr))
        except BlockingIOError:
            self._register_reader(server_sock, fut)
        return fut

    def sock_send(self, object sock, object data):
        cdef Future fut = Future()
        try:
            sent = sock.send(data)
            fut.set_result(sent)
        except BlockingIOError:
            self._register_writer(sock, fut)
        return fut

    def sock_recv(self, object sock, int b):
        cdef Future fut = Future()
        try:
            data = sock.recv(b)
            fut.set_result(data)
        except BlockingIOError:
            self._register_reader(sock, fut)
        return fut

    def sock_recv_static(self, object sock, object buffer_view):
        cdef Future fut = Future()
        try:
            n = sock.recv_into(buffer_view)
            fut.set_result(n)
        except BlockingIOError:
            self._register_reader(sock, fut)
        return fut

    def sleep(self, double delay):
        cdef double when = monotonic_seconds() + delay
        cdef Future fut = Future()
        cdef TimerEntry entry = TimerEntry(when, fut)
        heapq.heappush(self._timers, entry)
        return fut

    cdef void _process_timers(self):
        if not self._timers:
            return
        cdef double now = monotonic_seconds()
        cdef TimerEntry entry
        while self._timers and self._timers[0].when <= now:
            entry = heapq.heappop(self._timers)
            entry.future.set_result(None)

    cdef double _get_timeout(self):
        if not self._timers:
            return -1.0

        cdef double now = monotonic_seconds()
        cdef double m = -1
        cdef TimerEntry t_e
        cdef double next_time = self._timers[0].when
        cdef double diff = next_time - now
        return diff if diff > 0.0 else 0.0

    def run_until_complete(self, object coro):
        self.create_task(coro, True)
        self._run()

    def run(self):
        self._run()

    cdef void _run(self):
        self._running = True
        cdef Task task
        cdef list ready_r, ready_w
        cdef object sock
        cdef Future fut

        while self._running:
            while self._ready_queue:
                task = self._get_next_task()
                if task.next_value is not None:
                    value = task.next_value
                    task.next_value = None
                    task.step(value)
                else:
                    task.step()

            self._process_timers()
            if self._ready_queue:
                continue

            if not self._ready_queue and not self._timers and len(self._selector.get_map()) == 0:
                break

            timeout = self._get_timeout()
            if timeout < 0:
                timeout = 0
            events = self._selector.select(timeout)
            for key, mask in events:
                sock = key.fileobj
                kind, fut = key.data
                self._selector.unregister(sock)

                try:
                    if mask & selectors.EVENT_READ:
                        if hasattr(sock, 'accept'):
                            client, addr = sock.accept()
                            client.setblocking(False)
                            fut.set_result((client, addr))
                        else:
                            data = sock.recv(65536)
                            if not data:
                                fut.set_exception(ConnectionResetError("Client disconnected"))
                            else:
                                fut.set_result(data)
                    elif mask & selectors.EVENT_WRITE:
                        fut.set_result(None)
                except Exception as e:
                    fut.set_exception(e)

        self._running = False
