from collections import deque

from src.future cimport Future

cdef class Lock:
    cdef bint _locked
    cdef object _waiters

    def __init__(self):
        self._locked = False
        self._waiters = deque()

    def acquire(self) -> Future:
        cdef fut = Future()
        if not self._locked:
            self._locked = True
            fut.set_result(None)
        else:
            self._waiters.append(fut)
        return fut

    def release(self):
        if self._waiters:
            fut = <Future>self._waiters.popleft()
            fut.set_result(None)
        else:
            self._locked = False

    def locked(self) -> bool:
        return self._locked

cdef class Semaphore:
    cdef int _busy
    cdef int _max_busy
    cdef object _waiters

    def __init__(self, int n):
        self._busy = 0
        self._max_busy = n
        self._waiters = deque()

    def acquire(self) -> Future:
        cdef fut = Future()
        if self._busy < self._max_busy:
            self._busy += 1
            fut.set_result(None)
        else:
            self._waiters.append(fut)

        return fut

    def release(self):
        if self._waiters:
            fut = self._waiters.popleft()
            fut.set_result(None)
        else:
            self._busy -= 1

cdef class Event:
    cdef bint _flag
    cdef object _waiters

    def __init__(self):
        self._flag = False
        self._waiters = deque()

    def wait(self) -> Future:
        cdef fut = Future()
        if self._flag:
            fut.set_result(None)
        else:
            self._waiters.append(fut)

        return fut

    def set(self):
        self._flag = True
        while self._waiters:
            fut = self._waiters.popleft()
            fut.set_result(None)
