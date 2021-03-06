#!/bin/sh

# Relatively basic/safe defaults to use for unspecified params
RECORD_TYPE_DEFAULT=A
TTL_DEFAULT=300

# for developer use to force verbosity
# IS_SIMULATED=true
# _FORCE_VERBAL=true
# _FORCE_DEBUG=true

# Required dependencies
command -v curl >/dev/null 2>&1 || {
    echo >&2 "Please install `curl` for network data transfers.";
    exit 1;
}

IPV4_REGEX_PATTERN="([0-9]{1,3}[\.]){3}[0-9]{1,3}"
_CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_SELF=${0##*/} # `./ddns.sh` => `ddns.sh`
_SELF=${_SELF%.*} # `./ddns.sh => ddns` 
LOG_FILE_PATH_DEFAULT=$_CURRENT_DIR/$_SELF.log
COMMENT_DEFAULT="$_SELF"

print_help () {
    echo "Usage: $0 help" 1>&2;
    echo "subcommands" 1>&2;
    echo "          update" 1>&2;
    echo "          list" 1>&2;
    echo "          help" 1>&2;
}

print_update_help () {
    echo TODO... $1
}

# function to print only in verbose mode
verbalize () {
    if [ "${_FORCE_VERBAL:-$IS_VERBOSE}" = true ]; then
        echo "- $@"
    fi
}

# function print only in debug mode
debug_echo () {
    if [ "${_FORCE_DEBUG:-$DEBUG_MODE}" = true ]; then
        echo "debug- $@"
    fi
}

print_json () {
    echo $@
}

write_to_logfile () {
    # $1 is type of action, i.e. UPDATE, NO_UPDATE, etc
    local ENTRY_TYPE="$1${IS_SIMULATED:+_SIMULATED}"
    local LOG_OUTPUT="$PLUGIN;$RECORD_SET_NAME;$MY_IP;$ENTRY_TYPE;$(date);$COMMENT"
    if [ "$NO_LOG" != true ]; then
        verbalize Updating log file...
        echo $LOG_OUTPUT >> $LOG_FILE_PATH
        verbalize Written to log: $(tail -n 1 $LOG_FILE_PATH)
    fi
    echo $LOG_OUTPUT
}

check_for_last_update () {
    # $1 is custum status pattern, e.g. `UPDATE`
    verbalize Checking last update...
    local LAST_SUCCESSFUL_UPDATE_REGEX="^$PLUGIN;$RECORD_SET_NAME;$IPV4_REGEX_PATTERN;${1:-UPDATE_OK};.*$"
    # grep params -ohE are --only-matching --no-filename --extended-regex
    local LAST_SUCCESSFUL_UPDATE=$(grep -ohE $LAST_SUCCESSFUL_UPDATE_REGEX $LOG_FILE_PATH | tail -n 1)
    if [ "${LAST_SUCCESSFUL_UPDATE:-false}" = false ]; then
        verbalize Found no record of successful update with $RECORD_SET_NAME. Update triggered...
        IS_FORCED=true
        return # to main function to source plugin script
    fi
    local MY_PREV_IP=$(echo $LAST_SUCCESSFUL_UPDATE | grep -ohE $IPV4_REGEX_PATTERN)
    if [ "$MY_IP" != "$MY_PREV_IP" ]; then
        verbalize IP address change detected: $LAST_SUCCESSFUL_UPDATE
        verbalize Update triggered...
        IS_FORCED=true
        return # to main function to source plugin script
    fi
    verbalize DNS record is up to date.
    if [ "$IS_FORCED" = true ]; then
        verbalize Update unneeded, but requested...
    else
        verbalize No update needed.
        write_to_logfile NO_UPDATE
        exit
    fi
}

look_up_my_ip () {
    verbalize Looking up my IP address...
    # Install `dig` via `dnsutils` for  IP lookup.
    command -v dig >/dev/null 2>&1 || { echo >&2 "Please install `dig` via `dnsutils` for IP lookup."; exit 1; }
    command -v dig &> /dev/null && {
        verbalize ...and using OpenDNS...
        MY_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)
    } || {
        verbalize ...and using Google...
        MY_IP=$(dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com | grep --only-matching --no-filename --extended-regex $IPV4_REGEX_PATTERN)
    } || {
        verbalize ...and using ipify.org...
        MY_IP=$(curl --silent https://api.ipify.org)
    } || {
        echo "Could not get current IP."
        exit 1
    }
    # GOOGLE_IPV6=`dig -6 TXT +short o-o.myaddr.l.google.com @ns1.google.com`
    verbalize ...and it is $MY_IP.
}

print_available_provider_plugins () {
    local _PLUGIN_RE="$_SELF\..+\.sh"
    echo $(ls -l | grep -ohE $_PLUGIN_RE)
}

check_for_provider_plugin () {
    PLUGIN=$1
    if [ "$PLUGIN" == "" ]; then
        echo DNS provider unspecified.
        exit 1
    fi
    local PLUGIN_REGEX="$_SELF\.$PLUGIN\.sh"
    # set the plugin path for sourcing later
    PLUGIN_PATH=$(ls | grep -E $PLUGIN_REGEX)
    verbalize Plugin ${PLUGIN_PATH:-not} found.
    if [ "$PLUGIN_PATH" == "" ]; then
        echo Provider \"$PLUGIN\" unsupported or plugin not found.
        exit 1
    else
        verbalize Using $PLUGIN_PATH plugin...
    fi
}

update_subcommand () {
    if [ "$1" == "" ]; then
        print_update_help $SUBCOMMAND
        exit
    fi
    # POSITIONAL=()
    local ARGSV=()
    while [[ $# -gt 0 ]]; do
        ARGSV+=("$1") # save it in an array for later
        case $1 in
            -n | --name | --record-set-name | --domain-name )
                shift # to param
                RECORD_SET_NAME=$1
                ;;
            -r | --record-type )
                shift # to param
                RECORD_TYPE=$1
                ;;
            -z | --zone-id | --hosted-zone-id )
                shift # to param
                ZONE_ID=$1
                ;;
            --record-id )
                shift # to param
                RECORD_ID=$1
                ;;
            --ttl | --time-to-live )
                shift # to param
                TTL=$1
                ;;
            -m | --ip | --ip-address | --my-ip | --my-ip-address )
                shift # to param
                MY_IP=$1
                ;;
            -l | --log-file | --log-file-path )
                shift # to param
                LOG_FILE_PATH=$1
                ;;
            --auth-token | --token | -t )
                shift # to param
                AUTH_TOKEN=$1
                ;;
            --auth-email | --email )
                shift # to param
                AUTH_EMAIL=$1
                ;;
            --comment )
                shift # to param
                COMMENT=$1
                ;;
            --credentials-file )
                shift
                CREDENTIALS_FILE=$1
                ;;
            --config-file | -c )
                shift
                CONFIG_FILE=$1
                ;;
            --named-profile )
                shift
                NAMED_PROFILE=$1
                ;;
            -d | --debug ) # boolean, no shift
                DEBUG_MODE=true
                ;;
            -f | --force | --force-update ) # boolean, no shift
                IS_FORCED=true
                ;;
            --no-log ) # boolean, no shift
                NO_LOG=true
                ;;
            -6 | --ipv6 | --ip-v6 ) # boolean, no shift
                IPV6=true
                RECORD_TYPE=AAAA
                ;;
            -i | --interactive ) # boolean, no shift
                INTERACTIVE=true
                ;;
            -s | --sim | --simulate ) # boolean, no shift
                IS_SIMULATED=true
                ;;
            -v | --verbose ) # boolean, no shift
                echo verbose
                IS_VERBOSE=true
                ;;
            --proxied ) # boolean, no shift
                IS_PROXIED=true
                ;;
            * ) # unknown option
            # POSITIONAL+=("$1") # save it in an array for later
            # shift # to next argument
            echo Unknown argument: $1
            exit 1
            ;;
        esac
        shift # to next arg
    done # while loop
    # set -- "${POSITIONAL[@]}" # restore positional parameters
    # echo Positional: $POSITIONAL
    if [ "$DEBUG_MODE" = true ]; then
        echo $SUBCOMMAND $PLUGIN args: ${ARGSV[*]}
    fi
}

SUBCOMMAND=${1:-help}
shift # to first arg
verbalize Invoking $SUBCOMMAND subcommand...

case "$SUBCOMMAND" in
    list | ls )
        print_available_provider_plugins
        exit
        ;;
    help | h | -h | --help )
        print_help
        exit
        ;;
    update ) # Process update options
        check_for_provider_plugin $1
        shift # past plugin arg
        update_subcommand $@
        ;;
    * )
        echo Huh?
        print_help
        exit 1
esac

debug_echo Debug mode is enabled.
verbalize Being chatty as requested.
verbalize Using \"$PLUGIN\" as DNS provider...
verbalize Assuming defaults for unspecified params...

# some defaults to use (if not specified)
if [ -z "${LOG_FILE_PATH+xxx}" ]; then
    LOG_FILE_PATH=$LOG_FILE_PATH_DEFAULT
fi

verbalize Log file path set to \"$LOG_FILE_PATH\".

if [ -z "${RECORD_TYPE+xxx}" ]; then
    RECORD_TYPE=$RECORD_TYPE_DEFAULT
fi

verbalize Record type set to \"$RECORD_TYPE\".

if [ -z "${TTL+xxx}" ]; then
    TTL=$TTL_DEFAULT
fi

verbalize Time to live set to $TTL seconds.

if [ -z "${MY_IP+xxx}" ]; then
    look_up_my_ip
fi

# check_required_arg () {
#     TODO
# }

if [ -z "${RECORD_SET_NAME+xxx}" ]; then
    if [ "$INTERACTIVE" = true ]; then
        read -p "Record set name (i.e. <subdomain>.<domain>.<tld>): " RECORD_SET_NAME
    else
        echo Record set name unspecified.
        exit 1
    fi
fi

verbalize Record set name set to \"$RECORD_SET_NAME\".

if [ -z "${ZONE_ID+xxx}" ]; then
    if [ "$INTERACTIVE" = true ]; then
        read -p "Zone id: " ZONE_ID
    else
        echo Zone id unspecified.
        exit 1
    fi 
fi

verbalize Zone id set to \"$ZONE_ID\".

check_for_last_update UPDATE_OK

# Update records via provider
if [ "$IS_FORCED" = true ]; then
    echo "Updating"
    source $PLUGIN_PATH || {
        debug_echo JSON update payload: $JSON_UPDATE_PAYLOAD
        write_to_log ERROR;
        echo >&2 "No joy.";
        exit 1;
    }
fi

# echo $?

echo where

if [ "$?" != "0" ]; then
    echo Failed $?
    debug_echo JSON update payload: $JSON_UPDATE_PAYLOAD
    write_to_logfile FAIL
    exit 1
fi

debug_echo JSON update payload: $JSON_UPDATE_PAYLOAD
write_to_logfile UPDATE