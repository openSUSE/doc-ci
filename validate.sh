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
tables='true'
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
      [[ $(echo "$1" | cut -f2- -d'=') == 'false' ]] && tables=''
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
  echo 'DOCBOOK5_RNG_URI="https://github.com/openSUSE/geekodoc/raw/master/geekodoc/rng/geekodoc5-flat.rnc"' > "$dapsrc"
elif [[ "$schema" = 'docbook51' ]]; then
  echo 'DOCBOOK5_RNG_URI="/usr/share/xml/docbook/schema/rng/5.1/docbookxi.rng"' > "$dapsrc"
else
  fail "Validation schema \"$schema\" is not supported. Supported values are 'geekodoc1', 'docbook51'."
fi
log "Set up "

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

  gha_fold "Validating $dc"

    [[ "$ids" = '' ]] && log "Not checking IDs: variable 'validate-ids' is set to 'false' in workflow."
    [[ "$images" = '' ]] && log "Not checking images: variable 'validate-images' is set to 'false' in workflow."

    $daps_sr \
      -vv \
      -d "$dc" \
      validate \
      "$ids" \
      "$images"

    exitlastdaps=$?

  gha_fold --

  exitlasttable=0
  if [[ "$tables" = '' ]]; then
    log "Not checking table layouts in $dc: variable 'validate-tables' is set to 'false' in workflow."
  elif [[ $exitlastdaps -ne 0 ]]; then
    log - "Skipping table layout check for $dc: document is invalid."
  else

    gha_fold "Checking table layouts in $dc"

      validate_tables=/usr/share/daps/libexec/validate-tables.py

      is_adoc=0
      [[ $(get_dc_value 'MAIN' "$dc" | grep -oP '\.adoc$') ]] && is_adoc=1

      bigfile=$($daps_sr -d "$dc" bigfile)
      # Try on the profiled bigfile -- this is the definitive test whether
      # something is wrong. However, we will get bad line numbers.
      table_errors=$($validate_tables "$bigfile" 2>&1)
      exitlasttable=$?

      if [[ -n "$table_errors" ]]; then
        echo -e "$table_errors" | \
          sed -r -e 's,^/([^/: ]+/)*,,' -e 's,.http://docbook.org/ns/docbook.,,' | \
          sed -rn '/^- / !p'
        log - "Some tables are invalid."
      else
        log + "All tables are valid."
        [[ "$is_adoc" -eq 1 ]] && log "AsciiDoctor may add or delete cells to force document validity. Perform a visual check of the tables in your AsciiDoc document."
      fi

    gha_fold --

  fi
  exitthisdoc=$(( exitlastdaps + exitlasttable))
  if [[ "$exitthisdoc" -gt 0 ]]; then
    log - "Validation of $dc failed."
  else
    log + "Validation of $dc succeeded."
  fi
  exitcode=$(( exitcode + exitthisdoc ))
  echo ""

done


echo "::set-output name=exit-validate::$exitcode"
if [[ "$exitcode" -gt 0 ]]; then
  fail "Validation of $dcs failed."
else
  succeed "Validation of $dcs succeeded."
fi
