import std/[os, strutils, strformat, terminal, times, monotimes]
import config

# Terminal ANSI Codes
let blue = ansiForegroundColorCode(fgBlue)
let green = ansiForegroundColorCode(fgGreen)
let yellow = ansiForegroundColorCode(fgYellow)
let underscore = ansiStyleCode(styleUnderscore)
let bold = ansiStyleCode(styleBright)
let reset = ansiResetCode

let
  # Don't print huge lines
  max_line_length = 200
  # Stop if many results
  max_results = 100

type
  # Object for lines
  Line = object
    text: string
    number: int

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
  c.contains(".bundle.") or
  c.contains(".min.")
  return not not_valid

# Find files recursively and check text
proc get_results(query: string): seq[Result] =
  let low_query = query.tolower

  var
    all_results: seq[Result]
    counter = 0

  block dirwalk:
    for path in walkDirRec(".", relative = true):
      block on_path:
        for e in conf().exclude:
          if path.contains(e): break on_path

        for c in path.split("/"):
          if not valid_component(c): break on_path

        var info: FileInfo

        try:
          info = getFileInfo(path)
        except:
          break on_path

        if info.size == 0: break on_path
        
        var f: File

        try:
          f = open(path)
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
          text = readFile(path)
        except:
          break on_path

        for i, line in text.split("\n").pairs():
          var matched = false

          if conf().case_insensitive:
            matched = line.tolower.contains(low_query)
          else:
            matched = line.contains(query)

          if matched:
            counter += 1
            let text = line.strip.substr(0, max_line_length).strip
            lines.add(Line(text: text, number: i + 1))
            if counter >= max_results: break
        
        if lines.len > 0:
          all_results.add(Result(path: path, lines: lines))

        # If results are full end the function
        if counter >= max_results: break dirwalk
  
  return all_results

# Print the results
proc print_results(results: seq[Result], duration: float) =
  let result_width = terminalWidth() + yellow.len + reset.len - 2
  var counter = 0

  for r in results:
    # Print header
    let
      rs = result_string(r.lines.len)
      header = &"\n{bold}{green}{r.path}{reset}"

    echo header 

    # Print lines
    for line in r.lines:
      let s = &"{yellow}{line.number}{reset}: {line.text}"
      echo s.substr(0, result_width)
    
    counter += r.lines.len

  let
    rs = result_string(counter)
    d = duration.formatFloat(ffDecimal, 2)
    
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