from collections import deque
from select import select

from src.task cimport Task
from src.future cimport Future
import time

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

    def __init__(self):
        self._ready_queue = deque()
        self._timers = []
        self._running = False

    def create_task(self, object coro):
        cdef Task task = Task(coro, self)
        return task

    cdef void _schedule_task(self, Task task):
        self._ready_queue.append(task)

    cdef Task _get_next_task(self):
        if not self._ready_queue:
            raise IndexError("empty queue")
        return <Task>self._ready_queue.popleft()

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
        while self._running:
            while self._ready_queue:
                task = self._get_next_task()
                if not task._done:
                    task._step()

            self._process_timers()

            if not self._ready_queue and not self._timers:
                break


            timeout = self._get_timeout()
            if timeout > 0:
                select([], [], [], timeout)
        self._running = False