;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;; JetBrainsMono Nerd Font 11pt: the alacritty / Quickshell Theme.qml font. A float :size is
;; points (an integer would be pixels).
(setq doom-font (font-spec :family "JetBrainsMono Nerd Font" :size 11.0))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'matte-black)
;; Specify both a dark and light theme, like so and Doom will choose which one
;; to load based on your system light/dark setting:
;;
;;   (setq doom-theme '(doom-one   . doom-one-light))   ; (DARK . LIGHT)
;;
;; If you want more pro-active theme switching based on OS light/dark mode, look
;; up the `auto-dark' package.

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

;; Terminal frames look like the GUI: Alacritty is truecolor and uses the same
;; JetBrainsMono Nerd Font, so the matte-black theme paints identical colors and
;; the modeline icons render there too. The default face keeps the terminal's
;; own background so Alacritty's opacity shows through.
(setq doom-modeline-icon t)
(defun +matte/tty-transparent-bg (&optional frame)
  "Give terminal frames (FRAME or all of them) the terminal's own background."
  (dolist (f (if frame (list frame) (frame-list)))
    (unless (display-graphic-p f)
      (set-face-background 'default "unspecified-bg" f))))
(add-hook 'after-make-frame-functions #'+matte/tty-transparent-bg)
(add-hook 'doom-load-theme-hook #'+matte/tty-transparent-bg)

;; In-Emacs terminal: :term vterm (SPC o t popup, SPC o T here). Build its
;; native module without asking, so the first vterm on a fresh machine does not
;; stall a daemon frame on a y-or-n prompt (libvterm + cmake are installed).
(setq vterm-always-compile-module t)

;; Mouse in every terminal frame. Emacs 31 turns xterm-mouse-mode on by itself
;; only for terminals that pass its clipboard+mouse probe: Alacritty does, a
;; herdr pane does not, and without the tracking request herdr keeps clicks for
;; its own text selection instead of forwarding them to Emacs.
(xterm-mouse-mode 1)
