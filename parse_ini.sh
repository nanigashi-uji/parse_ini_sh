#!/bin/bash
# -*- mode: shell-script ; -*-
#
#    parse_ini.sh
#       ---- Read .ini file and output with shell variable definitions.
#
function parse_ini () {
    # Prepare Help Messages
    local funcstatus=0;
    local echo_usage_bk=$(declare -f echo_usage)
    local sed_list_section_bk=$(declare -f sed_list_section)
    local cleanup_bk=$(declare -f cleanup)
    local tmpfiles=()
    local tmpdirs=()

    function echo_usage () {
        if [ "$0" == "${BASH_SOURCE:-$0}" ]; then
            local this=$0
        else
            local this="${FUNCNAME[1]}"
        fi
        echo "[Usage] % $(basename ${this}) -list     file [files ...]"                                  1>&2
        echo "        % $(basename ${this}) [options] file [files ...]"                                  1>&2
        echo ""                                                                                          1>&2
        echo "[Options]"                                                                                 1>&2
        echo "    -l,--list                       : List sections "                                      1>&2
        echo "    -S,--sec-select       name      : Section name to select"                              1>&2
        echo "    -T,--sec-select-regex expr      : Section reg. expr. to select"                        1>&2
        echo "    -V,--variable-select name       : variable name to select"                             1>&2
        echo "    -W,--variable-select-regex expr : variable reg. expr. to select"                       1>&2
        echo "    -L,--local                      : Definition as local variables (B-sh)"                1>&2
        echo "    -e,--env                        : Definition as enviromnental variables"               1>&2
        echo "    -q,--quot                       : Definition by quoting with double/single-quotation." 1>&2
        echo "    -c,--csh,--tcsh                 : Output for csh statement (default: B-sh)"            1>&2
        echo "    -b,--bsh,--bash                 : Output for csh statement (default)"                  1>&2
        echo "    -s,--sec-prefix                 : add prefix: 'sectionname_' to variable names. "      1>&2
        echo "    -v,--verbose                    : Verbose messages "                                   1>&2
        echo "    -h,--help                       : Show Help (this message)"                            1>&2
        echo ""                                                                                          1>&2
        echo " --------------------------------------------------------------------------"               1>&2
        echo ""                                                                                          1>&2
        echo "[.ini file format]"                                                                        1>&2
        echo ""                                                                                          1>&2
        echo " [section] modulename/'global' "                                                           1>&2
        echo " parameter_name=value"                                                                     1>&2
        echo ""                                                                                          1>&2
        echo " parameter_name:"                                                                          1>&2
        echo "     No 4-spaces/tabs before variable_name; Otherwise it will be treated"                  1>&2
        echo "     as the following contents of its previous line."                                      1>&2
        echo ""                                                                                          1>&2
        echo " value:"                                                                                   1>&2
        echo "     it will be quoted by \"...\" or '...' by -q/--quot option"                            1>&2
        echo ""                                                                                          1>&2
        echo " The text from [#;] to the end of line will be treated as comment.(Ignored)"               1>&2
        echo ""                                                                                          1>&2 
        echo " If backslash (\) exists at the end of line, the following line will be treated"           1>&2 
        echo " as continous line. If line starts with four spaces/tabs, it will be treated as the"       1>&2
        echo " continous line of the preveous line"                                                      1>&2 
        echo ""                                                                                          1>&2 
        return
    }

    function sed_list_section () {
        local inifile="$1"
        if [ ! -f "${inifile}" ]; then
            if [ ${verbose:-0} -ne 0 ]; then
                echo "File not exists or not usual file: ${inifile}" 1>&2
            fi
            return 1
        fi
        if [ ${verbose:-0} -ne 0 ]; then
            echo "# Section in file: ${inifile}" 1>&2
        fi
        ${SED:-sed} ${sedopt:--E} -n -e ':begin
$!N;s/[#;]([^[:space:]]|[[:blank:]])*([^\\[:space:]]|[[:blank:]])(\n)/\3/;s/[#;]([^[:space:]]|[[:blank:]])*(\\)(\n)/\2\3/;$s/[#;]([^[:space:]]|[[:blank:]])*$//;/(\\\n|\n[[:blank:]]{4})/ { s/[[:blank:]]*(\\\n|\n[[:blank:]]{4})[[:blank:]]*/ /;t begin
};/^[[:blank:]]*\n/ D;/\n[[:blank:]]*$/ {s/\n[[:blank:]]*$//;t begin
};/^\[([^[:space:]]|[[:blank:]])*\]/!D;s/\[[[:blank:]]*//;s/[[:blank:]]*\]([^[:space:]]|[[:blank:]])*//;P;D' "${inifile}" || return 1
        return 0
    }


    local hndlrhup_bk=$(trap -p SIGHUP)
    local hndlrint_bk=$(trap -p SIGINT)
    local hndlrquit_bk=$(trap -p SIGQUIT)
    local hndlrterm_bk=$(trap -p SIGTERM)

    trap -- 'cleanup ; kill -1  $$' SIGHUP
    trap -- 'cleanup ; kill -2  $$' SIGINT
    trap -- 'cleanup ; kill -3  $$' SIGQUIT
    trap -- 'cleanup ; kill -15 $$' SIGTERM

    function cleanup () {

        # removr temporary files and directories
        if [ ${#tmpfiles} -gt 0 ]; then
            rm -f "${tmpfiles[@]}"
        fi
        if [ ${#tmpdirs} -gt 0 ]; then
            rm -rf "${tmpdirs[@]}"
        fi

        # Restore  signal handler
        if [ -n "${hndlrhup_bk}"  ] ; then eval "${hndlrhup_bk}"  ;  else trap --  1 ; fi
        if [ -n "${hndlrint_bk}"  ] ; then eval "${hndlrint_bk}"  ;  else trap --  2 ; fi
        if [ -n "${hndlrquit_bk}" ] ; then eval "${hndlrquit_bk}" ;  else trap --  3 ; fi
        if [ -n "${hndlrterm_bk}" ] ; then eval "${hndlrterm_bk}" ;  else trap -- 15 ; fi

        # Restore functions

        unset sed_list_section
        test -n "${sed_list_section_bk}" && eval ${sed_list_section_bk%\}}" ; }"

        unset echo_usage
        test -n "${echo_usage_bk}" && eval ${echo_usage_bk%\}}" ; }"

        unset cleanup
        test -n "${cleanup_bk}" && eval ${cleanup_bk%\}}" ; }"
    }

    # Analyze command line options
    local opt=0
    local secprefix=0
    local aslocalvar=0
    local forcsh=0
    local forcequoat=0
    local asenvvar=0
    local args=()
    local verbose=0
    local secselexps=()
    local varselexps=()
    local secselexps2=()
    while [ ${#} -gt 0 ] ; do
        case "$1" in
            -c|--csh)
                local forcsh=1
                shift
                ;;
            -q|--quot)
                local forcequoat=1
                shift
                ;;
            -l|--list)
                local opt=1
                shift
                ;;
            -L|--local)
                local aslocalvar=1
                shift
                ;;
            -e|--env*)
                local asenvvar=1
                shift
                ;;
            -s|--sec-prefix)
                local secprefix=1
                shift
                ;;
            -v|--verbose)
                local verbose=1
                shift
                ;;
            -h|--help)
                echo_usage
                cleanup
                return 0
                ;;

            -S|--sec-select)
                shift
                [ $# -le 0 ] && { echo_usage ; cleanup ; return 1 ; }
                local secselexps=(  "${secselexps[@]}" "$(${SED:-sed} ${sedopt:--E}                          -e 's/([\\.*\^$()])/\\\1/g' <<< "$1")" )
                local secselexps2=( "${secselexps2[@]}" "$(${SED:-sed} ${sedopt:--E} -e 's/[^[:alnum:]_]/_/g' -e 's/([\\.*\^$()])/\\\1/g' <<< "$1")" )
                shift
                ;;
            -T|--sec-select-regex)
                shift
                [ $# -le 0 ] && { echo_usage ; cleanup ; return 1 ; }
                local secselexps=( "${secselexps[@]}" "$1" )
                local secselexps2=( "${secselexps2[@]}" "$(${SED:-sed} ${sedopt:--E} -e 's/[^[:alnum:]_\\.*\^$()]/_/g' <<< "$1")" )
                shift
                ;;
            -V|--variable-select)
                shift
                [ $# -le 0 ] && { echo_usage ; cleanup ; return 1 ; }
                local varselexps=( "${varselexps[@]}" "$(${SED:-sed} ${sedopt:--E} -e 's/[^[:alnum:]_]/_/g' -e 's/([\\.*\^$()])/\\\1/g' <<< "$1")" )
                shift
                ;;
            -W|--variable-select-regex)
                shift
                [ $# -le 0 ] && { echo_usage ; cleanup ; return 1 ; }
                local varselexps=( "${varselexps[@]}" "$(${SED:-sed} ${sedopt:--E} -e 's/[^[:alnum:]_\\.*\^$()]/_/g' <<< "$1")" )
                shift
                ;;
            *)
                local args=( "$1" "${args[@]}" )
                shift
                ;;
        esac
    done

    case ${OSTYPE} in
        darwin)
            local sedopt="-E"
            ;;
        *)
            local sedopt="-E"
            ;;
    esac

    local scriptpath="${BASH_SOURCE:-$0}"
    local scriptdir="$(dirname "${scriptpath}")"
    if [ "$0" == "${BASH_SOURCE:-$0}" ]; then
        local this="$(basename "${scriptpath}")"
    else
        local this="${FUNCNAME[0]}"
    fi

#    local tmpdir0=$(mktemp -d "${this}.tmp.XXXXXX" )
#    local tmpdirs=( "${tmpdirs[@]}" "${tmpdir0}" )
#    local tmpfile0=$(mktemp   "${this}.tmp.XXXXXX" )
#    local tmpfiles=( "${tmpfiles[@]}" "${tmpfile0}" )

    if [ ${opt} -eq 1 ]; then
        if [ ${#args[@]} -le 0 ]; then
            if [ ${verbose:-0} -ne 0 ]; then
                echo_usage
            fi
            cleanup
            return 1
        fi
        local inifile=
        for inifile in "${args[@]}"; do
            sed_list_section "${inifile}" || local funcstatus=1
        done
    elif [ ${#args[@]} -lt 1 ]; then
        if [ ${verbose:-0} -ne 0 ]; then
            echo "Not enough arguments" 1>&2
        fi
        local funcstatus=1
        echo_usage
    else

        local sec_expr=
        local inifile=
        local list_sections=()
        for inifile in "${args[@]}"; do
            local list_sections=( "${list_sections[@]}" "$(sed_list_section "${inifile}")" )
        done

        for sec_expr in "${secselexps[@]}"; do
            if ${GREP:-grep} -q -e "^${sec_expr}\$" <<< "${list_sections[@]}" ; then
                :
            else
                if [ ${verbose:-0} -ne 0 ]; then
                    echo "No section will be selected by : ${sec_expr}" 1>&2
                fi
                local funcstatus=1
            fi
        done

        local inifile=

        local secprefixexp=""
        if [ ${secprefix:-0} -ne 0 ]; then
            local secprefixexp='\4'
        fi

        local vardefsep="="
        local vardefprefix=""
        if [ ${forcsh:-0} -ne 0 ]; then
            if [ ${asenvvar:-0} -ne 0 ]; then
                local vardefprefix="setenv "
                local vardefsep=" "
            else
                local vardefprefix="set "
            fi
        elif [ ${aslocalvar} -ne 0 ]; then
            local vardefprefix="local "
        elif [ ${asenvvar:-0} -ne 0 ]; then
            local vardefprefix="export "
        fi

        local varvalexp=''
        if [ ${forcequoat:-0} -ne 0 ]; then
            local varvalexp='/^".*"$/!s/^(.*)$/"\1"/g;/^('"'"'.*'"'"'|".*")$/!s/^(.*)$/'"'"'\1'"'"'/g;'
        fi

        local sec_address='/^.*(\n)/'
        if [ ${#secselexps[@]} -gt 0 ]; then
            local sec_address="/^($(IFS=\|; echo "${secselexps[*]}"))(\n)/"
        fi

        local varseladdr=''
        if [ ${#varselexps[@]} -gt 0 ]; then
            if [ ${secprefix:-0} -ne 0 ]; then
                if [ ${#secselexps2[@]} -gt 0 ]; then
                    local sec_expr="($(IFS=\|; echo "${secselexps2[*]}"))_"
                else
                    local sec_expr="([^[:blank:]]+)_"
                fi
                local varseladdr="/^${vardefprefix}(${sec_expr}$(IFS=\|; echo "${varselexps[*]}"))${vardefsep}([^[:space:]]|[[:blank:]])*;(\n)/"
            else
                local varseladdr="/^${vardefprefix}($(IFS=\|; echo "${varselexps[*]}"))${vardefsep}([^[:space:]]|[[:blank:]])*;(\n)/"
            fi
        fi

        local inifile=
        for inifile in "${args[@]}"; do
            
            if [ ! -f "${inifile}" ];then
                if [ ${verbose:-0} -ne 0 ]; then
                    echo "File not exists or not usual file: ${inifile}" 1>&2
                fi
                local funcstatus=1
                continue
            fi
            if [ ${verbose:-0} -ne 0 ]; then
                echo "# Variable definitions: ${inifile}" 1>&2
            fi

            ${SED:-sed} ${sedopt:--E} -e '1 {H;x;s/^([^[:space:]]|[[:blank:]])*(\n)([^[:space:]]|[[:blank:]])*$/global\2global_/g;x;};:begin
$!N;s/[#;]([^[:space:]]|[[:blank:]])*([^\\[:space:]]|[[:blank:]])(\n)/\3/;s/[#;]([^[:space:]]|[[:blank:]])*(\\)(\n)/\2\3/;$s/[#;]([^[:space:]]|[[:blank:]])*$//;/(\\\n|\n[[:blank:]]{4})/ {s/[[:blank:]]*(\\\n|\n[[:blank:]]{4})[[:blank:]]*/ /;t begin
};/^[[:blank:]]*\n/ D;/\n[[:blank:]]*$/{s/\n[[:blank:]]*$//;t begin
};/^([^[:space:]]|[[:blank:]])*\[([^[:space:]]|[[:blank:]])*\]/{s/^([^[:space:]]|[[:blank:]])*\[(([^[:space:]]|[[:blank:]])*)\](([^[:space:]]|[[:blank:]])*)(\n)/\2\6/g;s/^[[:blank:]]*//g; s/[[:blank:]]*(\n)/\1/g;h;x;s/(\n)([^[:space:]]|[[:blank:]])*$//;s/([^[:alnum:]_]|$)/_/g;x;H;x;s/(([^[:space:]]|[[:blank:]])*)(\n)(([^[:space:]]|[[:blank:]])*)(\n)(([^[:space:]]|[[:blank:]])*)$/\4\3\1/;x;D;};x;'"${sec_address}"'!{x;D;};x;/^(([^[:space:]=]|[[:blank:]])*)=(([^[:space:]]|[[:blank:]])*)/ {H;s/(([^[:space:]=]|[[:blank:]])*)=.*$/\1/g;s/^[[:blank:]]*//;s/[[:blank:]]*$//;s/[^[:alnum:]_]/_/g;'"${varvalexp}"'H;g;s/^(([^[:space:]]|[[:blank:]])*\n){2}//;s/(\n([^[:space:]]|[[:blank:]])*){2}$//;s/^([^[:space:]=]|[[:blank:]])*=//g;G;s/^(([^[:space:]]|[[:blank:]])*\n)(([^[:space:]]|[[:blank:]])*\n)(([^[:space:]]|[[:blank:]])*\n)(([^[:space:]]|[[:blank:]])*\n)(([^[:space:]]|[[:blank:]])*\n)/\1\5\9/;s/^(([^[:space:]]|[[:blank:]])*\n)(([^[:space:]]|[[:blank:]])*\n)(([^[:space:]]|[[:blank:]])*)(\n)(([^[:space:]]|[[:blank:]])*)$/\1\3\8\7\5/;s/^(([^[:space:]]|[[:blank:]])*)(\n)(([^[:space:]]|[[:blank:]])*)(\n)(([^[:space:]]|[[:blank:]])*)(\n([^[:space:]]|[[:blank:]])*)$/'"${vardefprefix}${secprefixexp}"'\7'"${vardefsep}"'\1;\9/;x;s/(\n([^[:space:]]|[[:blank:]])*){3}$//;x;'"${varseladdr}"'P;};D' "${inifile}"
        done
    fi
    
    # clean up
    cleanup
    local funcstatus=1
    return ${funcstatus}
}

if [ "$0" == ${BASH_SOURCE:-$0} ]; then
    parse_ini "$@"
fi
