![](goldie.jpg)

Finds text in files, recursively. Simply provide a query.

![](https://i.imgur.com/p0Guav9.jpeg)

## Arguments

```
Flags:

  --absolute (or -a)
  Show full paths

  --case-insensitive (or -i)
  Perform a case insensitive search

  --clean (or -c)
  Print a clean list without formatting

  --no-highlight (or -h)
  Don't highlight matches

  --no-spacing (or -s)
  Don't add spacing between items

Values:

  --path (or -p)
  Path to a directory

  --exclude (or -e)
  Exclude paths that contain this string

  --max-results (or -m)
  Max results to show

  --context (or -C)
  Number of lines to show in between

  --context-before (or -B)
  Number of lines to show before

  --context-after (or -A)
  Number of lines to show after

Arguments:

  query (Required)
  Text query to match
```

## Ignored Files

```nim
# Check if the path component is valid
proc valid_component(c: string): bool =
  let not_valid = c.starts_with(".") or
  c == "node_modules" or
  c == "package-lock.json" or
  c == "venv" or
  c == "build" or
  c.contains("bundle.") or
  c.contains(".min.") or
  c.ends_with(".zip") or
  c.ends_with(".tar.gz")
  return not not_valid
```

It also ignores binary files.

```nim
for c in bytes:
    if c == 0:
        return false
```

## Running

To run the debug version for testing you can use `run.sh`

To compile a production binary you can do:

```sh
nim compile -d:release -o=bin/goldie "src/goldie.nim"
```

Or install through the [AUR](https://aur.archlinux.org/packages/goldie-git)