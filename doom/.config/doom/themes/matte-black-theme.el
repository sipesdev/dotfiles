;;; matte-black-theme.el --- Doom theme from the Alacritty matte-black palette -*- lexical-binding: t; no-byte-compile: t; -*-
;; Derived from doom-one-theme.el (doom-themes, MIT License, Henrik Lissner).
;; Palette = alacritty/.config/alacritty/alacritty.toml; keep the two in step.
;;
;; Added: May 23, 2016 (28620647f838)
;; Author: Henrik Lissner <https://github.com/hlissner>
;; Maintainer: Henrik Lissner <https://github.com/hlissner>
;; Source: https://github.com/atom/one-dark-ui
;;
;;; Commentary:
;;
;; This themepack's flagship theme.
;;
;;; Code:

(require 'doom-themes)


;;
;;; Variables

(defgroup matte-black-theme nil
  "Options for the `matte-black' theme."
  :group 'doom-themes)

(defcustom matte-black-brighter-modeline nil
  "If non-nil, more vivid colors will be used to style the mode-line."
  :group 'matte-black-theme
  :type 'boolean)

(defcustom matte-black-brighter-comments nil
  "If non-nil, comments will be highlighted in more vivid colors."
  :group 'matte-black-theme
  :type 'boolean)

(defcustom matte-black-comment-bg matte-black-brighter-comments
  "If non-nil, comments will have a subtle highlight to enhance their
legibility."
  :group 'matte-black-theme
  :type 'boolean)

(defcustom matte-black-padded-modeline doom-themes-padded-modeline
  "If non-nil, adds a 4px padding to the mode-line.
Can be an integer to determine the exact padding."
  :group 'matte-black-theme
  :type '(choice integer boolean))


;;
;;; Theme definition

(def-doom-theme matte-black
  "A dark theme inspired by Atom One Dark."
  :family 'matte-black
  :background-mode 'dark

  ;; name        default   256       16
  ((bg         '("#121212" "#121212" "black"        ))
   (fg         '("#bebebe" "#bebebe" "brightwhite"  ))
   (bg-alt     '("#0e0e0e" "#0e0e0e" "black"        ))
   (fg-alt     '("#8a8a8d" "#8a8a8d" "white"        ))
   (base0      '("#0a0a0a" "#0a0a0a" "black"        ))
   (base1      '("#161616" "#161616" "brightblack"  ))
   (base2      '("#1c1c1c" "#1c1c1c" "brightblack"  ))
   (base3      '("#262626" "#262626" "brightblack"  ))
   (base4      '("#333333" "#333333" "brightblack"  ))
   (base5      '("#515151" "#515151" "brightblack"  ))
   (base6      '("#6a6a6a" "#6a6a6a" "brightblack"  ))
   (base7      '("#8a8a8d" "#8a8a8d" "brightblack"  ))
   (base8      '("#eaeaea" "#eaeaea" "white"        ))
   (grey       base4)
   (red        '("#D35F5F" "#D35F5F" "red"          ))
   (orange     '("#e68e0d" "#e68e0d" "yellow"       ))
   (green      '("#FFC107" "#FFC107" "green"        ))
   (teal       '("#f59e0b" "#f59e0b" "brightgreen"  ))
   (yellow     '("#FFC107" "#FFC107" "brightyellow" ))
   (blue       '("#7aa2f7" "#7aa2f7" "brightblue"   ))
   (dark-blue  '("#5e81ac" "#5e81ac" "blue"         ))
   (magenta    '("#c678dd" "#c678dd" "brightmagenta"))
   (violet     '("#b48ead" "#b48ead" "magenta"      ))
   (cyan       '("#eaeaea" "#eaeaea" "brightcyan"   ))
   (dark-cyan  '("#bebebe" "#bebebe" "cyan"         ))

   ;; face categories -- required for all themes
   (highlight      orange)
   (vertical-bar   (doom-darken base1 0.1))
   (selection      base5)
   (builtin        violet)
   (comments       base7)
   (doc-comments   (doom-lighten base7 0.15))
   (constants      violet)
   (functions      blue)
   (keywords       orange)
   (methods        blue)
   (operators      fg)
   (type           dark-blue)
   (strings        green)
   (variables      fg)
   (numbers        teal)
   (region         `(,(doom-lighten (car bg-alt) 0.15) ,@(doom-lighten (cdr base1) 0.35)))
   (error          red)
   (warning        yellow)
   (success        green)
   (vc-modified    orange)
   (vc-added       green)
   (vc-deleted     red)

   ;; These are extra color variables used only in this theme; i.e. they aren't
   ;; mandatory for derived themes.
   (modeline-fg              fg)
   (modeline-fg-alt          base5)
   (modeline-bg              (if matte-black-brighter-modeline
                                 (doom-darken blue 0.45)
                               (doom-darken bg-alt 0.1)))
   (modeline-bg-alt          (if matte-black-brighter-modeline
                                 (doom-darken blue 0.475)
                               `(,(doom-darken (car bg-alt) 0.15) ,@(cdr bg))))
   (modeline-bg-inactive     `(,(car bg-alt) ,@(cdr base1)))
   (modeline-bg-inactive-alt `(,(doom-darken (car bg-alt) 0.1) ,@(cdr bg)))

   (-modeline-pad
    (when matte-black-padded-modeline
      (if (integerp matte-black-padded-modeline) matte-black-padded-modeline 4))))


  ;;;; Base theme face overrides
  (((line-number &override) :foreground base4)
   ((line-number-current-line &override) :foreground fg)
   ((font-lock-comment-face &override)
    :background (if matte-black-comment-bg (doom-lighten bg 0.05) 'unspecified))
   (mode-line
    :background modeline-bg :foreground modeline-fg
    :box (if -modeline-pad `(:line-width ,-modeline-pad :color ,modeline-bg)))
   (mode-line-inactive
    :background modeline-bg-inactive :foreground modeline-fg-alt
    :box (if -modeline-pad `(:line-width ,-modeline-pad :color ,modeline-bg-inactive)))
   (mode-line-emphasis :foreground (if matte-black-brighter-modeline base8 highlight))

   ;;;; css-mode <built-in> / scss-mode
   (css-proprietary-property :foreground orange)
   (css-property             :foreground green)
   (css-selector             :foreground blue)
   ;;;; doom-modeline
   (doom-modeline-bar :background (if matte-black-brighter-modeline modeline-bg highlight))
   (doom-modeline-buffer-file :inherit 'mode-line-buffer-id :weight 'bold)
   (doom-modeline-buffer-path :inherit 'mode-line-emphasis :weight 'bold)
   (doom-modeline-buffer-project-root :foreground green :weight 'bold)
   ;;;; elscreen
   (elscreen-tab-other-screen-face :background "#353a42" :foreground "#1e2022")
   ;;;; ivy
   (ivy-current-match :background dark-blue :distant-foreground base0 :weight 'normal)
   ;;;; LaTeX-mode
   (font-latex-math-face :foreground green)
   ;;;; markdown-mode
   (markdown-markup-face :foreground base5)
   (markdown-header-face :inherit 'bold :foreground red)
   ((markdown-code-face &override) :background (doom-lighten base3 0.05))
   ;;;; rjsx-mode
   (rjsx-tag :foreground red)
   (rjsx-attr :foreground orange)
   ;;;; solaire-mode
   (solaire-mode-line-face
    :inherit 'mode-line
    :background modeline-bg-alt
    :box (if -modeline-pad `(:line-width ,-modeline-pad :color ,modeline-bg-alt)))
   (solaire-mode-line-inactive-face
    :inherit 'mode-line-inactive
    :background modeline-bg-inactive-alt
    :box (if -modeline-pad `(:line-width ,-modeline-pad :color ,modeline-bg-inactive-alt))))

  ;;;; Base theme variable overrides-
  ())

;;; matte-black-theme.el ends here
