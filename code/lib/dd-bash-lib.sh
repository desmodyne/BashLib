# shellcheck shell=bash

# dd-bash-lib.sh
#
# DesmoDyne library of generic bash functions
#
# author  : stefan schablowski
# contact : stefan.schablowski@desmodyne.com
# created : 2018-07-16


# NOTE: this library is not meant to be executed;
# instead use functions in own scripts with e.g.
#   source <path to this library>/dd-bash-lib.sh
# if BashLib is installed using brew with custom tap:
#   source /usr/local/lib/dd-bash-lib.sh
# see also https://github.com/desmodyne/homebrew-tools

# no shell she-bang, but a shellcheck shell directive:
# https://github.com/koalaman/shellcheck/issues/581

# basic styleguide convention:
# https://google.github.io/styleguide/shell.xml
# styleguide exception: 'do' and 'then' are placed on new lines:
# https://google.github.io/styleguide/shell.xml?showone=Loops#Loops


# TODO: use named parameters ? https://stackoverflow.com/a/30033822
# TODO: use Bash Infinity Framework ?
#       https://invent.life/project/bash-infinity-framework
# TODO: add code location indicator to log messages ?
# TODO: review using 'local' for variable declaration
# TODO: be quiet unless --verbose / -v is passed
#       or set in ~/.dd-bash-lib.conf or DD_BASH_LIB_OPTIONS
# TODO: global flag to determine if BashLib was already sourced ?
# TODO: add color to output ? green OK, red ERROR, yellow FAIL / WARNING ?


# treat unset variables and parameters as error for parameter expansion:
# https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
# NOTE: this is a backup safety measure; globals set externally (i.e. by
# scripts using this library) are tested individually before they are used
set -o nounset


# define functions: http://stackoverflow.com/a/6212408


# -----------------------------------------------------------------------------
# test operating system is supported and configure various commonly used tools
#
# This functions restricts the supported environments to Linux and macOS and
# makes the GNU version of commonly used command line tools (grep, sed, etc.)
# available to BashLib users under unified global variables; on macOS, this is
# in addition to the BSD tool variants.
# It is most useful when features are required that GNU tools provide, but are
# not supported by their BSD version, especially extended regular expressions.
# In practice, this means calling e.g. grep from a shell script still resolves
# to the 'native' tool, i.e. GNU grep on Linux and BSD grep on macOS; however,
# using e.g. "${grep}" resolves to GNU grep on both Linux and macOS.
#
# NOTE: at this stage, this function does not test if any of the cmd line tools
# are actually available, neither the native version nor GNU tools on macOS;
# on macOS, you may install GNU command line tools using Homebrew with e.g.
#   brew install coreutils findutils grep gnu-sed
# under their usual names with a 'g' prefixed to each name; see also e.g.
#   https://brew.sh/
#   https://apple.stackexchange.com/a/88812
#
# Prerequisites:
#   operating system is Linux or macOS
# Globals:
#   OSTYPE - evaluated to determine current OS
#   grep   - set to  'grep' on Linux,  'ggrep' on macOS
#   sed    - set to   'sed' on Linux,   'gsed' on macOS
#   xargs  - set to 'xargs' on Linux, 'gxargs' on macOS
# Arguments:
#   None  - any arguments passed are silently ignored
# Returns:
#   0 if platform is supported, 1 otherwise
#
# Sample code:
#   # call the function without any parameters
#   configure_platform
#   # use -E to enable extended regular expressions
#   "${sed}" -E ...

# TODO: test if command line tools are actually available, fail if not ?

function configure_platform
{
    # http://stackoverflow.com/a/18434831

    # TODO: shellcheck reports SC2034 on macOS in the linux-*) case,
    # but not for the darwin*) case; review disabling and situation on Linux

    case "${OSTYPE}" in
        darwin*)
            echo 'configure platform: OK'
            grep='ggrep'
            sed='gsed'
            xargs='gxargs'
            ;;
        linux-*)
            echo 'configure platform: OK'
            # shellcheck disable=SC2034
            grep='grep'
            # shellcheck disable=SC2034
            sed='sed'
            # shellcheck disable=SC2034
            xargs='xargs'
            ;;
        *)
            msg='configure platform: ERROR'$'\n'
            msg+="unsupported operating system: ${OSTYPE}"
            echo "${msg}" >&2
            return 1
            ;;
    esac

    return 0
}


# -----------------------------------------------------------------------------
# extend path to other scripts or executables
#
# Test if all executables in <req_tools> are found in PATH; if not,
# successively append paths in <ext_paths> to PATH and try again.
#
# This functions is most useful to automatically handle different PATHs during
# development vs. production: In production, any scripts or executables used
# by a superscript are typically installed using a distribution package
# and (project or other, e.g. Linux / macOS system) tools are found in PATH.
# During development, this is not necessarily the case; e.g. subscripts used
# by a superscript might reside in the same folder as the superscript itself,
# where they are not found unless the path is extended by that folder.
#
# WARNING to developers: It is generally a bad practice to mix production
# and development environments on the same host: DO NOT install a production
# version of anything you are currently developing; the exact executables
# being used depend on the order of paths in PATH; this is a source of error.
#
# Prerequisites:
#   Bash 4.0 or later, uses arrays not available in earlier versions
# Globals:
#   possibly extends PATH by paths in <ext_paths>
# Arguments:
#   req_tools - string array with tool names required in PATH
#   ext_paths - string array with paths to add to PATH: paths already in PATH
#               won't be re-added and a message will be displayed; paths that
#               don't exist or are not folders will be ignored with a warning
# Returns:
#   0 if all tools were found in (possibly extended) PATH; 1 otherwise
#
# Sample code:
#   req_tools=('my_helper_script' 'vagrant' 'javac')
#   ext_paths=('/usr/local/bin' '<path to my scripts>' '/opt/vagrant/bin')
#   extend_path req_tools ext_paths

# TODO: does changing PATH have any side effects to calling script ?

function extend_path
{
    echo 'verify required executables are available in PATH:'

    if [ "${#}" -ne 2 ]
    then
        msg='ERROR: wrong number of arguments'$'\n'
        msg+='please see function code for usage and sample code'
        echo "${msg}" >&2
        return 1
    fi

    # test if first argument is an array:
    # https://stackoverflow.com/a/27254437
    # https://stackoverflow.com/a/26287272
    # http://fvue.nl/wiki/Bash:_Detect_if_variable_is_an_array
    if ! [[ "$(declare -p "${1}" 2> /dev/null)" =~ "declare -a" ]]
    then
        msg='ERROR: <req_tools> argument is not an array'$'\n'
        msg+='please see function code for usage and sample code'
        echo "${msg}" >&2
        return 1
    fi

    if ! [[ "$(declare -p "${2}" 2> /dev/null)" =~ "declare -a" ]]
    then
        msg='ERROR: <ext_paths> argument is not an array'$'\n'
        msg+='please see function code for usage and sample code'
        echo "${msg}" >&2
        return 1
    fi

    # pass arrays as function arguments:
    # https://stackoverflow.com/a/29379084
    #
    # there is plenty confusion around arrays
    # and function arguments in bash in general:
    # https://stackoverflow.com/q/16461656
    #
    # NOTE: underscore appended to variable name
    # to reduce the chance of bash warning
    #   local: warning: req_tools: circular name reference
    # that occurs when client code also uses
    # 'req_tools' as name for the variable
    # passed as argument to this function
    local -n req_tools_="${1}"
    local -n ext_paths_="${2}"

    # test if req tools array is empty
    if [ -z "${req_tools_[*]}" ]
    then
        return 0
    fi

    # add a dummy element to beginning of array for first loop
    # https://unix.stackexchange.com/a/395103
    ext_paths_=('dummy' "${ext_paths_[@]}")

    # associative array with key = tool name and
    # value = true if tool found, false otherwise
    declare -A found_tools_map=()

    # https://stackoverflow.com/a/8880633
    for ext_path in "${ext_paths_[@]}"
    do
        # test if first loop iteration
        if [ "${ext_path}" != 'dummy' ]
        then
            # test if path is already in PATH
            if [[ "${PATH}" = *"${ext_path}"* ]]
            then
                echo "  WARNING: path ${ext_path} is already in PATH; skip"
                continue
            fi

            # TODO: test if readable / executable ?
            if [ ! -d "${ext_path}" ]
            then
                echo "  WARNING: folder ${ext_path} does not exist; skip"
                continue
            fi

            echo "  append ${ext_path} to PATH and retry:"
            PATH="${PATH}:${ext_path}"
        fi

        for req_tool in "${req_tools_[@]}"
        do
            # test if req_tool is in array keys and its value is true
            # NOTE: due to set -o nounset, need
            # to work around key not existing:
            # https://stackoverflow.com/a/35353851
            # TODO: review this for one toolname being part of another
            if [[ "${!found_tools_map[*]}" == *"${req_tool}"* ]] &&
               [  "${found_tools_map[${req_tool}]}" = true ]
            then
                continue
            fi

            # https://stackoverflow.com/a/677212
            # https://github.com/koalaman/shellcheck/wiki/SC2230
            # https://linux.die.net/man/1/bash
            # search for 'command [-pVv] command'
            # TODO: align OK / FAIL in output over all lines
            echo -n "  ${req_tool}: "
            if [ -x "$(command -v "${req_tool}")" ]
            then
                echo 'OK'
                found_tools_map["${req_tool}"]=true
            else
                echo 'FAIL'
                found_tools_map["${req_tool}"]=false
            fi
        done

        all_tools_found=true

        # https://stackoverflow.com/a/3113285
        for req_tool in "${!found_tools_map[@]}"
        do
            if [ "${found_tools_map[${req_tool}]}" = false ]
            then
                all_tools_found=false
            fi
        done

        if [ "${all_tools_found}" = true ]
        then
            return 0
        fi
    done

    echo

    return 1
}


# -----------------------------------------------------------------------------
# get path to script configuration file from command line arguments
#
# NOTE: this function is only useful if the main script follows the convention
# to take a single parameter, the path to a main script configuration file
#
# Dependencies:
#   uses 'usage' function
# Globals:
#   ${#}, ${1} - evaluated to get arguments passed to script using this function
#   conf_file  - set to path to configuration file after function succeeds
# Arguments:
#   conf_file  - path to configuration file
# Returns:
#   0 if a valid path to configuration file was found in args, 1 otherwise
#
# Sample code:
#   # pass all arguments to main script on to this function
#   get_conf_file_arg "${@}"

# TODO: support more than one argument, pass on any further arguments ?
# TODO: try to use ~/.<script_name>.yaml or so if no config file is passed ?
# TODO: support symbolic link to configuration file

function get_conf_file_arg
{
    echo -n 'get configuration file command line argument: '

    if [ "${#}" -ne 1 ]
    then
        msg='ERROR'$'\n''wrong number of arguments'$'\n'$'\n'
        msg+="$(usage)"
        echo "${msg}" >&2
        return 1
    fi

    # http://stackoverflow.com/a/14203146
    # NOTE: this code seems overly complex for a single argument,
    # but easily be extended to support an arbitrary number of arguments
    while [ ${#} -gt 0 ]
    do
        key="$1"

        case "${key}" in
            # NOTE: must escape -?, seems to act as wildcard otherwise
            -\?|--help)
            echo 'HELP'; echo; usage; return 1 ;;

            *)
            if [ -z "${conf_file}" ]
            then
                conf_file="${1}"
            else
                msg='ERROR'$'\n''wrong number of arguments'$'\n'$'\n'
                msg+="$(usage)"
                echo "${msg}" >&2
                return 1
            fi
        esac

        # move past argument or value
        shift
    done

    # config file is a mandatory command line argument
    if [ -z "${conf_file}" ]
    then
        msg='ERROR'$'\n''wrong number of arguments'$'\n'$'\n'
        msg+="$(usage)"
        echo "${msg}" >&2
        return 1
    fi

    # http://tldp.org/LDP/Bash-Beginners-Guide/html/sect_07_01.html

    if [ ! -e "${conf_file}" ]
    then
        msg='ERROR'$'\n'"${conf_file}: Path not found"$'\n'
        echo "${msg}" >&2
        return 1
    fi

    if [ ! -f "${conf_file}" ]
    then
        msg='ERROR'$'\n'"${conf_file}: Path is not a file"$'\n'
        echo "${msg}" >&2
        return 1
    fi

    if [ ! -r "${conf_file}" ]
    then
        msg='ERROR'$'\n'"${conf_file}: File is not readable"$'\n'
        echo "${msg}" >&2
        return 1
    fi

    echo 'OK'

    return 0
}

# -----------------------------------------------------------------------------
# print help message with information on how to use a script
#
# NOTE: this function is only useful if the main script follows the convention
# to take a single parameter, the path to a main script configuration file
#
# Globals:
#   ${0} - evaluated to set name of main script in message
# Arguments:
#   None  - any arguments passed are silently ignored
# Returns:
#   always succeeds, returns 0
#
# Sample code:
#   usage

function usage
{
    # https://stackoverflow.com/q/192319
    # https://stackoverflow.com/a/965072
    script_name="${0##*/}"

    # NOTE: indentation added here for improved readability
    # is stripped by sed when message is printed
    read -r -d '' msg_tmpl << EOT
    Usage: %s <config file>

    mandatory arguments:
      config file           absolute path to configuration file

    optional arguments:
      -?, --help            print this help message
EOT

    # NOTE: printf strips trailing newlines
    # shellcheck disable=SC2059
    msg="$(printf "${msg_tmpl}" "${script_name}" | sed -e 's|^    ||g')"$'\n'

    echo "${msg}"

    return 0
}


# undo bash option changes so this library can be sourced
# from a live shell with changing the shell's configuration
# TODO: test if this works as expected
set +o nounset
