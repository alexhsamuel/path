#-------------------------------------------------------------------------------
# 
# Interactive bash path manipulation library
#
# Source this file in bash or your `.bashrc` to add a `path` shell function for
# manipulating colon-delimited lookup paths in environment variables, such as
# `PATH`, `LD_LIBRARY_PATH`, and `PYTHONPATH`.
#
# Invoke `path --help` for usage information.  Examples:
#
#   path PATH                           # Print how my command path.
#   path PATH - 0                       # Remove the first element from it.
#   path PYTHONPATH ++ $HOME/python     # Prepend ~/python to my Python path.
#
# Also supports short aliases for path environment variable names.  For
# example,
#
#   PATH_VARNAME_ALIASES=(
#       [CP]=CLASSPATH
#       [LD]=LD_LIBRARY_PATH
#       [MAN]=MANPATH
#       [PY]=PYTHONPATH
#       [P]=PATH
#   )
#
#-------------------------------------------------------------------------------

abspath() {
    echo "$(cd "$(dirname "$1")"; echo $PWD)/$(basename "$1")"
}

_path-join() {
    local IFS=":"
    echo "$*"
}    

# _path-join-set VARNAME ITEM ...
#
#   Sets path $VARNAME to the path obtained by joining ITEMs.
# 
_path-join-set() {
    local varname="$1"; shift
    eval "$varname"="$(_path-join "$@")"
    export $varname
}

_path-show() {
    local varname="$1"

    local parts
    IFS=":" read -r -a parts <<< "${!varname}"

    echo "$varname="
    local part
    local i=0
    for part in "${parts[@]}"; do
        printf "%3d: %s\n" $i "$part"
        i=$(( i + 1 ))
    done
}

_path-remove() {
    local varname="$1"
    local item="$2"

    local parts
    IFS=":" read -r -a parts <<< "${!varname}"

    if [[ $item =~ ^[0-9]+$ ]]; then
        unset parts[$item]
    else
        item="$(abspath "$item")"
        local i
        for (( i = ${#parts[@]} - 1; i >= 0; i-- )); do
            local part="${parts[$i]}"
            if [[ "$part" == "$item" ]]; then
                unset parts[$i]
            fi
        done
    fi
    _path-join-set "$varname" "${parts[@]}"
}    

_path-in() {
    local varname="$1"
    local item="$2"

    item="$(abspath "$item")"

    local parts
    IFS=":" read -r -a parts <<< "${!varname}"

    local part
    for part in "${parts[@]}"; do
        if [[ "$part" == "$item" ]]; then
            return 0
        fi
    done
    return 1
}

_path-prepend() {
    local varname="$1"
    local item="$2"

    item="$(abspath "$item")"

    _path-remove "$varname" "$item"
    local parts
    IFS=":" read -r -a parts <<< "${!varname}"

    local -a new_parts=("$item")
    new_parts+=("${parts[@]}")
    _path-join-set "$varname" "${new_parts[@]}"
}

_path-add() {
    local varname="$1"
    local item="$2"

    item="$(abspath "$item")"

    local parts
    IFS=":" read -r -a parts <<< "${!varname}"

    local found
    for part in "${parts[@]}"; do
        if [[ "$part" == "$item" ]]; then
            found=yes
            break
        fi
    done
    if [[ ! $found ]]; then
        parts[${#parts[@]}]="$item"
    fi
    _path-join-set "$varname" "${parts[@]}"
}

_path-clean() {
    local varname="$1"

    local real
    if [[ "$1" == --real ]]; then
        real=yes
        shift
    fi

    local -a parts
    IFS=":" read -r -a parts <<< "${!varname}"

    local -a clean=()
    local part part1 
    for part in "${parts[@]}"; do
        local found=
        for part1 in "${clean[@]}"; do
            if [[ "$part" == "$part1" 
                  || ( $real && "$part" -ef "$part1" ) ]]; then
                found=yes
                break
            fi
        done
        if [[ ! $found ]]; then 
            clean[${#clean[@]}]="$part"
        fi
    done
    _path-join-set "$varname" "${clean[@]}"
}

_path-help() {
    echo 'Usage: path VARNAME [ COMMAND ... ]

    path VARNAME [ show ]
      Prints path components of $VARNAME.

    path VARNAME ( remove | rm | - ) ITEM
      If ITEM is a component of $VARNAME, removes it.  
      If ITEM is a number, returns the ITEMth component of $VARNAME.

    path VARNAME in ITEM
      Returns true if ITEM is a component of $VARNAME.

    path VARNAME ( prepend | pre | + ) ITEM
      Prepends ITEM to the path $VARNAME.  If it is already a component, 
      replaces the existing occurrence.

    path VARNAME ( add | ++ ) ITEM
      Appends ITEM it to the path $VARNAME if it is not a component.

    path VARNAME clean [ --real ]
      Removes the second and subsequent occurence of each component of $VARNAME.
      With --real, components are compared based on actual file system identity,
      so that redundant paths to the same file are removed.
    '
}

declare -A PATH_VARNAME_ALIASES

path() {
    local varname="$1"; shift
    if [[ $varname == "-h" || $varname == "--help" ]]; then
        _path-help
        return 0
    fi
    if [[ -z "$varname" ]]; then
        echo "missing VARNAME" >&2
        return 1
    fi

    local expansion="${PATH_VARNAME_ALIASES[$varname]}"
    if [[ -n "$expansion" ]]; then
        varname=$expansion
    fi    

    local command="${1:-show}"; shift
    case "$command" in
        # Command aliases.
        pre|++) command=prepend;;
        rm|-)   command=remove;;
        +)      command=add;;
        # Valid commands.
        add|clean|in|prepend|remove|show);;
        # Anything else is invalid.
        *)
            echo "invalid command '$command'" >&2
            return 1;;
    esac

    _path-$command "$varname" "$@"
}

