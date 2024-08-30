selector=$(echo "$1" | tr '[:upper:]' '[:lower:]')
data=$2
HETZNER_API_KEY=$3
domain=$4

api="https://dns.hetzner.com/api/v1"

get () {
	get_res=$(curl -s "${api}/$1" -H "Auth-API-Token: ${HETZNER_API_KEY}")
}

update () {
	update_res=$( curl -s -o /dev/null -w "%{http_code}" -X "PUT" "${api}/$1" \
		-H "Content-Type: application/json" \
		-H "Auth-API-Token: ${HETZNER_API_KEY}" \
		--json "$2" )
}

create () {
	create_res=$( curl -s -o /dev/null -w "%{http_code}" -X "POST" "${api}/$1" \
		-H "Content-Type: application/json" \
		-H "Auth-API-Token: ${HETZNER_API_KEY}" \
		--json "$2" )
}

get "zones"

zone_id=""

while read -r zone
do
	name=$(echo "$zone" | jq -r ".name")
	if [ "$name" = "$domain" ]; then
		zone_id=$(echo "$zone" | jq -r .id)
	fi
done < <(echo "$get_res" | jq -c '.zones[]')

if [ -z "$zone_id" ]; then
	exit 1
fi

get "records?zone_id=${zone_id}"

record_id=""

while read -r record
do
	name=$(echo "$record" | jq -r ".name")
	if [ "$name" = "$selector" ]; then
		record_id=$(echo "$record" | jq -r .id)
	fi
done < <(echo "$get_res" | jq -c '.records[]')

payload="$( jq -n \
		--arg sel "$selector" \
		--arg zid "$zone_id" \
		--arg value "$data" \
		'{"name": $sel, "ttl": 7200, "type": "TXT", "value": $value, "zone_id": $zid}' )"

if [ -z "$record_id" ]; then
	create "records" "$payload"
	if ! [[ $create_res == 2* ]]; then
		exit 1
	fi
else
	update "records/${record_id}" "$payload"
	if ! [[ $update_res == 2* ]]; then
		exit 1
	fi
fi

