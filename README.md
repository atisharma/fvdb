# fvdb - thin porcelain around FAISS

`fvdb` is a simple, minimal wrapper around the FAISS vector database.
It uses a L2 index with normalised vectors.

It uses the `faiss-cpu` package and `sentence-transformers` for embeddings.
If you need the GPU version of FAISS (very probably not), you can just manually
install `faiss-gpu` and use `GPUIndexFlatL2` instead of `IndexFlatL2` in `fvdb/db.hy`.

If summaries are enabled (**not** the default, see configuration section
below), a summary of the extract will be stored alongside the extract.


## Features

- similarity search with score
- choice of sentence-transformer embeddings
- useful formatting of results (json, tabulated...)
- cli access
- extract summaries

Any input other than plain text (markdown, asciidoc, rst, source code etc.) is out of scope.
You should one of the many available packages for that (unstructured, trafiltura, docling, etc.)
to convert to plaintext in a separate step.


## Usage

```python
import hy # fvdb is written in Hy, but you can use it from python too
from fvdb import faiss, ingest, similar, sources, write

# data ingestion
v = faiss()
ingest(v, "doc.md")
ingest(v, "docs-dir")
write(v, "/tmp/test.fvdb") # defaults to $XDG_DATA_HOME/fvdb (~/.local/share/fvdb/ on Linux)

# search
results = similar(v, "some query text")
results = marginal(v, "some query text") # not yet implemented

# information, management
sources(v)
    { ...
      'docs-dir/Once More to the Lake.txt',
      'docs-dir/Politics and the English Language.txt',
      'docs-dir/Reflections on Gandhi.txt',
      'docs-dir/Shooting an elephant.txt',
      'docs-dir/The death of the moth.txt',
      ... }

info(v)
    {   'records': 42,
        'embeddings': 42,
        'embedding_dimension': 1024,
        'is_trained': True,
        'path': '/tmp/test-vdb',
        'sources': 24,
        'embedding_model': 'Alibaba-NLP/gte-large-en-v1.5'}

nuke(v)
```

These are also available from the command line.
```bash
$ # defaults to $XDG_DATA_HOME/fvdb (~/.local/share/fvdb/ on Linux)
# data ingestion (saves on exit)
$ fvdb ingest doc.md
    Adding 2 records

$ fvdb ingest docs-dir
    Adding 42 records

$ # search
$ fvdb similar -j "some query text" > results.json   # --json / -j gives json output

$ fvdb similar -r 2 "George Orwell's formative experience as a policeman in colonial Burma"
    # defaults to tabulated output (not all fields will be shown)
       score  source                             added                               page    length
    --------  ---------------------------------- --------------------------------  ------  --------
    0.579925  docs-dir/A hanging.txt             2024-11-05T11:37:26.232773+00:00       0      2582
    0.526988  docs-dir/Shooting an elephant.txt  2024-11-05T11:37:43.891659+00:00       0      3889

$ fvdb marginal "some query text"                       # not yet implemented

$ # information, management
$ fvdb sources
    ...
    docs-dir/Once More to the Lake.txt
    docs-dir/Politics and the English Language.txt
    docs-dir/Reflections on Gandhi.txt
    docs-dir/Shooting an elephant.txt
    docs-dir/The death of the moth.txt
    ...

$ fvdb info
    -------------------  -----------------------------
    records              44
    embeddings           44
    embedding_dimension  1024
    is_trained           True
    path                 /tmp/test
    sources              24
    embedding_model      Alibaba-NLP/gte-large-en-v1.5
    -------------------  -----------------------------

$ fvdb nuke
```

### Configuration

Looks for `$XDG_CONFIG_HOME/fvdb/conf.toml`, otherwise uses defaults.

You cannot mix embeddings models in a single fvdb.

Here is an example.

```toml
# Sets the default path to something other than $XDG_CONFIG_HOME/fvdb/conf.toml
path = "/tmp/test.fvdb"

# Summaries are useful if you use an embedding model with large maximum sequence length,
# for example, gte-large-en-v1.5 has maximum sequence length of 8192.
summary = true		

# A conservative default model, maximum sequence length of 512,
# so no point using summaries.
embeddings.model = "all-mpnet-base-v2"

## Some models need extra options
#embeddings.model = "Alibaba-NLP/gte-large-en-v1.5"
#embeddings.trust_remote_code = true
## You can put some smaller models on a cpu, but larger models will be slow
#embeddings.device = "cpu"
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


## Planned

- optional progress bars for long jobs
