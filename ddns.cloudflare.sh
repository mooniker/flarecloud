PLUGIN_NAME="Cloudflare API v4"

source utils.sh
verbalize Using plugin for $PLUGIN_NAME...

# Required additional dependencies 
command -v curl >/dev/null 2>&1 || {
    echo >&2 "Please install `curl` for network data transfers.";
    exit 1;
}

_CF_API_BASE_URL="https://api.cloudflare.com/client/v4"

# RECORD_ID=
# https://api.cloudflare.com/#dns-records-for-a-zone-list-dns-records

# ZONE_ID=
# Get the Zone ID from: https://www.cloudflare.com/a/overview/<your-domain>

# AUTH_TOKEN=
# https://dash.cloudflare.com/${YOUR_ACCOUNT_ID}/profile/api-tokens

# ref:
# https://www.rohanjain.in/cloudflare-ddns/

print_help () {
    echo TODO help
}

# Params required by this plugin

# need either an API key (for service user) or email/auth token
if [ -z "${AUTH_TOKEN+xxx}" ]; then
    # DNS API token set to limited permissions preferred
    echo DNS API token requred. Use `--auth-token`.
    # exit 1
fi

_AUTH_HEADER="Authorization: Bearer $AUTH_TOKEN"
echo - Using HTTP authorization header for $PLUGIN_NAME

if [ "$DEBUG_MODE" = true ]; then
    command -v python >/dev/null 2>&1 || command -v jq >/dev/null 2>&1 || { echo >&2 "Please install `python` or 'jq' for for JSON parsing in debug mode."; exit 1; }
    echo Verifying API access...
    if [ "$IS_SIMULATED" = true ]; then
        echo Simulated: curl -X GET "$_CF_API_BASE_URL/user/tokens/verify" \
            -H "$_AUTH_HEADER" \
            -H "Content-Type:application/json"
    else
        curl -X GET "$_CF_API_BASE_URL/user/tokens/verify" \
            -H "$_AUTH_HEADER" \
            -H "Content-Type:application/json" \
            | python -m json.tool
    fi

    echo Checking DNS records...
    if [ "$IS_SIMULATED" = true ]; then
        echo Simulated: curl "$_CF_API_BASE_URL/zones/$ZONE_ID/dns_records" \
            -X GET \
            -H "$_AUTH_HEADER" \
            -H "Content-Type: application/json"
    else
        curl "$_CF_API_BASE_URL/zones/$ZONE_ID/dns_records" \
            -X GET \
            -H "$_AUTH_HEADER" \
            -H "Content-Type: application/json" \
            | python -m json.tool
    fi
fi

if [ -z "${RECORD_ID+xxx}" ]; then
    echo ...cancelled. Record identifier for $PLUGIN_NAME unspecified. Use \"--record-id\".
    exit 1
fi

JSON_UPDATE_PAYLOAD=$(cat <<EOF
{ "type": "$RECORD_TYPE",
  "name": "$RECORD_SET_NAME",
  "content": "$MY_IP",
  "ttl": $TTL,
  "proxied": ${IS_PROXIED:-false} }
EOF
)

if [ "$IS_SIMULATED" = true ]; then
echo Simulated: curl "$_CF_API_BASE_URL/zones/$ZONE_ID/dns_records/$RECORD_ID" \
        -X PUT \
        -H "Content-Type: application/json" \
        -H "$_AUTH_HEADER" \
        --data "$JSON_UPDATE_PAYLOAD"
else
    RESPONSE=$(
        curl "$_CF_API_BASE_URL/zones/$ZONE_ID/dns_records/$RECORD_ID" \
        -X PUT \
        -H "Content-Type: application/json" \
        -H "$_AUTH_HEADER" \
        --data "$JSON_UPDATE_PAYLOAD" \
        --silent
    )

    STATUS=$(echo $RESPONSE | grep -o '"success":[^,"]*')
    
    if [ "$STATUS" != '"success":true' ]; then
        write_to_logfile FAIL
        echo - Request: $JSON_UPDATE_PAYLOAD
        echo - Response: $RESPONSE
        echo ...FAILED.
        exit 1
    fi

fi
