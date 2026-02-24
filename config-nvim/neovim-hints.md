# Configuration
 * Key mapping       :map <key>
 * See * messages *  :messages
 * Clear messages    :messages clear

# Buffer Management
 * Open/create file, :e <filename>
 * Rename a file,    :! <oldname> <newname>, :e <newname>
 * Save all buffers, :wa
 * Jump last buffer, Ctrl-^
 * Next/Prev buffer, :bn, :bp
 * List buffers,     :ls
 * Switch to buffer, :b file<tab>
 * Close all buf cur,:%bd|e#
 * Next/Prev buffer  H, L

# Panes
 * horizontal split, :split
 * vertical split,   :vsplit
 * Resize pane,      Ctrl-<arrow>
 * Jump window,      Ctrl-w <direction>
 * Move pane,        Ctrl-w <capital direction>
 * Close pane        Ctrl-w q

# Editing
 * Undo,             :u
 * Redo,             Ctrl-r
 * The Undo list,    :undolist
 * Delete etc.,      d, dw, d$, d0

# Navigation
 * Jump to line      :<number>
 * Top/bottom of buf,gg, G
 * Top/mid/bot pane, :H, M, :L
 * Next/prev word,   w, e   and b, ge || W, E, B, gE
 * Down/Up           j, k
 * Start/End         0, $
 * First non-blank   ^
 * Next/Prev sent.   ), (
 * Next/Prev chunk   }, {
 * Jump matching     %
 * Next/Prev section ]], [[

# Copy/Paste
 * char/line/block sel  v, V, Ctrl-v
 * jump cursor          o
 * yank, word etc.,     y, yw, y$, yy, y}, yG
 * Paste before/after   P, p
 * del->insert          c$, ci"
 * |ydc|ia|wp"(...|     yank/delete/change inside/around word/paragraph/quotes/parentheses/...
 * "|abc+|yp            From register a/b/c/system-clipboard, yank/paste

# Project Management
 * Directory            :pwd, :cd <path>, :lcd <path> (ie., just for the current pane)
