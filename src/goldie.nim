import std/[os, strutils, strformat, terminal, times, monotimes, nre, sugar]
import config

# Terminal ANSI Codes
let blue = ansi_foreground_color_code(fgBlue)
let green = ansi_foreground_color_code(fgGreen)
let yellow = ansi_foreground_color_code(fgYellow)
let reverse = ansi_style_code(styleReverse)
let bold = ansi_style_code(styleBright)
let reset = ansiResetCode

# Other constants
let max_line_length = 200

type
  # Object for lines
  Line = object
    text: string
    number: int
    context_above: seq[string]
    context_below: seq[string]

  # Object for results
  Result = object
    path: string
    lines: seq[Line]

# Result or Results
proc result_string(n: int): string =
  return if n == 1: "result" else: "results"

# Check ignore rules
proc check_ignore(c: string): bool =
  for e in conf.ignore_exact:
    if c == e: return true

  for e in conf.ignore_contains:
    if c.contains(e): return true

  for e in conf.ignore_starts:
    if c.starts_with(e): return true

  for e in conf.ignore_ends:
    if c.ends_with(e): return true

  return false

# Check ignore defaults
proc check_ignore_defaults(c: string): bool =
  if not conf.ignore_defaults:
    return false

  return false or

  # Exact
  c == "node_modules" or
  c == "package-lock.json" or
  c == "env" or
  c == "venv" or
  c == "build" or

  # Contains
  c.contains("bundle.") or
  c.contains(".min.") or

  # Starts
  c.starts_with(".") or

  # Ends
  c.ends_with(".zip") or
  c.ends_with(".tar.gz") or

  false

# Check if the path component is valid
proc valid_component(c: string): bool =
  let not_valid = false or

  check_ignore(c) or
  check_ignore_defaults(c)

  return not not_valid

# Clean text
proc clean(text: string): string =
  if conf.context_before > 0 or conf.context_after > 0:
    return text.substr(0, max_line_length).strip(leading = false)
  else:
    return text.strip.substr(0, max_line_length).strip

# Find files recursively and check text
proc get_results(query: string): seq[Result] =
  let low_query = query.tolower
  var use_regex = false
  var reg = re("")

  if query.len > 2 and query.starts_with("/") and query.ends_with("/"):
    use_regex = true
    reg = re(query[1..^2])

  var
    all_results: seq[Result]
    counter = 0

  # Check for matches
  proc check(path: string, kind: string): bool =
    var full_path = path

    if kind == "directory":
      for e in conf.exclude:
        if path.contains(e): return false

      for c in path.split("/"):
        if not valid_component(c):
          return false

      full_path = joinPath(conf.path, path)

    var info: FileInfo

    try:
      info = get_file_info(full_path)
    except:
      return false

    if info.size == 0: return false

    var f: File

    try:
      f = open(full_path)
    except:
      return false

    var bytes: seq[uint8]
    let blen = min(info.size, 512)

    for x in 0..<blen:
      bytes.add(0)

    discard f.read_bytes(bytes, 0, blen)

    # Check if it's a binary file
    for c in bytes:
      if c == 0:
        return false

    var
      lines: seq[Line]
      text: string

    try:
      text = readFile(full_path)
    except:
      return false

    let all_lines = text.split("\n")

    proc add_results() =
      let p = if conf.absolute: full_path else: path
      all_results.add(Result(path: p, lines: lines))

    for i, line in all_lines.pairs():
      var matched = false

      if use_regex:
        matched = nre.find(line, reg).isSome
      else:
        if conf.case_insensitive:
          matched = line.tolower.contains(low_query)
        else:
          matched = line.contains(query)

      if matched:
        counter += 1
        let text = clean(line)

        var the_line = Line(text: text, number: i + 1, context_above: @[],
            context_below: @[])

        if conf.context_before > 0:
          let min = max(0, i - conf.context_before)

          if min != i:
            for j in min..<i:
              the_line.context_above.add(clean(all_lines[j]))

        if conf.context_after > 0:
          let max = min(all_lines.len - 1, i + conf.context_after)

          if max != i:
            for j in i + 1..max:
              the_line.context_below.add(clean(all_lines[j]))

        lines.add(the_line)

        if counter >= conf.max_results:
          add_results()
          return true

    if lines.len > 0:
      add_results()

    # If results are full end the function
    if counter >= conf.max_results: return true
    return false

  if file_exists(conf.path):
    discard check(conf.path, "file")
  elif dir_exists(conf.path):
    for path in walk_dir_rec(conf.path, relative = true):
      if check(path, "directory"): break
  else:
    quit(1)

  return all_results

# Print the results
proc format_results(results: seq[Result], duration: float): seq[string] =
  let format = not conf.piped and not conf.clean
  let query = conf.query
  var reg = re("")

  if query.len > 2 and query.starts_with("/") and query.ends_with("/"):
    reg = re(query[1..^2])
  else:
    let q = escape_re(query)
    reg = re(&"(?i)({q})")

  var counter = 0
  var lines: seq[string] = @[]

  proc highlight(text: string): string =
    return nre.replace(text, reg, (r: string) => &"{reverse}{r}{reset}")

  proc space() =
    if not conf.no_spacing:
      lines.add("")

  for i, r in results:
    # Print header
    let header = if format:
      &"{bold}{green}{r.path}{reset}"
    else:
      r.path

    space()
    lines.add(header)

    # Print lines
    for line in r.lines:
      let numlen = max(0, int_to_str(line.number).len)
      var padding = ""

      if numlen > 0:
        for i in 1..numlen:
          padding &= " "

      if line.context_above.len > 0:
        space()

        for item in line.context_above:
          var text = item

          if conf.highlight:
            text = highlight(text)

          if format:
            lines.add(&"{blue}>>{reset}{padding}{text}")
          else:
            lines.add(&">>{padding}{text}")

      let s = if format:
        var text = line.text

        if conf.highlight:
          text = highlight(text)

        &"{yellow}{line.number}{reset}: {text}"
      else:
        &"{line.number}: {line.text}"

      lines.add(s)

      if line.context_below.len > 0:
        for item in line.context_below:
          var text = item

          if conf.highlight:
            text = highlight(text)

          if format:
            lines.add(&"{blue}>>{reset}{padding}{text}")
          else:
            lines.add(&">>{padding}{text}")

        space()

    counter += r.lines.len

  let
    rs = result_string(counter)
    d = duration.format_float(ffDecimal, 2)

  if format:
    space()
    lines.add(&"{blue}Found {counter} {rs} in {d} ms{reset}")

  return lines

# Print results
proc print_results(lines: seq[string]) =
  var startx = 0
  var endx = len(lines) - 1

  while startx <= endx and lines[startx] == "":
    inc(startx)

  while endx >= startx and lines[endx] == "":
    dec(endx)

  let cleaned = lines[startx..endx]
  var spaced = false
  echo ""

  for line in cleaned:
    if line == "":
      if not spaced:
        echo line
        spaced = true
    else:
      echo line
      spaced = false

  echo ""

# Main function
proc main() =
  get_config()

  let
    time_start = get_mono_time()
    results = get_results(conf.query)

  # If any result
  if results.len > 0:
    let
      time_end = get_mono_time()
      duration = time_end - time_start
      ms = duration.in_nano_seconds.float / 1_000_000

    print_results(format_results(results, ms))

# Starts here
when is_main_module:
  main()
