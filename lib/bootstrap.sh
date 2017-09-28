#!bash

# Export all variables and functions
set +a

# Define variables
prog="${0##*/}"
prefix="${bootstrap%/lib/bootstrap.sh}"
bindir="$prefix/bin"
execdir="$prefix/lib"
confdir="$prefix/etc"

# Define defaults
searchdirs="$prefix/servers:$prefix/roles"

# Switch to prefix dir
cd "$prefix"

# Pathmunge bindir
if [[ ! "$PATH" =~ (^|:)"$bindir"(:|$) ]]; then
	PATH="$PATH:$bindir"
fi

# Read user-defined settings
if [[ -r "$confdir/settings.conf" ]]; then
	. "$confdir/settings.conf"
fi

# For each $searchdir, define a function that will run scripts in that dir
searchfuncs=()
IFS=:
for dir in $searchdirs; do
	func="${dir##*/}"
	func="${func%s}"
	searchfuncs+=("$func")
	source /dev/stdin <<-EOF
		$func() {
			if [[ -x "$dir/\$1" && -f "$dir/\$1" ]]; then
				if [[ -d "$dir/\$1.d" ]]; then
					export datadir="$dir/\$1.d"
				fi
				"$dir/\$1" "\${@:2}"
			else
				err "Could not find $func: %s" "\$1"
				return 1
			fi
		}
	EOF
done
unset IFS
unset dir
unset func

# Prints an info message to stdout
msg() {
	local message="$1"
	shift
	printf -- "$message\n" "$@"
}

# Prints a warning to stderr
warn() {
	msg "$@" >&2
}

# Prints an error to stderr
err() {
	msg "$@" >&2
}

# Prints an error to stderr and exits
die() {
	retval=1
	if [[ "$1" =~ [0-9]+ ]]; then
		retval="$1"
		shift
	fi

	err "$@"
	exit $retval
}

# Validates and normalizes options
validopts() {
	local o i opt arg shortopts longopts
	shortopts="$1"
	longopts=()
	retval=()
	opt=
	arg=
	shift

	while [[ "$1" != '--' ]]; do
		longopts+=("$1")
		shift
	done
	shift

	while [[ "$1" == -* ]]; do
		opt="$1"
		case "$opt" in
		  --)
			break
		  ;;
		  --*)
			if [[ "$opt" == *=* ]]; then
				arg="${opt#*=}"
				opt="${opt%%=*}"
			fi

			if [[ "${longopts[*]}" =~ ( |^)"${opt#--}":?( |$) ]]; then
				retval+=("$opt")
			else
				err "Unknown option: %s" "$opt"
				return 1
			fi

			if [[ "${longopts[*]}" == *${opt#--}:* ]]; then
				if [[ -n "$arg" ]]; then
					retval+=("$arg")
				elif (( $# > 1 )); then
					shift
					retval+=("$1")
				else
					err "Option requires argument: %s" "$opt"
					return 1
				fi
			fi
			shift
		  ;;
		  -*)
			for ((i=1; i<${#opt}; i++)); do
				o="${opt:i:1}"
				if [[ "$shortopts" == *$o* ]]; then
					retval+=("-$o")
				else
					err "Unknown option: %s" "-$o"
					return 1
				fi

				if [[ "$shortopts" == *$o:* ]]; then
					if (( i == ${#opt} - 1 )); then
						shift
						if (( $# )); then
							retval+=("$1")
						else
							err "Option requires argument: %s" "-$o"
							return 1
						fi
					else
						retval+=("${opt:i+1}")
						break
					fi
				fi
			done
			shift
		  ;;
		esac
	done
	retval+=("$@")
}

# Stop exporting variables and functions
set -a

