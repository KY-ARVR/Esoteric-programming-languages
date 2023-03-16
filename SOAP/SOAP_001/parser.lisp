;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 
;; This class comprehends the definition of "Parser" class and its
;; appertaining operations, serving in the assemblage of an abstract
;; syntax tree (AST) from a series of tokens, supplied by a lexer.
;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; -- Implementation of class "Parser".                            -- ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defstruct (Parser
  (:constructor make-parser (lexer
                             &aux (current-token
                                    (lexer-get-next-token lexer)))))
  "The ``Parser'' class' task resolves to the assemblage of an abstract
   syntax tree (AST) from a series of tokens generated by a lexer under
   its castaldy."
  (lexer         (error "Missing lexer for parser.") :type Lexer)
  (current-token (make-token :eof NIL)               :type Token))

;;; -------------------------------------------------------

(declaim (ftype (function (Parser) Node) parser-parse-statement))

;;; -------------------------------------------------------

(defmacro with-parser ((parser) &body body)
  "Evaluates the PARSER and binds its slots ``lexer'' and
   ``current-token'' to eponymous local symbol macros for general
   access, evaluates the BODY forms, and returns the last processed
   form's results.
   ---
   Two local functions vouchsafe latreutical commodities:
   
     ------------------------------------------------------------------
     Local function       | Effect
     ---------------------+--------------------------------------------
     eat (type)           | Returns the current token if it conforms to
                          | the expected TYPE, while querying and
                          | storing the next for future purposes. If no
                          | conformity could be ascertained, an error
                          | of an unspecified type is signaled.
     ..................................................................
     eat-current-token () | Returns the current token, while querying
                          | and storing the next one for future
                          | purposes.
     ------------------------------------------------------------------"
  (let ((evaluated-parser (gensym)))
    (declare (type symbol evaluated-parser))
    `(let ((,evaluated-parser ,parser))
       (declare (type Parser ,evaluated-parser))
       (declare (ignorable   ,evaluated-parser))
       (symbol-macrolet
           ((lexer
             (the Lexer
               (parser-lexer parser)))
            (current-token
             (the Token
               (parser-current-token parser))))
         (declare (type Lexer lexer))
         (declare (ignorable  lexer))
         (declare (type Token current-token))
         (declare (ignorable  current-token))
         (flet
             ((eat (expected-token-type)
               "Checks whether the CURRENT-TOKEN conforms to the
                EXPECTED-TOKEN-TYPE, on confirmation returning the
                CURRENT-TOKEN while concomitantly querying and storing
                the next one from the LEXER; on a mismatch, an error of
                an unspecified type is signaled."
               (declare (type keyword expected-token-type))
               (the Token
                 (if (token-type-p current-token expected-token-type)
                   (prog1 current-token
                     (setf current-token
                       (lexer-get-next-token lexer)))
                   (error "Expected a token of the type ~s, ~
                           but encountered ~s."
                     expected-token-type current-token))))
              (eat-current-token ()
               "Returns the CURRENT-TOKEN before querying and storing
                the next one from the LEXER in its stead."
               (the Token
                 (prog1 current-token
                   (setf current-token
                     (lexer-get-next-token lexer))))))
           ,@body)))))

;;; -------------------------------------------------------

(defun parser-parse-integer-literal (parser)
  "Parses a base-3 integer literal using the PARSER and returns an
   ``:integer-literal'' node representation thereof."
  (declare (type Parser parser))
  (with-parser (parser)
    (the Node
      (make-node :integer-literal
        :value (token-value (eat :integer))))))

;;; -------------------------------------------------------

(defun parser-parse-variable (parser)
  "Parses a variable query expression using the PARSER and returns a
   ``:variable'' node representation thereof."
  (declare (type Parser parser))
  (with-parser (parser)
    (the Node
      (make-node :variable))))

;;; -------------------------------------------------------

(defun parser-parse-expression (parser)
  "Parses a numeric expression using the PARSER, which may either
   constitute a literal integer or a variable access, and returns a node
   representation thereof."
  (declare (type Parser parser))
  (with-parser (parser)
    (the Node
      (case (token-type current-token)
        (:integer
          (parser-parse-integer-literal parser))
        (:percent
          (parser-parse-variable parser))
        (otherwise
          (error "Invalid expression token: ~s." current-token))))))

;;; -------------------------------------------------------

(defun parser-parse-empty-set (parser)
  "Parses an empty set (\"Ø\") and returns a ``:set-literal'' node
   representation thereof."
  (declare (type Parser parser))
  (with-parser (parser)
    (eat :empty-set)
    (the Node
      (make-node :set-literal :elements NIL))))

;;; -------------------------------------------------------

(defun parser-parse-non-empty-set (parser)
  "Parses a braced set literal, ensconced with \"{\" and \"}\", and
   returns a ``:set-literal'' node representation thereof."
  (declare (type Parser parser))
  (with-parser (parser)
    (eat :left-brace)
    (let ((elements NIL))
      (declare (type node-list elements))
      (unless (token-type-p current-token :right-brace)
        (push (parser-parse-expression parser) elements)
        (loop while (token-type-p current-token :comma) do
          (eat :comma)
          (push (parser-parse-expression parser) elements)))
      (eat :right-brace)
      (the Node
        (make-node :set-literal
          :elements (nreverse elements))))))

;;; -------------------------------------------------------

(defun parser-parse-set-literal (parser)
  "Parses a set literal using the PARSER, either constituting the empty
   set (\"Ø\") or a bracketed (\"{...}\") variant of zero or more
   elements, and returns a ``:set-literal'' node representation
   thereof."
  (declare (type Parser parser))
  (with-parser (parser)
    (the Token
      (case (token-type current-token)
        (:empty-set
          (parser-parse-empty-set parser))
        (:left-brace
          (parser-parse-non-empty-set parser))
        (otherwise
          (error "Expected an empty set or a set literal, ~
                  but encountered the token ~s."
            current-token))))))

;;; -------------------------------------------------------

(defun parser-parse-membership-flip (parser)
  "Parses a membership flip instruction using the PARSER and returns a
   ``:flip-membership'' node representation thereof."
  (declare (type Parser parser))
  (with-parser (parser)
    (eat :asterisk)
    (the Node
      (make-node :flip-membership
        :value (parser-parse-expression parser)))))

;;; -------------------------------------------------------

(defun parser-parse-character-output (parser)
  "Parses a character output instruction using the PARSER and returns a
   ``:print-character'' node representation thereof."
  (declare (type Parser parser))
  (with-parser (parser)
    (the Node
      (make-node :print-character :value
        (token-value
          (eat :quoted-character))))))

;;; -------------------------------------------------------

(defun parser-parse-set-operation (parser)
  "Parses a binary set operation using the PARSER and returns a
   ``:set-operation'' node representation thereof."
  (declare (type Parser parser))
  (with-parser (parser)
    (let ((operator      NIL)
          (right-operand NIL))
      (declare (type (or null set-operator) operator))
      (declare (type (or null Node)         right-operand))
      (setf operator      (token-type (eat-current-token)))
      (setf right-operand (parser-parse-set-literal parser))
      (the Node
        (make-node
          :set-operation
          :operator      operator
          :right-operand right-operand)))))

;;; -------------------------------------------------------

(defun parser-parse-loop (parser)
  "Parses a loop construct using the PARSER and returns a ``:loop'' node
   representation thereof."
  (declare (type Parser parser))
  (with-parser (parser)
    (let ((predicate       NIL)
          (guard-set       NIL)
          (body-statements NIL))
      (declare (type (or null set-relationship) predicate))
      (declare (type (or null Node)             guard-set))
      (declare (type node-list                  body-statements))
      (setf predicate (token-type (eat-current-token)))
      (setf guard-set (parser-parse-set-literal parser))
      (eat :left-bracket)
      (setf body-statements
        (loop
          until   (token-type-p current-token :right-bracket)
          collect (parser-parse-statement parser)))
      (eat :right-bracket)
      (the Node
        (make-node :loop
          :predicate predicate
          :guard-set guard-set
          :body      body-statements)))))

;;; -------------------------------------------------------

(defun parser-parse-character-test (parser)
  "Parses a conditional character test using the PARSER and returns an
   ``:if-character'' node representation thereof."
  (declare (type Parser parser))
  (with-parser (parser)
    (let ((guard-character NIL)
          (body-statements NIL))
      (declare (type (or null character) guard-character))
      (declare (type node-list           body-statements))
      (setf guard-character
        (token-value
          (eat :apostrophized-character)))
      (eat :slash)
      (setf body-statements
        (loop
          until   (token-type-p current-token :backslash)
          collect (parser-parse-statement parser)))
      (eat :backslash)
      (the Node
        (make-node :if-character
          :guard-character guard-character
          :body            body-statements)))))

;;; -------------------------------------------------------

(defun parser-parse-simple-instruction (parser token-type node-type)
  "Parses a single-token instruction, conforming to the TOKEN-TYPE,
   using the PARSER and returns a node representation thereof,
   identified by the NODE-TYPE."
  (declare (type Parser  parser))
  (declare (type keyword token-type))
  (declare (type keyword node-type))
  (with-parser (parser)
    (the Node
      (prog1
        (make-node node-type)
        (eat token-type)))))

;;; -------------------------------------------------------

(defun parser-parse-statement (parser)
  "Parses a single statement using the PARSER and returns a node
   representation thereof."
  (declare (type Parser parser))
  (with-parser (parser)
    (the Node
      (case (token-type current-token)
        (:asterisk
          (parser-parse-membership-flip parser))
        
        (:quoted-character
          (parser-parse-character-output parser))
        
        ((:subset   :proper-subset   :not-subset
          :superset :proper-superset :not-superset
          :equal)
          (parser-parse-loop parser))
        
        ((:union :intersection :left-difference :right-difference)
          (parser-parse-set-operation parser))
        
        (:c
          (parser-parse-simple-instruction parser :c :complement))
        
        (:colon
          (parser-parse-simple-instruction parser :colon
            :increment-variable))
        
        (:semicolon
          (parser-parse-simple-instruction parser :semicolon
            :increment-variable))
        
        (:tilde
          (parser-parse-simple-instruction parser :tilde
            :input-character))
        
        (:apostrophized-character
          (parser-parse-character-test parser))
        
        (otherwise
          (error "Invalid statement token: ~s." current-token))))))

;;; -------------------------------------------------------

(defun parser-parse (parser)
  "Assembles the tokens supplied to the PARSER into an abstract syntax
   tree (AST) and returns its root node."
  (declare (type Parser parser))
  (with-parser (parser)
    (the Node
      (make-node :program :statements
        (prog1
          (loop
            until   (token-type-p current-token :eof)
            collect (parser-parse-statement parser))
          (eat :eof))))))
