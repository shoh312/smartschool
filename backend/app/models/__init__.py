
import importlib
import pkgutil

for _module in pkgutil.iter_modules(__path__):
    importlib.import_module("%s.%s" % (__name__, _module.name))
