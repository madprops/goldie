# Goldie

Find text in files recursively

![](goldie.jpg)

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

  --no-ignore-defaults
  Don't use the default ignore-component-rules

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

  --ignore-exact
  Add ignore-component-rule (exact)

  --ignore-contains
  Add ignore-component-rule (contains)

  --ignore-starts
  Add ignore-component-rule (starts with)

  --ignore-ends
  Add ignore-component-rule (ends with)

Arguments:

  query (Required)
  Text query to match
```

## Ignored Components

Components are each part of a path.

`/these/are/components`

They are checked to see if they should be ignored.

By default it ignores files and directories you likely don't need.

```nim
# Exact
c == "node_modules" or
c == "package-lock.json" or
c == "venv" or
c == "build" or

# Contains
c.contains("bundle.") or
c.contains(".min.") or

# Starts
c.starts_with(".") or

# Ends
c.ends_with(".zip") or
c.ends_with(".tar.gz")
```

These should be updated over time by the dev(s).

You can add more rules through arguments.

It also ignores binary files:

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

Then place that binary somewhere in your path.

Or install through the [AUR](https://aur.archlinux.org/packages/goldie-git)

## Why This

I made this because the search tool I used failed to find results sometimes.

I could just use `ripgrep` instead, but I can modify this to my needs.

Plus it's fun to have a `nim` project.

## Contribute

Code contributions are welcome to this project.

The only restriction is that dependencies are not allowed.

Library files should be included instead of declared in `goldie.nimble`

For instance this uses the `nap` library which I wrote, which is used for arguments.

And it resides in `src/nap`