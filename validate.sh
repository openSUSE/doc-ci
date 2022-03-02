#!/bin/bash
# shellcheck disable=SC2143
# Validate an AsciiDoc/DocBook document with DAPS

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

gha_fold() {
  name="$1"
  prefix='::group::'
  if [[ $1 == '--' ]]; then
    name=''
    prefix='::endgroup::'
  fi
  echo -e "$prefix$name"
}

get_dc_value() {
  local dc_attribute=$1
  local dc_file=$2
  grep -oP '^\s*'"$dc_attribute"'\s*=\s*.*' "$dc_file" | head -1 | sed -r -e 's/^\s*'"$dc_attribute"'\s*=\s*//' -e 's/"*//g' -e "s/'*//g" -e 's/(^\s*|\s*$)//g'
}


# shellcheck disable=SC2027,SC2046
echo "Running "$(basename "$0")", "$(sha1sum "$0" | cut -b1-8)" [ verify locally with: sha1sum "$(basename "$0")" | cut -b1-8 ]."

gha_fold "Environment"
  for var in GITHUB_JOB GITHUB_EVENT_NAME \
      GITHUB_ACTOR GITHUB_REPOSITORY_OWNER GITHUB_REPOSITORY GITHUB_REF GITHUB_SHA \
      HOME RUNNER_TEMP RUNNER_WORKSPACE \
      GITHUB_ACTION_REPOSITORY GITHUB_ACTION_REF; do
    echo "$var=\"${!var:-EMPTY-}\""
  done
gha_fold --

dcs=''
ids='--validate-ids'
images='--validate-images'
tables=''
schema='geekodoc1'

while [[ $1 ]]; do
  case $1 in
    dc-files=*)
      dcs=$(echo "$1" | cut -f2- -d'=')
      shift
      ;;
    validate-ids=*)
      [[ $(echo "$1" | cut -f2- -d'=') == 'false' ]] && ids=''
      shift
      ;;
    validate-images=*)
      [[ $(echo "$1" | cut -f2- -d'=') == 'false' ]] && images=''
      shift
      ;;
    validate-tables=*)
      [[ $(echo "$1" | cut -f2- -d'=') == 'false' ]] && tables='--not-validate-tables'
      shift
      ;;
    xml-schema=*)
      schema=$(echo "$1" | cut -f2- -d'=')
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

for dc in $dcs; do
  [[ -f "$dc" ]] || fail "DC file \"$dc\" does not exist."
done

daps_config="$HOME/.config/daps"
dapsrc="$daps_config/dapsrc"
mkdir -p "$daps_config"
if [[ "$schema" = 'geekodoc1' ]]; then
  echo 'DOCBOOK5_RNG_URI="urn:x-suse:rnc:v1:geekodoc-flat"' > "$dapsrc"
elif [[ "$schema" = 'geekodoc2' ]]; then
  echo 'DOCBOOK5_RNG_URI="urn:x-suse:rnc:v2:geekodoc-flat"' > "$dapsrc"
elif [[ "$schema" = 'docbook51' ]]; then
  echo 'DOCBOOK5_RNG_URI="http://docbook.org/xml/5.1/rng/docbookxi.rng"' > "$dapsrc"
elif [[ "$schema" = 'docbook52' ]]; then
  echo 'DOCBOOK5_RNG_URI="http://docbook.org/xml/5.2/rng/docbookxi.rng"' > "$dapsrc"
else
  fail "Validation schema \"$schema\" is not supported. Supported values are 'geekodoc1', 'geekodoc2', 'docbook51', 'docbook52'."
fi
log "Set up validation schema \"$schema\""

gha_fold "Package versions in container"
  rpm -q --qf '- %{NAME} %{VERSION}\n' \
    daps daps-mini \
    libxslt-tools libxml2-tools xmlgraphics-fop \
    docbook_5 docbook_4 geekodoc novdoc \
    docbook-xsl-stylesheets docbook5-xsl-stylesheets \
    suse-xsl-stylesheets suse-xsl-stylesheets-sbp hpe-xsl-stylesheets
gha_fold --


exitcode=0

for dc in $dcs; do

  builddir="build/$dc"
  mkdir -p "$builddir" 2>/dev/null || true

  # Use fixed styleroot, so the styleroot does not become an issue during
  # validation
  daps_sr="daps --styleroot /usr/share/xml/docbook/stylesheet/nwalsh5/current/ --builddir $builddir"

  daps_val_run=$($daps_sr \
      -vv \
      -d "$dc" \
      validate \
      "$ids" \
      "$images" \
      "$tables" \
       2>&1)

  exitlastdaps=$?

  next_msg="Validating $dc"
  [[ "$exitlastdaps" -eq 0 ]] && gha_fold "$next_msg" || echo -e "💥${RED}$next_msg${RESET}"

  [[ "$ids" = '' ]] && log "Not checking IDs: variable 'validate-ids' is set to 'false' in workflow."
  [[ "$images" = '' ]] && log "Not checking images: variable 'validate-images' is set to 'false' in workflow."
  [[ "$tables" = '--not-validate-tables' ]] && log "Not checking tables: variable 'validate-tables' is set to 'false' in workflow."

  # * \018 == ASCII Cancel character used by DAPS to delete previous lines
  # * Also cut away all profiling messages, they tend to be empty calories (the
  #   we cut them out is hopefully not too invasive)
  echo -e "$daps_val_run" | sed -n '/\018/ !p' | sed -n '/[ \t]*Profiling [^ ][^ ]*\.xml/ !p'

  [[ $(get_dc_value 'MAIN' "$dc" | grep -oP '\.adoc$') ]] && \
    log "AsciiDoctor may add or delete cells to force document validity. Perform a visual check of the tables in your AsciiDoc document."

  [[ "$exitlastdaps" -eq 0 ]] && gha_fold --

  if [[ "$exitlastdaps" -gt 0 ]]; then
    log - "Validation of $dc failed."
  else
    log + "Validation of $dc succeeded."
  fi
  exitcode=$(( exitcode + exitlastdaps ))
  echo ""

done


echo "::set-output name=exit-validate::$exitcode"
if [[ "$exitcode" -gt 0 ]]; then
  fail "Overall validation result of this run ($dcs): failed."
else
  succeed "Overall validation result of this run ($dcs): successful."
fi
