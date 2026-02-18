cdef class Future:
    cdef bint _done
    cdef object _result
    cdef object _exception
    cdef list _cbs
    cdef void set_result(self, object result)
    cdef void set_exception(self, object result)
    cdef void _fire_callbacks(self)
    cpdef object result(self)
