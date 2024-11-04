# fvdb - thin porcelain around FAISS

`fvdb` is a simple, minimal wrapper around the FAISS vector database.
It uses a L2 index with normalised vectors.

It uses the `faiss-cpu` package and `sentence-transformers` for embeddings.
If you need the GPU version of FAISS (very probably not), you can just manually
install `faiss-gpu` and use `GPUIndexFlatL2` instead of `IndexFlatL2` in `fvdb/db.hy`.


## Features

- similarity search with score
- choice of sentence-transformer embeddings
- useful formatting of results (json, tabulated...)
- cli access

Any input other than plain text (markdown, asciidoc, rst etc) is out of scope.
You should one of the many available packages for that (unstructured, trafiltura, docling, etc.)


## Usage

```python
import hy # fvdb is written in Hy, but you can use it from python too
from fvdb import faiss, ingest, similar, sources, write

# data ingestion
v = faiss()
ingest(v, "docs.md")
ingest(v, "docs-dir")
write(v, "/tmp/test.fvdb") # defaults to $XDG_DATA_HOME/fvdb (~/.local/share/fvdb/ on Linux)

# search
similar(v, "some query text")
marginal(v, "some query text") # not yet implemented

# information, management
sources(v)
info(v)
nuke(v)
```

```bash
$ # defaults to $XDG_DATA_HOME/fvdb (~/.local/share/fvdb/ on Linux)
# data ingestion (saves on exit)
$ fvdb ingest doc.md
$ fvdb ingest docs-dir

$ # search
$ fvdb similarity "some query text"        # default to json output
$ fvdb similarity -t "some query text" # --table / -t gives tabulated output
$ fvdb marginal "some query text" # not yet implemented

$ # information, management
$ fvdb sources
$ fvdb info
$ fvdb nuke
```

### Configuration

Looks for `$XDG_CONFIG_HOME/fvdb/conf.toml`, otherwise uses defaults.

Here is an example.

```toml
path = "/tmp/test.fvdb"

# You cannot mix embeddings models in a single fvdb
embeddings.model = "all-mpnet-base-v2" # conservative default

# some models need extra options
#embeddings.model = "Alibaba-NLP/gte-large-en-v1.5"
#embeddings.trust_remote_code = true
```


## Installation

First [install pytorch](https://pytorch.org/get-started/locally/), which is used by `sentence-transformers`.
You must decide if you want the CPU or CUDA (nvidia GPU) version of pytorch.
For just text embeddings for `fvdb`, CPU is sufficient.

Then,
```bash
pip install fvdb
```
and that's it.
