from src.future cimport Future

cdef class Task(Future):
    cdef object coro
    cdef object loop
    cdef object _next_value
    cdef void _step(self, object value=*) except *
    cdef _on_future_done(self, Future fut)