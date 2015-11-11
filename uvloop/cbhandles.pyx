@cython.final
@cython.internal
@cython.freelist(100)
cdef class Handle:
    cdef:
        object callback, args
        bint cancelled
        bint done
        Loop loop
        object __weakref__

    def __cinit__(self, Loop loop, object callback, object args):
        self.callback = callback
        self.args = args
        self.cancelled = 0
        self.done = 0
        self.loop = loop

    cdef inline _run(self):
        if self.cancelled == 1 or self.done == 1:
            return

        self.done = 1
        try:
            if self.args is not None:
                self.callback(*self.args)
            else:
                self.callback()
        except Exception as ex:
            self.loop.call_exception_handler({
                'message': 'Exception in callback {}'.format(self.callback),
                'exception': ex
            })

    cdef _cancel(self):
        self.cancelled = 1
        self.callback = None

    # Public API

    def cancel(self):
        self._cancel()


@cython.final
@cython.internal
@cython.freelist(100)
cdef class TimerHandle:
    cdef:
        object callback, args
        bint closed
        UVTimer timer
        Loop loop
        object __weakref__

    def __cinit__(self, Loop loop, object callback, object args,
                  uint64_t delay):

        self.loop = loop
        self.callback = callback
        self.args = args
        self.closed = 0

        self.timer = UVTimer(loop, self._run, delay)
        self.timer.start()

    def __del__(self):
        self._cancel()

    cdef _cancel(self):
        if self.closed == 1:
            return
        self.closed = 1
        self.callback = None
        self.timer.close()

    def _run(self):
        if self.closed == 1:
            return

        callback = self.callback
        self._cancel()

        try:
            if self.args is not None:
                callback(*self.args)
            else:
                callback()
        except Exception as ex:
            self.loop.call_exception_handler({
                'message': 'Exception in callback {}'.format(callback),
                'exception': ex
            })

    # Public API

    def cancel(self):
        self._cancel()