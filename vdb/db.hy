"
A vector database API.

This module provides an API for interacting with a vector database
(vdb) stored in-memory using Faiss and a list of dicts and using
Faiss and pickle for serialization.

Functions are provided for creating, modifying, and searching the
vector database. Ingestion functions support adding documents, files
and text with associated metadata. The `remove_source` function
allows for the removal of all entries associated with a specific
source (e.g. to update a file).

Limited validation and integrity checks may be performed using the
`validate` function, which currently only ensures the number of
records and embeddings match.

Because the vdb is in-memory, and no locks are implemented, this
module is probably not thread-safe. Modify the vdb only from the main
thread. Other threads will have to reload the state after modification.
"

(require hyrule [of -> ->>])
(require hyjinx [defmethod])

(import hyrule [assoc])
(import hyjinx [first count
                pload psave
                hash-id
                mkdir
                now
                is-url])

(import logging)

(import collections.abc [Generator])
(import itertools [chain])
(import os)
(import pathlib [Path])
(import numpy)

(import faiss [IndexFlatL2 IndexFlatIP read-index write-index normalize-L2])

(import vdb.config [cfg])
(import vdb.embeddings [embed embedding-model-name])
(import vdb.split [split chunk-markdown])


;; * Functions to create, persist or destroy the vector database
;;   See https://github.com/matsui528/faiss_tips for useful possibilities
;; -----------------------------------------------------------------------------

(defn faiss [[path (:path cfg)]]
  "A persistent faiss vector database.
  'vectors' is a faiss IndexFlatL2 object.
  'records' is a (pickled) list of records (each a dict):
    [{hash chunk embedding #** metadata} ... ]."
  ;;
  ;; For special operations on an underlying faiss index, see
  ;; https://github.com/facebookresearch/faiss/wiki/Special-operations-on-indexes
  ;;
  ;; The faiss vector index indexes on position, so removing an entry shifts the
  ;; index of following items by -1.
  ;; Care has to be taken to keep vectors and records in sync, especially when deleting.
  ;;
  ;; If the records get very large, or you need to query them directly, consider duckdb.
  ;;
  (if (and (.is-dir (Path path embedding-model-name))
           (.is-file (Path path embedding-model-name "vector_index.faiss"))
           (.is-file (Path path embedding-model-name "records.pkl")))
    {"vectors" (read-index (str (Path path embedding-model-name "vector_index.faiss")))
     "records" (pload (Path path embedding-model-name "records.pkl"))
     "model" embedding-model-name
     "path" path
     "dirty" False}
    (let [dim (len (embed "this gets the embedding dimension"))]
      {"vectors" (IndexFlatL2 dim) ; flat index needs no training
       "records" []
       "model" embedding-model-name
       "path" path
       "dirty" False})))

(defn write [#^ dict vdb * [path None]]
  "Write the vector and document indices to disk."
  ;; TODO rebalance / optimize index before saving
  (let [path (Path (or path (:path vdb)) embedding-model-name)]
    (mkdir path)
    (if (.is-dir path)
        (do
          (write-index (:vectors vdb) (str (Path path "vector_index.faiss")))
          (psave (:records vdb) (Path path "records.pkl")))
        (raise (FileNotFoundError f"Writing vdb to path {(:path vdb)} failed - is it a directory?")))))

(defn nuke [#^ dict vdb]
  "Remove all records (in-place) from the vector index and records."
  (.clear (:records vdb))
  (.reset (:vectors vdb))
  (assoc vdb "dirty" True))
  
;; * Functions to modify the vector databases (add, delete)
;; -----------------------------------------------------------------------------

(defn info [#^ dict vdb]
  "Some statistics on the vector db."
  (let [recs (:records vdb)
        vecs (:vectors vdb)]
    {"records" (len recs)
     "embeddings" vecs.ntotal
     "embedding_dimension" vecs.d
     "is_trained" vecs.is-trained
     "path" (:path vdb)
     "sources" (len (sources vdb))
     "embedding_model" (:model vdb)}))
  
(defn sources [#^ dict vdb]
  "The set of sources in the vdb."
  (sfor r (:records vdb) (:source r)))

(defn validate [#^ dict vdb]
  "Check that there are the same number of records."
  ;; TODO data integrity:
  ;;      compare embeddings / cosine similarity of each element?
  (let [recs (:records vdb)
        vecs (:vectors vdb)]
    (assert (= (len recs) vecs.ntotal))))
  
(defmethod ingest [#^ dict vdb #^ (| (of list dict) Generator chain) docs]
  "Ingest a list of (document) dicts into the vector db.
  Expects for each dict at least:
    `{extract embedding hash-id #** metadata}`
  and an `error` key for those that failed and should be skipped.
  The hash of each chunk is used as an index id, since the id must be unique.
  This means it's almost impossible to duplicate document content with this hashing scheme."
  (let [;; Create a temporary dict for just selecting new entries, key is hash.
        records-map (dfor d docs
                      :if (not (:error d None))
                      (:hash d) d)
        ;; Only insert records that aren't already in the db.
        ;; The new hashes are all hashes (the keys) less the ones already in the vdb.
        vdb-hashes (sfor record (:records vdb) (:hash record))
        new-hashes (list (.difference (set (.keys records-map)) vdb-hashes))
        ;; The new records contain the embeddings associated with those new hashes.
        ;; Pop them, because we don't want them in the metadata.
        new-embeddings (lfor h new-hashes (.pop (get records-map h) "embedding"))
        new-records (lfor h new-hashes (get records-map h))]
    ;; we are now ready to add
    (when new-hashes
      (let [findex (:vectors vdb)
            records (:records vdb)
            vs (numpy.array new-embeddings :dtype numpy.float32)]
        ;; Add (in-place) the new embeddings (n x dim) to the vector index
        (normalize-L2 vs) ; works in-place
        (findex.add vs) ; works in-place
        ;; Add (in-place) the new records to the records list
        (records.extend new-records)
        ;; Add the new records to the chunk index and return the new vdb.
        ;; Remember to write to disk!
        (assoc vdb "dirty" True)))
    ;; Return (a copy of) the subset, if any, that was added as a doc
    {"n_records_added" (len new-records)}))

(defmethod ingest [#^ dict vdb #^ str fname-or-directory]
  "Ingests a file, or files under a directory."
  (ingest vdb (split fname-or-directory)))

(defn ingest-markdown [#^ dict vdb #^ str markdown-text * [source-type "text"] [source "anon"]] 
  "Ingest markdown text. Can be composed with various sources."
  (let [chunks (chunk-markdown markdown-text)]
    (ingest-doc vdb {"type" source-type
                     "source" source
                     "added" (sources.now)
                     "chunks" chunks
                     "embeddings" (embed chunks)})))

(defn ingest-chat [#^ dict vdb #^ (of list dict) chat-history]
  "Add a chat history to the vdb."
  (raise NotImplementedError))

(defn remove-source [#^ dict vdb #^ str source]
  "Remove all entries that match a source.
  This function modifies the vector index in-place."
  (let [records (:records vdb)
        vectors (:vectors vdb)
        ixs (gfor [ix record] (enumerate records)
                  :if (= source (:source record))
                  ix)]
        ;; FIXME  this index doesn't implement delete!!
        ;;        so we are overwriting the whole index.
    (assoc vdb
           "vectors" (.delete vectors (numpy.fromiter ixs :dtype numpy.int64))
           "records" (lfor record records
                           :if (!= source (:source record))
                           record)
           "path" (:path vdb)
           "dirty" True)))

;; * Search
;; -----------------------------------------------------------------------------

(defn _prepare-queries [#^ (| str (of list str)) queries]
  "Ensure query embeddings are matrix-shaped."
  (if (isinstance queries str)
      (numpy.array [(embed queries)] :dtype numpy.float32)
      (numpy.array (embed queries) :dtype numpy.float32)))
  
(defmethod similar [#^ dict vdb #^ str query #** kwargs]
  "Similarity search on query or list of queries.
  Returns list of results."
  (first (similar vdb [query] #** kwargs)))

(defmethod similar [#^ dict vdb #^ (of list str) queries * [top 6]]
  "Similarity search on list of queries.
  Returns list of lists of results (one list per query)."
  (let [v-index (:vectors vdb)
        records (:records vdb)
        [scores ixs] (.search v-index (_prepare-queries queries) top)]
    (lfor [kth-scores kth-ixs] (zip scores ixs)
          (list
            (reversed
              (lfor [score ix] (zip kth-scores kth-ixs)
                    ; return type should be json serializable
                    {"score" (float score)
                     "index" (int ix)
                     #** (get records ix)}))))))

(defn _margin? [])
  ;; let score be cosine similarity to query then subtract out projection on preceding vectors

(defn marginal [#^ dict vdb query [k 4]]
  "Marginal relevance query.
  Each successive in in the lower-dimensional manifold of vectors where the
  components of the previous results are zero."
  ;; let query embedding be e,
  ;; and r_i be ith result embedding, then
  ;; query on (e - r_i (r_i'e))
  (raise NotImplementedError)
  (let [results []]
    (for [n (range k)]
      (let [result (first (first (similar vdb query :results 1)))
            e (:embedding result)]
            
        (.append results)))))
