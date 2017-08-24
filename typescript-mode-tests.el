
;;; typescript-mode-tests --- This file contains automated tests for typescript-mode.el

;;; Commentary:
;; Run tests using (ert-run-tests-interactively t).

;;; Code:

(require 'ert)
(require 'typescript-mode)

(defun typescript-test-get-doc ()
  (buffer-substring-no-properties (point-min) (point-max)))

(defun typescript-test-indent-all ()
  (delete-trailing-whitespace)
  (indent-region (point-min) (point-max) nil)
  (untabify (point-min) (point-max)))

(ert-deftest indentation-reference-document-is-reflowed-correctly ()
  (let* ((buffer (find-file "test-files/indentation-reference-document.ts")))
    ;; double ensure mode is active
    (typescript-mode)

    (let ((test-reference (typescript-test-get-doc)))
      (typescript-test-indent-all)
      (should (string-equal test-reference
                            (typescript-test-get-doc))))

    (kill-buffer buffer)))

(defun get-all-matched-strings (to-match)
  (let (result)
    (dotimes (x (/ (length (match-data)) 2))
      (setq result (nconc result (list (match-string x to-match)))))
    result))

(ert-deftest typescript-tslint-report-regexp-matches ()
  "typescript-tslint-report-regexp matches a line that does not
have a rule name or a severity."
  (let* ((to-match
          "src/modules/authenticator.ts[1, 83]: ' should be \"")
         (match (string-match typescript-tslint-report-regexp
                              to-match))
         (matches (and match (get-all-matched-strings to-match))))
    (should match)
    (should (not (nth 1 matches)))
    (should (not (nth 2 matches)))
    (should (string-equal (nth 3 matches)
                          "src/modules/authenticator.ts"))
    (should (string-equal (nth 4 matches) "1"))
    (should (string-equal (nth 5 matches) "83"))))

(ert-deftest typescript-tslint-report-regexp-matches-with-name ()
  "typescript-tslint-report-regexp matches a line that has
a rule name, no severity."
  (let* ((to-match
          "(quotemark) src/modules/authenticator.ts[1, 83]: ' should be \"")
         (match (string-match typescript-tslint-report-regexp
                              to-match))
         (matches (and match (get-all-matched-strings to-match))))
    (should match)
    (should (not (nth 1 matches)))
    (should (string-equal (nth 2 matches) "(quotemark) "))
    (should (string-equal (nth 3 matches)
                          "src/modules/authenticator.ts"))
    (should (string-equal (nth 4 matches) "1"))
    (should (string-equal (nth 5 matches) "83"))))

(ert-deftest typescript-tslint-report-regexp-matches-with-error ()
  "typescript-tslint-report-regexp matches a line that has
a severity set to ERROR, no rule name."
  (let* ((to-match
          "ERROR: src/modules/authenticator.ts[1, 83]: ' should be \"")
         (match (string-match typescript-tslint-report-regexp
                              to-match))
         (matches (and match (get-all-matched-strings to-match))))
    (should match)
    (should (not (nth 1 matches)))
    (should (not (nth 2 matches)))
    (should (string-equal (nth 3 matches)
                          "src/modules/authenticator.ts"))
    (should (string-equal (nth 4 matches) "1"))
    (should (string-equal (nth 5 matches) "83"))))

(ert-deftest typescript-tslint-report-regexp-matches-with-warning ()
  "typescript-tslint-report-regexp matches a line that has
a severity set to WARNING, no rule name."
  (let* ((to-match
          "WARNING: src/modules/authenticator.ts[1, 83]: ' should be \"")
         (match (string-match typescript-tslint-report-regexp
                              to-match))
         (matches (and match (get-all-matched-strings to-match))))
    (should match)
    (should (string-equal (nth 1 matches) "WARNING"))
    (should (not (nth 2 matches)))
    (should (string-equal (nth 3 matches)
                          "src/modules/authenticator.ts"))
    (should (string-equal (nth 4 matches) "1"))
    (should (string-equal (nth 5 matches) "83"))))

(ert-deftest correctly-indents-lines-with-wide-chars ()
  "Otsuka Ai and other multi-char users should be a happy to write typescript."

  (with-temp-buffer
    (ignore-errors (typescript-mode))
    (insert "let x = '大塚愛'")
    (let ((pos1 (current-column)))
      (typescript-indent-line)
      (let ((pos2 (current-column)))
        (should (= pos1 pos2))))))

(ert-deftest correctly-indents-lines-with-tabs ()
  (with-temp-buffer
    (ignore-errors (typescript-mode))

    (insert "class Example {")
    (newline-and-indent)
    (insert "constructor() {")
    (newline-and-indent)
    (insert "const a = new Promise")

    (should (= 29 (current-column)))
    (typescript-indent-line)
    (should (= 29 (current-column)))

    ;; verify tab was used
    (move-beginning-of-line nil)
    (should (= 0 (current-column)))
    (forward-char 1)
    (should (= 8 (current-column)))))

(ert-deftest indentation-does-not-hang-on-multiline-string ()
  "Testcase for https://github.com/ananthakumaran/typescript.el/issues/20"

  (with-temp-buffer
    (typescript-mode)

    (insert "let multiLineString = \"line 1")
    (newline-and-indent)
    (insert "// and so we continue")
    (newline-and-indent)
    ;; completing and not locking up is test-success!
    ))

(defun test-re-search (searchee contents offset)
  (with-temp-buffer
    (typescript-mode)

    (insert contents)
    (goto-char (- (point-max) offset))

    (should (= 5 (typescript--re-search-backward-inner searchee nil 1)))))

(ert-deftest re-search-backwards-skips-single-line-strings ()
  (test-re-search "token" "let token = \"token in string-thing\";" 2))

(ert-deftest re-search-backwards-skips-multi-line-strings ()
  (test-re-search "token" "let token = \"token in\n multi-line token string\";" 2))

(ert-deftest re-search-backwards-skips-single-line-comments ()
  (test-re-search "token" "let token; // token in comment" 0))

(ert-deftest re-search-backwards-skips-multi-line-comments ()
  (test-re-search "token" "let token; /* token in \nmulti-line token comment" 0))

;; Adapted from jdee-mode's test suite.
(defmacro test-with-temp-buffer (content &rest body)
  "Fill a temporary buffer with `CONTENT' and eval `BODY' in it."
  (declare (debug t)
           (indent 1))
  `(with-temp-buffer
     (insert ,content)
     (typescript-mode)
     (font-lock-fontify-buffer)
     (goto-char (point-min))
     ,@body))

(defun get-face-at (loc)
  "Get the face at `LOC'. If it is not a number, then we `re-search-forward' with `LOC'
as the search pattern."
  (when (not (numberp loc))
    (save-excursion
      (re-search-forward loc)
      (setq loc (match-beginning 0))))
  (get-text-property loc 'face))

(setq font-lock-contents
 " * @param {Something} bar A parameter. References [[moo]] and [[foo]].
 * @param second May hold ``x`` or ``y``.")

(defun font-lock-test (contents expected)
  "Perform a test on our template. `CONTENTS' is the string to
put in the temporary buffer. `EXPECTED' is the expected
results. It should be a list of (LOCATION . FACE) pairs."
  (test-with-temp-buffer
   contents
   (dolist (spec expected)
     (should (eq (get-face-at (car spec)) (cdr spec))))))

(ert-deftest font-lock/documentation-in-documentation-comments ()
  "Documentation in documentation comments should be fontified as
documentation."
  (font-lock-test
   (concat "/**\n" font-lock-contents "\n*/")
   '((1 . font-lock-comment-delimiter-face)
     (5 . font-lock-comment-face)
     ("@param" . typescript-jsdoc-tag)
     ("{Something}" . typescript-jsdoc-type)
     ("bar" . typescript-jsdoc-value)
     ("\\[\\[moo\\]\\]" . typescript-jsdoc-value)
     ("\\[\\[foo\\]\\]" . typescript-jsdoc-value)
     ("``x``" . typescript-jsdoc-value)
     ("``y``" . typescript-jsdoc-value))))

(ert-deftest font-lock/no-documentation-in-non-documentation-comments ()
  "Documentation tags that are not in documentation comments
should not be fontified as documentation."
  (test-with-temp-buffer
   (concat "/*\n" font-lock-contents "\n*/\n")
   (let ((loc 3))
     ;; Make sure we start with the right face.
     (should (eq (get-face-at loc) font-lock-comment-face))
     (should (eq (text-property-not-all loc (point-max) 'face font-lock-comment-face)
                 (1- (point-max)))))))

(ert-deftest font-lock/no-documentation-in-strings ()
  "Documentation tags that are not in strings should not be
fontified as documentation."
  (test-with-temp-buffer
   (concat "const x = \"/**" font-lock-contents "*/\";")
   (let ((loc (search-forward "\"")))
     ;; Make sure we start with the right face.
     (should (eq (get-face-at loc) font-lock-string-face))
     ;; Make sure the face does not change later.
     (should (eq (text-property-not-all loc (point-max) 'face font-lock-string-face)
                 (1- (point-max)))))))

(provide 'typescript-mode-tests)

;;; typescript-mode-tests.el ends here
