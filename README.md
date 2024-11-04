# vdb - thin porcelain around FAISS

`vdb` is a simple, minimal wrapper around the FAISS vector database.
It uses a L2 index with normalised vectors.

It uses the `faiss-cpu` package and `sentence-transformers` for embeddings.
If you need the GPU version of FAISS (very probably not), you can just manually
install `faiss-gpu` and use `GPUIndexFlatL2` instead of `IndexFlatL2` in `vdb/db.hy`.


## Features

- similarity search with score
- choice of sentence-transformer embeddings
- useful formatting of results (json, tabulated...)
- cli access

Any input other than plain text (markdown, asciidoc, rst etc) is out of scope.
You should one of the many available packages for that (unstructured, trafiltura, docling, etc.)


## Usage

```python
import hy # vdb is written in Hy, but you can use it from python too
from vdb import faiss, ingest, similarity, sources, write

# data ingestion
v = faiss()
vdb.ingest(v, "docs.md")
vdb.ingest(v, "docs-dir")
vdb.write(v, "/tmp/test.vdb") # defaults to $XDG_DATA_HOME/vdb (~/.local/share/vdb/ on Linux)

# search
vdb.similarity(v, "some query text")
vdb.marginal(v, "some query text") # not yet implemented

# information, management
vdb.sources(v)
vdb.info(v)
vdb.nuke(v)
```

```bash
$ # defaults to $XDG_DATA_HOME/vdb (~/.local/share/vdb/ on Linux)
# data ingestion (saves on exit)
$ vdb ingest doc.md
$ vdb ingest docs-dir

$ # search
$ vdb similarity "some query text"        # default to json output
$ vdb similarity -t "some query text" # --table / -t gives tabulated output
$ vdb marginal "some query text" # not yet implemented

$ # information, management
$ vdb sources
$ vdb info
$ vdb nuke
```

### Configuration

Looks for `$XDG_CONFIG_HOME/vdb/conf.toml`, otherwise uses defaults.

Here is an example.

```toml
path = "/tmp/test.vdb"

# You cannot mix embeddings models in a single vdb
embeddings.model = "all-mpnet-base-v2" # conservative default

# some models need extra options
#embeddings.model = "Alibaba-NLP/gte-large-en-v1.5"
#embeddings.trust_remote_code = true
```


## Installation

First [install pytorch](https://pytorch.org/get-started/locally/), which is used by `sentence-transformers`.
You must decide if you want the CPU or CUDA (nvidia GPU) version of pytorch.
For just text embeddings for `vdb`, CPU is sufficient.

Then,
```bash
pip install vdb
```
and that's it.
