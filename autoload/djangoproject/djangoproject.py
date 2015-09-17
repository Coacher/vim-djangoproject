class DjangoProjectPlugin(object):
    __slots__ = ('prev_sys_path', 'prev_py_path',)

    def __init__(self):
        for attr in self.__slots__:
            setattr(self, attr, None)

    def activate(self, directory, settings, update_pythonpath=True,
                 import_settings=False):
        import os
        import sys

        os.environ['DJANGO_SETTINGS_MODULE'] = settings

        self.prev_sys_path = list(sys.path)
        self.prev_py_path = os.environ.get('PYTHONPATH', None)

        pardir = os.path.normpath(os.path.join(directory, os.pardir))

        for path in (pardir, directory):
            if path not in self.prev_sys_path:
                sys.path.append(path)

                if update_pythonpath:
                    py_path = os.environ.get('PYTHONPATH', None)
                    os.environ['PYTHONPATH'] = \
                        os.pathsep.join((py_path, path)) if py_path else path

        if not import_settings:
            return

        import django
        from django.conf import settings

        if django.get_version() >= '1.7':
            django.setup()
        elif not settings.configured:
            settings._setup()

    def deactivate(self):
        import os
        import sys

        sys.path[:] = self.prev_sys_path

        if self.prev_py_path is not None:
            os.environ['PYTHONPATH'] = self.prev_py_path
        else:
            os.environ.pop('PYTHONPATH', None)

        os.environ.pop('DJANGO_SETTINGS_MODULE', None)


DjangoProjectPlugin = DjangoProjectPlugin()
