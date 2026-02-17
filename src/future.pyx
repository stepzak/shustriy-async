cdef class Future:

    def __init__(self):
        self._done = False
        self._result = None
        self._cbs = []

    cdef set_result(self, object result):
        if self._done:
            return None

        self._result = result
        self._done = True
        for cb in self._cbs:
            cb(self)
        return None

    cdef _fire_callbacks(self):
        for cb in self._cbs:
            cb(self)

    def done(self):
        return self._done

    def result(self):
        return self._result

    def add_done_callback(self, object callback):
        if self._done:
            callback(self)
        else:
            self._cbs.append(callback)