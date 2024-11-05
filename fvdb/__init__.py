"""
fvdb - thin porcelain around FAISS

`fvdb` is a simple, minimal wrapper around the FAISS vector database.
It uses an L2 index with normalised vectors.
"""

import hy
import fvdb.config
from fvdb.db import faiss, ingest, similar, sources, marginal, info, nuke, write

# set the package version
__version__ = "0.1.2"
__version_info__ = __version__.split(".")

