import std/[os, strutils, strformat, terminal, times, monotimes, nre, sugar]
import config

# Terminal ANSI Codes
let blue = ansiForegroundColorCode(fgBlue)
let green = ansiForegroundColorCode(fgGreen)
let yellow = ansiForegroundColorCode(fgYellow)
let reverse = ansiStyleCode(styleReverse)
let bold = ansiStyleCode(styleBright)
let reset = ansiResetCode
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

# Check if the path component is valid
proc valid_component(c: string): bool =
  let not_valid = c.startsWith(".") or
  c == "node_modules" or
  c == "package-lock.json" or
  c == "LICENSE" or
  c == "LICENSE.md" or
  c.contains(".bundle.") or
  c.contains(".min.")
  return not not_valid

# Find files recursively and check text
proc get_results(query: string): seq[Result] =
  let low_query = query.tolower
  var use_regex = false
  var reg = re("")

  if query.len > 2 and query.startsWith("/") and query.endsWith("/"):
    use_regex = true
    reg = re(query[1..^2])

  var
    all_results: seq[Result]
    counter = 0

  block dirwalk:
    for path in walkDirRec(conf().path, relative = true):
      block on_path:
        for e in conf().exclude:
          if path.contains(e): break on_path

        for c in path.split("/"):
          if not valid_component(c): break on_path

        let full_path = joinPath(conf().path, path)
        var info: FileInfo

        try:
          info = getFileInfo(full_path)
        except:
          break on_path

        if info.size == 0: break on_path

        var f: File

        try:
          f = open(full_path)
        except:
          break on_path

        var bytes: seq[uint8]
        let blen = min(info.size, 512)

        for x in 0..<blen:
          bytes.add(0)

        discard f.readBytes(bytes, 0, blen)

        # Check if it's a binary file
        for c in bytes:
          if c == 0:
            break on_path

        var
          lines: seq[Line]
          text: string

        try:
          text = readFile(full_path)
        except:
          break on_path

        let all_lines = text.split("\n")

        for i, line in all_lines.pairs():
          var matched = false

          if use_regex:
            matched = nre.find(line, reg).isSome
          else:
            if conf().case_insensitive:
              matched = line.tolower.contains(low_query)
            else:
              matched = line.contains(query)

          if matched:
            counter += 1
            let text = line.strip.substr(0, max_line_length).strip
            var the_line = Line(text: text, number: i + 1, context_above: @[], context_below: @[])

            if conf().num_context > 0:
              let min = max(0, i - conf().num_context)

              if min != i:
                for j in min..<i:
                  the_line.context_above.add(all_lines[j])

              let max = min(all_lines.len - 1, i + conf().num_context)

              if max != i:
                for j in i + 1..max:
                  the_line.context_below.add(all_lines[j])

            lines.add(the_line)
            if counter >= conf().max_results: break

        if lines.len > 0:
          let p = if conf().absolute: full_path else: path
          all_results.add(Result(path: p, lines: lines))

        # If results are full end the function
        if counter >= conf().max_results: break dirwalk

  return all_results

# Print the results
proc print_results(results: seq[Result], duration: float) =
  let format = not conf().piped and not conf().clean
  let query = conf().query
  var reg = re("")

  if query.len > 2 and query.startsWith("/") and query.endsWith("/"):
    reg = re(query[1..^2])
  else:
    let q = escapeRe(query)
    reg = re(&"(?i)({q})")

  var counter = 0

  for i, r in results:
    # Print header
    let rs = result_string(r.lines.len)

    let header = if format:
      &"\n{bold}{green}{r.path}{reset}"
    else:
      if i == 0:
        r.path
      else:
        &"\n{r.path}"

    echo header

    # Print lines
    for line in r.lines:
      if line.context_above.len > 0:
        echo ""

        for item in line.context_above:
          if format:
            echo &"{green}B{reset}: {item}"
          else:
            echo &"B: {item}"

      let s = if format:
        var text = line.text

        if conf().highlight:
          text = nre.replace(text, reg, (r: string) => &"{reverse}{r}{reset}")

        &"{yellow}{line.number}{reset}: {text}"
      else:
        &"{line.number}: {line.text}"

      echo s

      if line.context_below.len > 0:
        for item in line.context_below:
          if format:
            echo &"{green}A{reset}: {item}"
          else:
            echo &"A: {item}"

    counter += r.lines.len

  let
    rs = result_string(counter)
    d = duration.formatFloat(ffDecimal, 2)

  if format:
    echo &"\n{blue}Found {counter} {rs} in {d} ms{reset}\n"

# Main function
proc main() =
  get_config()

  let
    time_start = getMonoTime()
    results = get_results(conf().query)

  # If any result
  if results.len > 0:
    let
      time_end = getMonoTime()
      duration = time_end - time_start
      ms = duration.inNanoSeconds.float / 1_000_000

    print_results(results, ms)

# Starts here
when isMainModule:
  main()