mdpdf() {
  local input="" output=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help) printf '%s\n' 'Usage: mdpdf FILE.md [-o OUTPUT.pdf]'; return 0 ;;
      -o|--output)
        [ "$#" -ge 2 ] && [ -n "$2" ] || { printf '%s\n' 'Missing output path' >&2; return 2; }
        output=$2; shift 2 ;;
      -*) printf 'Unknown option: %s\n' "$1" >&2; return 2 ;;
      *) [ -z "$input" ] || { printf '%s\n' 'Provide one input file' >&2; return 2; }; input=$1; shift ;;
    esac
  done
  [ -f "$input" ] || { printf '%s\n' 'Usage: mdpdf FILE.md [-o OUTPUT.pdf]' >&2; return 2; }
  command -v md-to-pdf >/dev/null 2>&1 || { printf '%s\n' 'md-to-pdf is missing; run its setup module' >&2; return 1; }
  if [ -n "$output" ]; then
    mkdir -p -- "$(dirname -- "$output")" || return 1
    md-to-pdf "$input" --dest "$output"
  else
    md-to-pdf "$input"
  fi
}
