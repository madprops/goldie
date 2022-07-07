import std/[strformat]
import pkg/[nap]

let version = "0.1.0"

type Config* = ref object
  query*: string
  exclude*: seq[string]
  case_insensitive*: bool

var oconf*: Config

proc get_config*() =
  let
    query = add_arg(name="query", kind="argument", required=true, help="Path to a directory")
    exclude = add_arg(name="exclude", kind="value", multiple=true, help="String to exclude", alt="e")
    case_insensitive = add_arg(name="case-insensitive", kind="flag", help="Perform a case insensitive search", alt="i")

  add_header("Search content of files recursively")
  add_header(&"Version: {version}")
  add_note("Git Repo: https://github.com/madprops/goldie")
  parse_args()

  oconf = Config(
    query: query.value,
    exclude: exclude.values,
    case_insensitive: case_insensitive.used 
  )

proc conf*(): Config =
  return oconf