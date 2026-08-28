"""Importing this package registers every mapper.

SQLAlchemy resolves relationship targets by class name at configure time, so
a script that imports only the two models it needs blows up on the first
query with "expression 'Camera' failed to locate a name". Importing the
package first is the cheap fix -- the app itself never hit this because it
loads all the routers, and they collectively import everything.
"""

import importlib
import pkgutil

for _module in pkgutil.iter_modules(__path__):
    importlib.import_module("%s.%s" % (__name__, _module.name))
