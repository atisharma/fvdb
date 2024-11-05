"
Apply `sumy` to generate an extractive summary.
"

(require hyrule [of -> ->>])

(import nltk)
(import nltk.tokenize [PunktTokenizer])
(import sumy.parsers.plaintext [PlaintextParser])
(import sumy.nlp.tokenizers [Tokenizer])
(import sumy.summarizers.lsa [LsaSummarizer :as Summarizer])
(import sumy.nlp.stemmers [Stemmer])
(import sumy.utils [get_stop_words])

(import fvdb.config)


(setv language (:language fvdb.config.cfg "english"))
(setv summary-sentences (:summary-sentences fvdb.config.cfg 10))

(nltk.download "punkt_tab" :quiet True)

;; * Extractive summary using sumy
;; ----------------------------------------------------

(defclass FixedTokenizer [Tokenizer]
  "See https://github.com/miso-belica/sumy/issues/216"

  (defn _get-sentence-tokenizer [self language]
    "Override this method for CVE-2024-39705"
    (when (in language self.SPECIAL_SENTENCE_TOKENIZERS)
      (return (get self.SPECIAL_SENTENCE_TOKENIZERS language)))
    (try
      (return (PunktTokenizer language))
      (except [e (LookupError zipfile.BadZipfile)]
        (raise (LookupError "NLTK tokenizers are missing or the language is not supported.\n"
			    "Download them by following command: python -c \"import nltk; nltk.download('punkt_tab')\"\n"
                	    "Original error was:\n" + str(e)))))))

(defn extractive-summary [text]
  "Apply `sumy` to generate an extractive summary."
  (let [parser (PlaintextParser.from-string text (FixedTokenizer language))
        stemmer (Stemmer language)
        summarizer (Summarizer stemmer)]
    (setv summarizer.stop_words (get-stop-words language))
    (.join " " (map str (summarizer parser.document summary-sentences)))))

