import std/[os, strformat, terminal]
import pkg/[nap]

let version = "0.1.0"

proc resolve_dir(path: string): string =
  let rpath = if path == ".":
    getCurrentDir()
  else:
    expandTilde(path)

  if not dirExists(rpath):
    echo "Path does not exist."
    quit(1)

  return rpath

type Config* = ref object
  query*: string
  path*: string
  absolute*: bool
  exclude*: seq[string]
  case_insensitive*: bool
  piped*: bool
  clean*: bool
  highlight*: bool
  max_results*: int
  context*: int
  context_before*: int
  context_after*: int

var oconf*: Config

proc get_config*() =
  let
    query = add_arg(name="query", kind="argument", required=true, help="Text query to match")
    path = add_arg(name="path", kind="value", value=".", help="Path to a directory", alt="p")
    absolute = add_arg(name="absolute", kind="flag", help="Show full paths", alt="a")
    exclude = add_arg(name="exclude", kind="value", multiple=true, help="Exclude paths that contain this string", alt="e")
    case_insensitive = add_arg(name="case-insensitive", kind="flag", help="Perform a case insensitive search", alt="i")
    clean = add_arg(name="clean", kind="flag", help="Print a clean list without formatting", alt="c")
    no_highlight = add_arg(name="no-highlight", kind="flag", help="Don't highlight matches", alt="h")
    max_results = add_arg(name="max-results", kind="value", value="100", help="Max results to show", alt="m")
    context = add_arg(name="context", kind="value", value="0", help="Show context above and below. Number of lines", alt="x")
    context_before = add_arg(name="context-before", kind="value", value="0", help="Show context above. Number of lines", alt="1")
    context_after = add_arg(name="context-after", kind="value", value="0", help="Show context below. Number of lines", alt="2")

  add_header("Search content of files recursively")
  add_header(&"Version: {version}")
  add_note("Git Repo: https://github.com/madprops/goldie")
  parse_args()

  let ctx = context.get_int

  oconf = Config(
    path: resolve_dir(path.value),
    piped: not isatty(stdout),
    query: query.value,
    absolute: absolute.used,
    exclude: exclude.values,
    case_insensitive: case_insensitive.used ,
    clean: clean.used,
    highlight: not no_highlight.used,
    max_results: max_results.get_int,
    context_before: max(ctx, context_before.get_int),
    context_after: max(ctx, context_after.get_int),
  )

proc conf*(): Config =
  return oconf