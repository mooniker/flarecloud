
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