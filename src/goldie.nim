import std/[os, strutils, strformat, terminal]

# Terminal ANSI Codes
let blue = ansiForegroundColorCode(fgBlue)
let green = ansiForegroundColorCode(fgGreen)
let yellow = ansiForegroundColorCode(fgYellow)
let reset = ansiResetCode

# Don't print huge lines
let max_line_length = 250

# Stop if many results
let max_results = 100

# Object for lines
type Line = object
  text: string
  number: int

# Object for results
type Result = object
  path: string
  lines: seq[Line]

# Result or Results
proc result_string(n: int): string =
  return if n == 1: "result" else: "results"  

# Find files recursively and check text
proc get_results(query: string): (int, seq[Result]) =
  let q = query.toLower
  var all_results: seq[Result]
  var counter = 0

  block dirwalk:
    for path in walkDirRec(".", relative=true):
      block on_path:
        let components = path.split("/")
        for c in components:
          if c.startsWith("."): break on_path

        let info = getFileInfo(path)
        if info.size == 0: continue
        
        let f = open(path)
        var bytes: seq[uint8]
        let blen = min(info.size, 512)
        
        for x in 0..<blen:
          bytes.add(0)
        
        discard f.readBytes(bytes, 0, blen)

        # Check if it's a binary file
        for c in bytes:
          if c == 0:
            break on_path
        
        var lines: seq[Line]

        for i, line in readFile(path).split("\n").pairs():
          if line.toLower.contains(q):
            let text = line.strip.substr(0, max_line_length).strip
            lines.add(Line(text: text, number: i + 1))
            counter += 1
            
            if counter >= max_results:
              all_results.add(Result(path: path, lines: lines))
              break dirwalk
        
        if lines.len > 0:
          all_results.add(Result(path: path, lines: lines))
  
  return (counter, all_results)

# Print the results
proc print_results(counter: int, results: seq[Result]) =
  let rs = result_string(counter)
  echo &"\n{blue}Found {counter} {rs}{reset}"

  for r in results:
    # Print header
    let rs = result_string(r.lines.len)
    let header = &"\n< {r.lines.len} {rs} in {green}{r.path}{reset} >"    
    echo header 

    # Print lines
    for line in r.lines:
      echo &"{yellow}{line.number}{reset}: {line.text}"

  echo ""   

# Main function
proc main() =
  if paramCount() < 1:
    return
  
  var args: seq[string]

  for i in 1..paramCount():
    args.add(paramStr(i))
  
  let query = args.join(" ").strip
  
  if query == "":
    return
  
  let ans = get_results(query)
  let counter = ans[0]
  let results = ans[1]

  # If results
  if counter > 0:
    print_results(counter, results)

# Starts here
when isMainModule:
  main()