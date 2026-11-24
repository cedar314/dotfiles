source "$DOTFILES_ROOT/md-to-pdf/versions.sh"
npm_tool md-to-pdf md-to-pdf "$MD_TO_PDF_VERSION" || true
link_config "$DOTFILES_ROOT/md-to-pdf/init.sh" "$CONFIG_HOME/dotfiles/shell/md-to-pdf.sh"
link_config "$DOTFILES_ROOT/md-to-pdf/style.css" "$CONFIG_HOME/md-to-pdf/style.css"
status skipped 'Stylesheet preserved but not forced; the inspected helper did not apply it. Use md-to-pdf --stylesheet explicitly.'
status skipped 'Chromium/browser downloads and fonts are separate host prerequisites; no sandbox flags changed'
