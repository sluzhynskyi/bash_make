#!/usr/bin/env bash
filename='shmakefile'
# Transform long options to short ones
for arg in "$@"; do
    shift
    case "$arg" in
    "--help") set -- "$@" "-h" ;;
    "--file") set -- "$@" "-f" ;;
    *) set -- "$@" "$arg" ;;
    esac
done
# Parsing short options
while getopts ":hf:" opt; do
    case ${opt} in
    h)
        echo "Usage:"
        echo "    shell_make -h                 Display this help message."
        echo "    shell_make -f                 Use file as a makefile"
        exit 0
        ;;
    f)
        filename=$OPTARG
        ;;
    \?)
        echo "Usage: shell_make [-h] [-f makefile]"
        exit 1
        ;;
    :)
        echo "Usage: shell_make [-f makefile], needs an argument"
        exit 1
        ;;
    esac
done
shift $((OPTIND - 1))
# Creating an array for targets that provided user

declare -A targets
declare -A builds # Associative array of target:True, if build, target:False, if not
declare -A commands
declare -a orders

# Reading file
IFS=$'\n'
while read -r line; do
    # reading each line
    if [[ $line == *:* ]]; then
        IFS=':' read -r -a array <<<"$line"
        orders+=("${array[0]}")
        target="${array[0]}"
        dependencies="${array[1]}"
        if [[ -n $dependencies ]]; then
            targets["$target"]="$dependencies"
        else
            targets["$target"]=""
        fi
    fi

    if [[ $line =~ ^$(printf '\t').* ]]; then
        c="${line/$(printf '\t')/}"
        commands["$target"]="$c"
    fi
done <"$filename"

if [ $# -gt 0 ]; then
    start_targets=("$@")
else
    start_targets=("${orders[0]}")
#    echo "${start_targets[0]}"
fi

#for key in "${orders[@]}"; do
#    echo "$key"
#    echo "${targets[$key]}"
#done
#for key in "${commands[@]}"; do echo "$key"; done
#for key in "${!targets[@]}"; do echo "$key"; done
for key in "${!targets[@]}"; do builds[$key]=false; done
#for value in "${targets[@]}"; do echo "$value"; done
function older_modified() {
    if [[ $1 -ot $2 ]]; then #  FILE1 is older than FILE2
        return 1
    fi
    return 0
}

IFS=" "
make() {
    if [ "${builds[$1]}" = false ]; then
        builds[$1]=true
        dep="${targets[$1]}" # Get dependencies for target
        for d in $dep; do
            d_t="${d//[$'\t\r\n ']/}"
            if [ -n "$d_t" ]; then
                make "$d_t"
            else
                echo "No rule to make target '$d'. Stop" && exit 1
            fi
        done
        m=0
        f=0
        for d in $dep; do
            d_t="${d//[$'\t\r\n ']/}"
            if [ -n "$d_t" ]; then
                if [[ $1 = *.* ]] && [[ -f $d ]]; then
                    f=1
                    if older_modified "$d" "$1"; then
                        m=1
                    fi
                fi
            fi
        done
        if [[ ${commands[$1]+abc} ]] && { [[ $m == 1 ]] || [[ $f == 0 ]]; }; then
            echo "${commands[$1]}"
            eval "${commands[$1]}"
        fi
    fi
}
for t in "${start_targets[@]}"; do
    ! [ ${targets["$t"]+abc} ] && echo " No rule to make target '$t'. Stop" && exit 1
    make "$t"
done
