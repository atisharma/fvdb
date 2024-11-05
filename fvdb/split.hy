"
Convert, then split files and text documents on sensible boundaries
into chunks for processing.

This module provides a collection of functions to divide text or files
into searchable chunks (chunk-*). These may then be placed into
a document data structure suitable for insertion into a vector
database (see fvdb.hy) for later retrieval.

Multiple file types are supported, including text, HTML, markdown,
JSON, and various programming languages. Functions are also available
to process directory paths and chat histories (split-*).

The main functionality involves identifying suitable 'separators' for
dividing text into chunks. These separators are determined based on
the MIME type or file extension, with specific separators defined for
various programming languages and markup formats.

The split-file function returns a list of dicts (documents).
The split-dir and split functions return a generator of documents.

There are three main data structures to understand:

* document: {#** metadata, extract, embedding}
* text: a string to be split.

Non-plaintext formats are not supported here, because there is a plethora of
specialised tools for that purpose already, and the best choice of tool changes
often. It is better to process them separately and then process the resulting
text files. See unstructured, trafiltura, docling, etc.
"

(require hyrule [of unless -> ->>]) 
(require hyjinx [rest lmap])

(import hyjinx [first last second
                flatten chain
                hash-id now
                filenames filetype
                mkdir
                slurp])


(import os)
(import re)
(import magic)
(import json)
(import pathlib [Path])

(import markdownify [markdownify])

(import fvdb.config)
(import fvdb.embeddings [max-length token-count embed])


;; TODO : consider CLIP to encode images?


;; Conditional import
(setv summary (:summary fvdb.config.cfg False))
(when summary
  (import fvdb.summaries [extractive-summary]))


;; * High-level convenience functions
;; ----------------------------------------------------

(defn separators-by-extension [ext]
  "Return the separators on which we split strings, associated with the file extension."
  ;; see https://github.com/langchain-ai/langchain/blob/master/libs/text-splitters/langchain_text_splitters/character.py#L120
  (let [paras ["\n\n\n" "\n\n" "\n" "\t" " " ""]]
    (match ext
           ;; programming languages
           "c" (separators-by-extension "cpp")
           "c++" (separators-by-extension "cpp")
           "cpp" ["\nclass " "\nvoid "
                  "\nint " "\nfloat " "\ndouble "
                  "\nif " "\nfor " "\nwhile " "\nswitch " "\ncase "
                  #* paras]
           "go" ["\nfunc " "\nvar " "\nconst " "\ntype " "\nif " "\nfor " "\nswitch " "\ncase " #* paras]
           "hs" ["\nmain :: " "\nmain = " "\nlet " "\nin " "\ndo " "\nwhere " "\n:: " "\n= "
                 "\ndata " "\nnewtype " "\ntype " "\n:: "
                 "\nmodule " "\nimport " "\nqualified " "\nimport qualified "
                 "\nclass " "\ninstance " "\ncase " "\n| "
                 "\ndata " "\n= {" "\n, "
                 #* paras]
           "hsc" (separators-by-extension "hs")
           "java" ["\nclass " "\npublic " "\nprotected " "\nprivate " "\nstatic "
                   "\nif " "\nfor " "\nwhile " "\nswitch " "\ncase "
                   #* paras]
           "jl" ["\nfunction " "\nconst " "\nmacro " "\nstruct " #* paras]
           "js" ["\nfunction " "\nconst " "\nlet " "\nvar " "\nclass "
                 "\nif " "\nfor " "\nwhile " "\nswitch " "\ncase "
                 "\ndefault " #* paras]
           "lua" ["\nlocal " "\nfunction " "\nif " "\nfor " "\nwhile " "\nrepeat " #* paras]
           "php" ["\nfunction " "\nclass "
                  "\nif " "\nforeach " "\nwhile " "\ndo " "\nswitch " "\ncase "
                  #* paras]
           "py" ["\nclass " "\ndef " "\n\tdef " #* paras]
           "rb" ["\ndef " "\nclass " "\nif " "\nunless " "\nwhile " "\nfor " "\ndo " "\nbegin " "\nrescue " #* paras]
           "sh" [r"\n[::alphanum::_ ]+\(" "for " "if " #* paras]
           "sql" ["\n\n\n--" "\nSELECT " "\nUPDATE " "\nDELETE " "\nINSERT " "\nCREATE " "\nALTER " "\nDROP "
                  "\nselect " "\nupdate " "\ndelete " "\ninsert " "\ncreate " "\nalter " "\ndrop "
                  #* paras]

           ;; * lisp-like
           "cl" ["\n\n\n;;; " "\n\n\n;; " r"\n\(defun " r"\n\(defclass " r"\n\(defmethod " r"\n\(defmacro " r"\n\(def" r"\n\s+\(def" r"\n\(let " "\n;;;" "\n;;" #* paras]
           "clj" ["\n\n\n;;; " "\n\n\n;; " r"\n\(defn " r"\n\(defmulti " r"\n\(defn- " r"\n\(def " r"\n\(def" r"\n\s+\(def" "\n;;;" "\n;;" #* paras]
           "fnl" ["\n\n\n;;; " "\n\n\n;; " r"\n(fn " r"\n\(macro " r"\n\(local " #* paras]
           "hy" ["\n\n\n;;;" "\n\n\n;; " r"\n\(defn " r"\n\(defclass " r"\n\(def" r"\n\s+\(def" "\n;;;" "\n;;" #* paras]

           ;; markup languages
           "html" ["<body" "<div" "<p" "<br" "<li"
                   "<h1" "<h2" "<h3" "<h4" "<h5" "<h6"
                   "<span" "<table"
                   "<tr" "<td" "<th"
                   "<ul" "<ol"
                   "<header" "<footer"
                   "<nav" "<head"
                   "<style" "<script" "<meta" "<title"
                   #* paras]
           "tex" [r"\n\\chapter{" r"\n\\section{" r"\n\\subsection{" r"\n\\subsubsection{"
                  r"\n\\begin{enumerate" r"\n\\begin{itemize"
                  r"\n\\begin{description" r"\n\\begin{list"
                  r"\n\\begin{quote" r"\n\\begin{quotation"
                  r"\n\\begin{verse" r"\n\\begin{verbatim"
                  r"\n\\begin{align"  r"\n\\begin{equation" r"\n\\begin{eqnarray" 
                  r"\n\\\["
                  #* paras]

           ;; data languages
           "json_indented" ["  },\n" "  },\n" "    },\n" "    },\n" #* paras]
           "json" ["}," " }," "  }," "   }," #* paras]
           ;; plaintext markup languages
           ;; markdown requires space after heading defn, ignores ***, ---
           "markdown" ["\n# " "\n## " "\n#{1,6} " "```\n" "\n\\*\\*\\*+\n" "\n---+\n" "\n___+\n" #* paras]
           "md" (separators-by-extension "markdown")
           "rst" ["\n=+\n" "\n-+\n" "\n\\*+\n" "\n\n.. *\n\n" #* paras]
           "txt" paras)))

(defn _chunk-by-filetype [text ft]
  "Produce chunks according to file type.
  This is an internal helper function with no error handling."
  (match (:mime ft)
         ;; explicitly handled
         "text/csv" (chunk-csv text)
         "application/json" (chunk-json text)
         "application/xml" (chunk-xml text)
         "text/html" (chunk-html text)
         "text/javascript" (chunk text (separators-by-extension "js"))
         "text/x-shellscript" (chunk text (separators-by-extension "sh"))
         "application/x-sh" (chunk text (separators-by-extension "sh"))
         "text/plain" (chunk text (separators-by-extension (:extension ft)))
         ;; take a swing and hope
         otherwise (chunk text (separators-by-extension (:extension ft)))))

(defn split-file [fname]
  "Split according to file type (with error handling).
  Return generator of dicts (documents) with the extract, its embedding,
  a summary, and metadata."
  (let [ft (filetype fname)]
    (try
      (gfor [p c] (enumerate (_chunk-by-filetype (slurp fname) ft))
          {#** ft
           "added" (now)
           "extract" c
           "summary" (when summary
                       (extractive-summary c))
           "page" p
           "embedding" (embed c)
           "hash" (hash-id c)
           "length" (token-count c)})
     (except [e [Exception]]
       [{#** ft
         "added" (now)
         "error" f"Error while splitting {fname}: {e}."}]))))

(defn split [fname-or-directory]
  "Create a generator of dicts for a file,
  or from all files under a directory (recursively).
  Splits are made according to file type."
  (cond
    (.is-file (Path fname-or-directory))
    (split-file fname-or-directory)

    (.is-dir (Path fname-or-directory))
    (chain.from-iterable
      (map (fn [f] (split-file f))
           (filenames fname-or-directory))) ;; `filenames` ignores certain directories by default

    :else
    (raise (FileNotFoundError fname-or-directory))))

;; * Plain-text
;; ----------------------------------------------------

(defn chunk [#^ str text #^ (of list str) separators]
  "Recursively bisect text on a character until each chunk is under the maximum length
  allowed by the embeddings model."
  (flatten
    (if (and separators
             (>= (token-count text) (max-length)))
      (let [sep (first separators)
            occurrences (lfor m (re.finditer sep text) (.start m))
            point (if occurrences
                      (get occurrences (// (len occurrences) 2))
                      0)
            sections [(cut text point) (cut text point None)]]
        ;; if the split works, go down the tree, otherwise try the next separator
        (if point
            (lfor s sections :if s (chunk s separators))
            (chunk text (rest separators))))
      ;; splitting on newline boundaries can create large sections of whitespace
      [(.strip text)])))

;; * Plain-text markup flavours
;; ----------------------------------------------------

(defn chunk-markdown [markdown-text]
  "Split markdown text."
  (chunk markdown-text (separators-by-extension "markdown")))
                     
(defn chunk-html [html-text]
  "Convert html to markdown, then process."
  (-> html-text
      (markdownify :heading-style "ATX" :strip "style")
      (chunk-markdown)))

;; * Data languages
;; ----------------------------------------------------

(defn chunk-json [json-text]
  "Reformat and split to some sensible semantic boundary."
  (try
    (-> json-text
        (json.loads)
        (json.dumps :indent 2)
        (chunk (separators-by-extension "json_indented")))
    (except [json.decoder.JSONDecodeError]
      (chunk json-text (separators-by-extension "json")))))
      
(defn chunk-csv [csv-text]
  "Reformat and split to some sensible semantic boundary."
  (raise NotImplementedError))
  
(defn chunk-xml [xml-text]
  "Reformat and split to some sensible semantic boundary."
  (raise NotImplementedError))
