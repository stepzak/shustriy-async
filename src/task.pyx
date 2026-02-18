from src.future cimport Future

cdef class Task(Future):

    def __init__(self, object coro, object loop):
        Future.__init__(self)
        self.coro = coro
        self._done = False
        self.loop = loop
        self._next_value = None
        self.loop._schedule_task(self)

    cdef void _step(self, object value=None) except *:
        if self._done:
            return
        try:
            future = self.coro.send(value)
            if isinstance(future, Future):
                future.add_done_callback(self._on_future_done)
            else:
                self._step(future)
        except StopIteration as e:
            self._done = True
            self._result = e.value if e.value is not None else None
            self._fire_callbacks()

        except Exception as e:
            self._done = True
            self._exception = e
            self._fire_callbacks()

    def result(self):
        if not self._done:
            raise RuntimeError("Fgdhfjgd fbhndj")
        return self._result

    def done(self):
        return self._done

    cdef _on_future_done(self, Future fut) except*:
        try:
            self._next_value = fut.result()
            self.loop._schedule_task(self)
        except Exception as e:
            self._done = True
            self._exception = e
            self._fire_callbacks()

