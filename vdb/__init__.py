"""
vdb - thin porcelain around FAISS

`vdb` is a simple, minimal wrapper around the FAISS vector database.
It uses an L2 index with normalised vectors.
"""

import hy
import vdb.config
from vdb.db import faiss, ingest, similar, sources, marginal, info, nuke, write

# set the package version
__version__ = "0.0.1"
__version_info__ = __version__.split(".")

