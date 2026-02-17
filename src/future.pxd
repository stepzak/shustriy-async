cdef class Future:
    cdef bint _done
    cdef object _result
    cdef list _cbs
    cdef set_result(self, object result)
    cdef _fire_callbacks(self)
    cpdef object result(self)