#!/bin/bash
#

RED='\e[31m'
GREEN='\e[32m'
BLUE='\e[34m'
BOLD='\e[1m'
RESET='\e[0m'

log() {
  # $1 - optional: string: "+" for green color, "-" for red color
  # $2 - message
  colorcode="$BLUE"
  [[ "$1" == '+' ]] && colorcode="$GREEN" && shift
  [[ "$1" == '-' ]] && colorcode="$RED" && shift
  echo -e "$colorcode${1}$RESET"
}

fail() {
  # $1 - message
  echo -e "$RED$BOLD${1}$RESET"
  exit 1
}

succeed() {
  # $1 - message
  echo -e "$GREEN$BOLD${1}$RESET"
  exit 0
}

get_dc_value() {
  dc_attribute=$1
  dc_file=$2
  grep -oP '^\s*'"$dc_attribute"'\s*=\s*.*' "$dc_file" | head -1 | sed -r -e 's/^\s*'"$dc_attribute"'\s*=\s*//' -e 's/"*//g' -e "s/'*//g" -e 's/(^\s*|\s*$)//g'
}

echo "Running "$(basename "$0")", "$(sha1sum "$0" | cut -b1-8)" [ verify locally with: sha1sum "$(basename "$0")" | cut -b1-8 ]."

echo "::group::Environment"
for var in ACTIONS_CACHE_URL ACTIONS_RUNTIME_TOKEN ACTIONS_RUNTIME_URL \
           CI GITHUB_ACTION GITHUB_ACTIONS GITHUB_ACTION_REF \
           GITHUB_ACTION_REPOSITORY GITHUB_ACTOR GITHUB_API_URL \
           GITHUB_BASE_REF GITHUB_ENV GITHUB_EVENT_NAME GITHUB_EVENT_PATH \
           GITHUB_GRAPHQL_URL GITHUB_HEAD_REF GITHUB_JOB GITHUB_PATH \
           GITHUB_REF GITHUB_REPOSITORY GITHUB_REPOSITORY_OWNER \
           GITHUB_RETENTION_DAYS GITHUB_RUN_ID GITHUB_RUN_NUMBER \
           GITHUB_SERVER_URL GITHUB_SHA GITHUB_WORKFLOW GITHUB_WORKSPACE \
           HOME INPUT_COMMAND RUNNER_OS RUNNER_TEMP \
           RUNNER_TOOL_CACHE RUNNER_WORKSPACE; do
  echo "$var=\"${!var:----EMPTY---}\""
done
echo "::endgroup::"

dc=''
ids=' --validate-ids'
images=' --validate-images'
tables='true'
schema='geekodoc1'

while [[ $1 ]]; do
  case $1 in
    dc=*)
      dc=$(echo "$1" | cut -f2- -d'=')
      shift
      ;;
    ids=*)
      [[ $(echo "$1" | cut -f2- -d'=') == 'false' ]] && ids=''
      shift
      ;;
    images=*)
      [[ $(echo "$1" | cut -f2- -d'=') == 'false' ]] && images=''
      shift
      ;;
    tables=*)
      [[ $(echo "$1" | cut -f2- -d'=') == 'false' ]] && tables=''
      shift
      ;;
    schema=*)
      # Noop currently
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      log - "Command-line argument \"$1\" cannot be parsed."
      shift
      ;;
  esac
done

[[ -f "$dc" ]] || fail "DC file \"$dc\" does not exist."


builddir="build/$dc"
daps_sr="daps --styleroot /usr/share/xml/docbook/stylesheet/nwalsh5/current/ --builddir $builddir -vv"

echo "::group:: Validating $dc"

mkdir -p "$builddir" 2>/dev/null || true
$daps_sr \
  -d "$dc" \
  validate \
  "$ids" \
  "$images"
exitdaps=$?

echo "::endgroup::"

exittables=0
if [[ "$tables" == 'true' ]]; then
  echo "::group:: Checking table layouts in $dc"

  validate_tables=/usr/share/daps/libexec/validate-tables.py

  is_adoc=0
  [[ $(get_dc_value 'MAIN' "$DCFILE" | grep -oP '\.adoc$') ]] && is_adoc=1

  bigfile=$($daps_sr -d "$dc" bigfile)
  # Try on the profiled bigfile -- this is the definitive test whether
  # something is wrong. However, we will get bad line numbers.
  table_errors=$($validate_tables "$bigfile" 2>&1)
  exittables=$?

  if [[ -n "$table_errors" ]]; then
    echo -e "$table_errors" | \
      sed -r -e 's,^/([^/: ]+/)*,,' -e 's,.http://docbook.org/ns/docbook.,,' | \
      sed -rn '/^- / !p'
    log - "Some of the tables in this document are broken."
  else
    if [[ "$is_adoc" -eq 1 ]]; then
      log "Make sure to perform a visual check of the tables in your AsciiDoc document. AsciiDoctor may delete cells to make documents valid."
    else
      log + "All tables look valid."
    fi
  fi
  echo "::endgroup::"
else
  log "Not checking table layouts: 'validate-tables' is set to false in workflow"
fi

exitcode=$((exitdaps + exittables))

echo "::set-output name=exitvalidate::$exitcode"
exit $exitcode
