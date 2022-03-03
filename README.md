# domain-checker

Commandline utility to check availability of domain names for different zones

Usage:

* `domain-checker [words file] [zones file] [output file]`
* `<vars> domain-checker [words file] > [output file]`

This utility checks if a domain can be registered for all combinations of
words and zones, first it checks for the presence of a `SOA` record in the DNS
and, if not, it checks the whois of the domain.

If the domain is available for registration,
it will be saved as a result of the work.

## Variables

[ variable name = "default value" (positional arg) - description ]

* **`WORDS_FILE`**=`wordss.txt` _(first arg)_ -
  File with words to search for a domain names
* **`ZONES_FILE`**=`None` _(second arg)_ -
  Zone name file (optional)
* **`OUTPUT_FILE`**=`None` _(third arg)_ -
  File where available domain names will be saved (optional)
* **`CHECK_ZONES`**=`true` - Check zones for whois server (optional)
* **`DNS_SERVERS`**=`1.1.1.1,8.8.8.8,1.0.0.1,8.8.4.4` -
  Comma-separated list of custom DNS servers to check for SOA records
* **`THREADS_LIMIT`**=`number of proc` - Number of threads (optional)
* **`SOFT_THREADING`**=`true` -
  If enabled, threads are executed for the zone loop,
  otherwise global threads are used (optional)

## Dependecies

* `dig`
* `whois`
* `pv`
