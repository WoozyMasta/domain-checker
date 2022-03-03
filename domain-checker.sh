#!/usr/bin/env bash
# MIT License
# Copyright (c) 2022 Maxim Levchenko aka WoozyMasta
# domain-checker - commandline utility to check availability of domain names

set -euo pipefail

# Settings
: "${WORDS_FILE:=${1:-words.txt}}"
: "${ZONES_FILE:=${2:-}}"
: "${OUTPUT_FILE:=${3:-}}"
: "${CHECK_ZONES:=true}"
: "${DNS_SERVERS:=}"
: "${THREADS_LIMIT:=$(nproc)}"
: "${SOFT_THREADING:=true}"

# Constants
declare -a dependecies=('dig' 'whois' 'pv')
declare -a zones=('net' 'org' 'com' 'io' 'tech' 'pro' 'site')
declare -a dns=('1.1.1.1' '8.8.8.8' '1.0.0.1' '8.8.4.4')
whois_regex='(status:\s*available)|(domain\s*)?(has\s*)?no(t|thing)?\s*'
whois_regex+='(object|match|found|available|data|regi|entri)'


# Defs
check-whois() {
  local whois cnt zone="$1"
  whois="$(whois -H "$zone" | grep -ioP 'whois:\s*\K.*')"

  if ! whois -H "$whois" &>/dev/null; then
    cnt="$(LANG=en whois -H "$whois" | grep -c 'TLD has no whois' || true )"
    if [ "$cnt" -ne 0 ]; then
      >&2 echo "Zone '${zones[i]}' unsuported, has no whois"
      return 1
    fi
  fi
}

check-domain() {
  local cnt ip domain="$1"

  ip="${dns[(( RANDOM % ${#dns[@]} ))]}"
  if [ -z "$(dig @"$ip" +keepopen +short -q "$domain" -t SOA)" ]; then

    cnt="$(whois -H "$domain" | grep -ciE "$whois_regex" || true)"
    if [ "$cnt" -ne 0 ]; then
      echo "$domain" >&"$fd"
    fi
  fi
}

fail() { >&2 printf 'Error: %s\n' "$@"; exit 1; }

usage() {
  cat << USAGE

domain-checker - commandline utility to check availability of domain names for different zones

Usage:
  domain-checker [words file] [zones file] [output file]
  <vars> domain-checker [words file] > [output file]

This utility checks if a domain can be registered for all combinations of words and zones.
First it checks for the presence of a SOA record in the DNS and, if not, it checks the whois of the domain.
If the domain is available for registration, it will be saved as a result of the work.

Variables:

[ variable name = "default value" (positional arg) - description ]

WORDS_FILE="$WORDS_FILE" (1) - File with words to search for a domain names
ZONES_FILE="$ZONES_FILE" (2) - Zone name file (optional)
OUTPUT_FILE="$OUTPUT_FILE" (3) - File where available domain names will be saved (optional)
CHECK_ZONES="$CHECK_ZONES" - Check zones for whois server (optional)
DNS_SERVERS="$DNS_SERVERS" - Comma-separated list of custom DNS servers to check for SOA records
THREADS_LIMIT="$THREADS_LIMIT" - Number of threads (optional)
SOFT_THREADING="$SOFT_THREADING" - If enabled, threads are executed for the zone loop, otherwise global threads are used (optional)

https://github.com/WoozyMasta/domain-checker

USAGE
}

# Main
for cmd in "${dependecies[@]}"; do
  command -v "$cmd" &>/dev/null || fail "Required command '$cmd' not found"
done

[ "${1:-}" == '--help' ] || [ "${1:-}" == '-h' ] && usage
[ -z "${1:-}" ] && [ ! -f "$WORDS_FILE" ] && usage

[ -f "$WORDS_FILE" ] || fail "Words '$WORDS_FILE' file not exists"

if [ -n "$ZONES_FILE" ]; then
  if [ -f "$ZONES_FILE" ]; then
    mapfile -t zones < <(grep -v '^#\|^$' "$ZONES_FILE" | sort -u)
  else
    fail "Zones '$ZONES_FILE' file not exists"
  fi
fi

if [ -n "$DNS_SERVERS" ]; then
  IFS=', ' read -r -a dns <<< "$DNS_SERVERS"
  >&2 printf '%s' \
    "Validation of SOA records will be performed using custom DNS servers:"
  printf ' %s,' "${dns[@]}" | >&2 sed 's/,$/./'; >&2 echo
fi

if [ "${CHECK_ZONES,,}" == true ]; then
  >&2 echo 'Check domain zones availability'
  for i in "${!zones[@]}"; do
    check-whois "${zones[i]}" || unset 'zones[i]'
  done
fi

tmpfile=$(mktemp ".$(basename "$0").report.XXXXX.txt")
trap 'rm -f -- "$tmpfile"' EXIT
exec {fd}>>"$tmpfile"

_count="$(sort -u "$WORDS_FILE" | grep -cv '^#\|^$')"
_tcount="$(( _count * ${#zones[@]} ))"

>&2 printf '%s' "Check $_count ($_tcount) domains availability for zones:"
printf ' %s,' "${zones[@]}" | >&2 sed 's/,$/./'
>&2 echo

while read -r host; do

  for tld in "${zones[@]}"; do
    domain="${host,,}.$tld"
    if [ "$(jobs -r | wc -l)" -ge "$THREADS_LIMIT" ]; then
      wait "$(jobs -r -p | head -1)"
    fi
    check-domain "$domain" &
  done

  [ "${SOFT_THREADING,,}" == true ] && wait
  printf X

done < <(grep -v '^#\|^$' "$WORDS_FILE" | sort -u) | \
  pv -N "Checked domais" -tbeps "$(sort -u "$WORDS_FILE" | grep -cv '^#\|^$')" \
  - >/dev/null

[ "${SOFT_THREADING,,}" != true ] && wait

sort -uo "$tmpfile"{,}

command -v editor &>/dev/null && editor='editor' || editor='cat'
if [ -n "$OUTPUT_FILE" ]; then
  cat "$tmpfile" > "$OUTPUT_FILE"
  $editor "$OUTPUT_FILE"
else
  $editor "$tmpfile"
fi

exec {fd}>&-
rm -f "$tmpfile"

>&2 echo "Done"; exit 0
