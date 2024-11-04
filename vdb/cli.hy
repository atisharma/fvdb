"
vdb - A vector database API.

This package provides an API for interacting with a vector database
(vdb) stored in-memory using Faiss and a list of dicts and for using
Faiss and pickle for serialization.

Command-line utilities are provided for creating, modifying, and searching the
vector database.
"

(import click)
(import tabulate [tabulate])
(import toolz.dicttoolz [keyfilter])
(import json [dumps])

(import vdb.config)


(setv default-path (:path vdb.config.cfg))


(defn [(click.group)]
      cli [])

(defn [(click.command)
       (click.option "-p" "--path" :default default-path :help "Specify a vdb path.")]
  info [path]
  (import vdb.db [faiss info])
  (let [v (faiss path)]
    (click.echo
      (tabulate (.items (info v))))))

(cli.add-command info)


(defn [(click.command)
       (click.option "-p" "--path" :default default-path :help "Specify a vdb path.")]
  nuke [path]
  (import vdb.db [faiss nuke])
  (let [v (faiss path)]
    (nuke v)))

(cli.add-command nuke)

  
(defn [(click.command)
       (click.option "-p" "--path" :default default-path :help "Specify a vdb path.")]
  sources [path]
  (import vdb.db [faiss sources])
  (let [v (faiss path)]
    (for [source (sorted (sources v))]
      (click.echo source))))
  
(cli.add-command sources)

  
(defn [(click.command)
       (click.option "-p" "--path" :default default-path :help "Specify a vdb path.")
       (click.argument "file_or_directory")]
  ingest [path file-or-directory]
  (import vdb.db [faiss ingest write])
  (let [v (faiss path)
        records (ingest v file-or-directory)
        n-records (:n-records-added records)]
    (click.echo f"Adding {n_records} records")
    (write v)))
  
(cli.add-command ingest)
  

(defn [(click.command)
       (click.option "-p" "--path" :default default-path :help "Specify a vdb path.")
       (click.option "-r" "--top" :default 6 :type int :help "Return just top n results.")
       (click.option "-j" "--json" :is-flag True :default False :help "Return results as a json string")
       (click.argument "query")]
  similar [path query * top json]
  (import vdb.db [faiss similar])
  (let [v (faiss path)
        results (similar v query :top top)
        keys ["score" "source" "page" "length" "added"]]
    (if json
      (click.echo
        (dumps results))
      (click.echo
        (tabulate (lfor d results
                    (keyfilter (fn [k] (in k keys)) d))
                  :headers "keys")))))
  
(cli.add-command similar)

