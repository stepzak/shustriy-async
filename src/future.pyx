cdef class Future:

    def __init__(self):
        self._done = False
        self._result = None
        self._exception = None
        self._cbs = []

    cdef void set_result(self, object result):
        if self._done:
            return
        self._done = True
        self._result = result
        self._fire_callbacks()

    cdef void set_exception(self, object exception):
        if self._done:
            return
        if not isinstance(exception, BaseException):
            raise TypeError("Exception expected")
        self._done = True
        self._exception = exception
        self._fire_callbacks()

    cdef void _fire_callbacks(self):
        for cb in self._cbs:
            cb(self)

    def done(self):
        return self._done

    cpdef object result(self):
        if not self._done:
            raise RuntimeError("Future not done")
        if self._exception is not None:
            raise self._exception
        return self._result

    def add_done_callback(self, object callback):
        if self._done:
            callback(self)
        else:
            self._cbs.append(callback)