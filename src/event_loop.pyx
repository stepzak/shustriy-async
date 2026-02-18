from collections import deque
from select import select

from src.task cimport Task
from src.future cimport Future
import time
import socket
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
    cdef double when
    cdef Future future
    def __init__(self, double when, Future future):
        self.when = when
        self.future = future

cdef class EventLoop:

    cdef object _ready_queue
    cdef list _timers
    cdef bint _running
    cdef dict _sock_readers
    cdef dict _sock_writers

    def __init__(self):
        self._ready_queue = deque()
        self._timers = []
        self._running = False
        self._sock_readers = {}
        self._sock_writers = {}

    def create_task(self, object coro):
        cdef Task task = Task(coro, self)
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
            task = self.create_task(coro)
            task.add_done_callback(lambda t, idx=i, st=state: st.on_task_done(idx, t))

        return gather_fut

    cdef void _register_reader(self, object sock, Future fut):
        self._sock_readers[sock] = fut

    cdef void _register_writer(self, object sock, Future fut):
        self._sock_writers[sock] = fut

    cpdef void _schedule_task(self, Task task):
        self._ready_queue.append(task)

    cdef Task _get_next_task(self):
        if not self._ready_queue:
            raise IndexError("empty queue")
        return <Task>self._ready_queue.popleft()

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
        cdef double when = time.time() + delay
        cdef Future fut = Future()
        self._timers.append(TimerEntry(when, fut))
        return fut

    cdef void _process_timers(self):
        if not self._timers:
            return
        cdef double now = time.time()
        cdef list ready = []
        cdef list remaining = []
        cdef TimerEntry entry
        for entry in self._timers:
            if entry.when <= now:
                ready.append(entry)
            else:
                remaining.append(entry)
        self._timers = remaining
        for entry in ready:
            entry.future.set_result(None)

    cdef double _get_timeout(self):
        if not self._timers:
            return -1.0

        cdef double now = time.time()
        cdef double m = -1
        cdef TimerEntry t_e
        for t_e in self._timers:
            if t_e.when < m or m == -1:
                m = t_e.when

        cdef double diff = m - now
        return diff if diff > 0.0 else 0.0

    def run_until_complete(self, object coro):
        self.create_task(coro)
        self._run()

    def run(self):
        self._run()

    cdef void _run(self):
        self._running = True
        cdef Task task
        cdef list ready_r, ready_w
        cdef object sock
        cdef Future fut
        cdef list rlist
        cdef list wlist

        while self._running:
            while self._ready_queue:
                task = self._get_next_task()
                if task._next_value is not None:
                    value = task._next_value
                    task._next_value = None
                    task._step(value)
                else:
                    task._step()

            self._process_timers()

            if not self._ready_queue and not self._timers and not self._sock_readers and not self._sock_writers:
                break
            rlist = list(self._sock_readers.keys())
            wlist = list(self._sock_writers.keys())

            timeout = self._get_timeout()
            if timeout < 0:
                timeout = 0.0
            if rlist and wlist:
                timeout = None

            ready_r, ready_w, _ = select(rlist, wlist, [], timeout)
            for sock in ready_r:
                fut = self._sock_readers.pop(sock)
                try:
                    if hasattr(sock, 'accept'):
                        client, addr = sock.accept()
                        client.setblocking(False)
                        fut.set_result((client, addr))
                    else:
                        data = sock.recv(65536)
                        fut.set_result(data)
                except BlockingIOError:
                    self._register_reader(sock, fut)
                except Exception as e:
                    fut.set_exception(e)

            for sock in ready_w:
                fut = self._sock_writers.pop(sock)
                try:
                    fut.set_result(None)
                except Exception as e:
                    fut.set_exception(e)

        self._running = False