#!/bin/bash

# Run make and capture errors, then process them to group by file and sort imports
make 2>&1 \
| sed "s/[‘’]/'/g" \
| grep "Error: Symbol .* is undefined" \
| LC_ALL=C gawk -F: '
{
  file = $1
  split($0, p, "\047")   # split on ASCII single quote
  sym = p[2]
  if (!seen[file SUBSEP sym]++) {
    if (!(file in seenFile)) {
      seenFile[file] = ++nfiles
      order[nfiles] = file
    }
    syms[file, ++count[file]] = sym
  }
}
END {
  for (i = 1; i <= nfiles; i++) {
    f = order[i]
    print "; " f
    # unique per file (already ensured), but sort them (by value)
    delete list
    k = 0
    for (j = 1; j <= count[f]; j++) list[++k] = syms[f, j]
    asort(list)   # <-- value sort; keeps the actual symbol strings
    for (j = 1; j <= k; j++) print ".import " list[j]
    if (i < nfiles) print ""
  }
}'
