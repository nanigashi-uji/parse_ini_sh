# parse_ini.sh

## Desctiption

Shell script to parse .ini file using sed.
  - List section names of .ini file
  - Output parameter definitions with the shell variable definitions.
 
## Usage

```
[Usage] % parse_ini.sh -list     file [files ...]
        % parse_ini.sh [options] file [files ...]

[Options]
    -l,--list                       : List sections 
    -S,--sec-select       name      : Section name to select
    -T,--sec-select-regex expr      : Section reg. expr. to select
    -V,--variable-select name       : variable name to select
    -W,--variable-select-regex expr : variable reg. expr. to select
    -L,--local                      : Definition as local variables (B-sh)
    -e,--env                        : Definition as enviromnental variables
    -q,--quot                       : Definition by quoting with double/single-quotation.
    -c,--csh,--tcsh                 : Output for csh statement (default: B-sh)
    -b,--bsh,--bash                 : Output for csh statement (default)
    -s,--sec-prefix                 : add prefix: 'sectionname_' to variable names. 
    -v,--verbose                    : Verbose messages 
    -h,--help                       : Show Help (this message)

```
## Expected format of .ini file
```
[section] 
parameter_name=value
```

### parameter_name

No 4-spaces/tabs before variable_name; Otherwise it will be treated as the following contents of its previous line.

### value

it will be quoted by "..." or '...' by -q/--quot option

### Comment

The text from [#;] to the end of line will be treated as comment.(Ignored)

### continous lines

If backslash (\) exists at the end of line, the following line will be treated as continous line. If line starts with four spaces/tabs, it will be treated as the continous line of the preveous line

## Requirements
  - bash
  - sed
  - grep

## Author
  Nanigashi Uji (53845049+nanigashi-uji@users.noreply.github.com)
  
