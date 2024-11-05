"
This module sets up the embeddings model for the vector database using
sentence-transformers and transformers libraries. It loads the
specified model and its tokenizer, exposes a function to get the
embedding vector for a given text, and provides utility functions for
tokenization and token counting.

Usage example (python):

```python
from llama_farm.embeddings import embed, tokenize, token_count

embedding_vector = embed(\"Hello, Llama Farm!\")
tokens = tokenize(\"This is a sentence.\")
token_cnt = token_count(tokens)
  ```

The sentence-transformers model is specified in the config.toml.

[embeddings]
# The model must be specified, other options will be passed to
# both tokenizer and model.
model = \"all-mpnet-base-v2\"
# some models require to trust remote code
#trust_remote_code = true
```
"

(require hyrule [unless ->])

(import fvdb.config)


(setv default-model "all-mpnet-base-v2")
(setv embedding-model-options (:embeddings fvdb.config.cfg {"model" default-model}))
(setv embedding-model-name (.pop embedding-model-options "model" default-model))

(setv embedding-model None)
(setv tokenizer None)

;; * Functions dealing with embeddings for the vector databases
;; -----------------------------------------------------------------------------

(defn _import-embedding-model []
  "It is large, so delay import until needed."
  (global embedding-model)
  (unless embedding-model
    (import sentence-transformers [SentenceTransformer])
    (setv embedding-model (SentenceTransformer
                            embedding-model-name
                            #** embedding-model-options))))

(defn _import-tokenizer []
  "It is large, so delay import until needed."
  (global tokenizer)
  (unless tokenizer
    (import transformers [AutoTokenizer])
    (setv tokenizer (AutoTokenizer.from-pretrained
                      embedding-model-name
                      #** embedding-model-options))))

(defn tokenize [text #** kwargs]
  "Return the tokenized text."
  (_import-tokenizer)
  (tokenizer.tokenize text #** kwargs))
                      
(defn token-count [x * [tokenizer tokenize]]
  "The number of embedding tokens, roughly, of anything with a meaningful
  string representation. The (transformers) tokenizer defaults to that specified
  for the storage embeddings model."
  (_import-tokenizer)
  (-> x
      (str)
      (tokenizer :padding False)
      (len)))

(defn embed [chunks]
  "Return the embedding vector (normalized)."
  (_import-embedding-model)
  (embedding-model.encode chunks :normalize-embeddings True))

(defn max-length []
  "The maximum length (in tokens) that the embeddings can express."
  (_import-embedding-model)
  embedding-model.max-seq-length)

