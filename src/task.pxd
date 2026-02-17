from src.future cimport Future

cdef class Task(Future):
    cdef object coro
    cdef bint _done
    cdef object loop
    cdef void _step(self, object value=*) except *
    cdef _on_future_done(self, Future fut)