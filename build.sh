#!/bin/bash
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

dc=''
html='true'
single='true'
pdf='true'
schema='geekodoc2'

while [[ $1 ]]; do
  case $1 in
    dc-files=*)
      dcs=${1#*=}
      shift
      ;;
    format-html=*)
      [[ ${1#*=} == 'false' ]] && html=''
      shift
      ;;
    format-single-html=*)
      [[ ${1#*=} == 'false' ]] && single=''
      shift
      ;;
    format-pdf=*)
      [[ ${1#*=} == 'false' ]] && pdf=''
      shift
      ;;
    xml-schema=*)
      schema=${1#*=}
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
    daps \
    libxslt-tools libxml2-tools xmlgraphics-fop \
    docbook_5 docbook_4 geekodoc novdoc \
    docbook-xsl-stylesheets docbook5-xsl-stylesheets \
    suse-xsl-stylesheets suse-xsl-stylesheets-sbp hpe-xsl-stylesheets
gha_fold --

builddir="build"
mkdir -p "$builddir" 2>/dev/null || true

daps="daps --builddir $builddir"
daps_sr="daps --styleroot /usr/share/xml/docbook/stylesheet/nwalsh5/current/ --builddir $builddir"


exitcode=0
for dc in $dcs; do
  # This works with and without quotes:
  styleroot=$(grep -P '^\s*STYLEROOT\s*=\s*' "$dc" | sed -n 's/^[^=]*=[[:blank:]]*["'\'']\?\([^"'\'']*\)["'\'']\?.*/\1/p')
  dapsbuild=$daps
  if [[ ! -d "$styleroot" ]]; then
    dapsbuild=$daps_sr
    log - "$dc requests STYLEROOT $styleroot which is not installed. Replacing with default STYLEROOT."
  fi

  exitlasthtml=0
  if [[ "$html" = 'true' ]]; then
    gha_fold "Building $dc as HTML"
      $dapsbuild -vv -d "$dc" html --draft
      exitlasthtml=$?
    gha_fold --
  fi

  exitlastsingle=0
  if [[ "$single" = 'true' && "$exitlasthtml" -eq 0 ]]; then
    gha_fold "Building $dc as single-HTML"
      $dapsbuild -vv -d "$dc" html --single --draft
      exitlastsingle=$?
    gha_fold --
  fi

  exitlastpdf=0
  if [[ "$pdf" = 'true' ]]; then
    gha_fold "Building $dc as PDF"
      $dapsbuild -vv -d "$dc" pdf --draft
      exitlastpdf=$?
    gha_fold --
  fi

  exitthisdoc=$(( exitlasthtml + exitlastsingle + exitlastpdf ))
  if [[ "$exitthisdoc" -gt 0 ]]; then
    log - "Build of $dc failed."
  else
    log + "Build of $dc succeeded."
  fi
  exitcode=$(( exitcode + exitthisdoc ))
  echo ""
done


gha_fold "Adding beta warning messages to HTML files"
  # We need to avoid touching files twice (the regex is not quite safe
  # enough for that), hence it is important to exclude symlinks.
  warnfiles=$(find "$builddir" -type f -name '*.html')
  warningtext='This is a draft document that was built and uploaded automatically. It may document beta software and be incomplete or even incorrect. <strong>Use this document at your own risk.<\/strong>'
  warningbutton='I understand this is a draft'
  cookiedays="0.5" # retention time for cookie = .5 days aka 12 hours
  for warnfile in $warnfiles; do
    # shellcheck disable=SC2016
    sed -r -i \
      -e 's/<\/head><body[^>]*/& onload="$('"'"'#betawarn-button-wrap'"'"').toggle();if (document.cookie.length > 0) {if (document.cookie.indexOf('"'"'betawarn=closed'"'"') != -1){$('"'"'#betawarn'"'"').toggle()}};"><div id="betawarn" style="position:fixed;bottom:0;z-index:9025;background-color:#FDE8E8;padding:1em;margin-left:10%;margin-right:10%;display:block;border-top:.75em solid #E11;width:80%"><p style="color:#333;margin:1em 0;padding:0;">'"$warningtext"'<\/p> <div id="betawarn-button-wrap" style="display:none;margin:0;padding:0;"><a href="#" onclick="$('"'"'#betawarn'"'"').toggle();var d=new Date();d.setTime(d.getTime()+('"$cookiedays"'*24*60*60*1000));document.cookie='"'"'betawarn=closed; expires='"'"'+d.toUTCString()+'"'"'; path=\/'"'"'; return false;" style="color:#333;text-decoration:underline;float:left;margin-top:.5em;padding:1em;display:block;background-color:#FABEBE;">'"$warningbutton"'<\/a><\/div><\/div/' \
      -e 's/ id="(_fixed-header-wrap|_white-bg)"/& style="background-color: #E11;"/g'\
      "$warnfile"
    log "Added warning to $warnfile"
  done
gha_fold --


gha_fold "Collecting build output for upload as an artifact"
  wd="$PWD"
  artifact_dir=docs-artifact-collect
  artifact_name='builds-'$(echo "$dcs" | sha1sum | cut -b1-8)
  html_dirs=$(find "$builddir" -type d -name 'html')
  single_dirs=$(find "$builddir" -type d -name 'single-html')

  mkdir -p "$wd/$artifact_dir"

  for dir in $html_dirs $single_dirs; do
    # DAPS generates this dir structure:
    #   build   / DC-name / format  / root-id_draft / content.html
    # We want to transform that to:
    #   art-dir / format  / DC-name / content.html
    # (`$dir` is at `build/DC-name/format`)
    format_name=$(echo "$dir" | grep -oP '[^/]+$')
    doc_name=$(echo "$dir" | grep -oP '[^/]+/[^/]+$' | grep -oP '^[^/]+')

    rootid_dir=$(ls $dir | head -1)
    [[ -d "$dir/$rootid_dir" ]] && dir="$dir/$rootid_dir"

    log "Moving $dir to $artifact_dir/$format_name/$doc_name"
    mkdir -p "$wd/$artifact_dir/$format_name"
    cp -r "$dir" "$wd/$artifact_dir/$format_name/$doc_name"
  done
  
  # since the PDF is a single file, we move it separately
  pdf_file=$(find "$builddir" -type f -name '*.pdf' )
  format_name="pdf"
  doc_name=$(echo "$pdf_file" | grep -oP '[^/]+/[^/]+$' | grep -oP '^[^/]+')
  pdf_name=$(echo "$pdf_file" | grep -oP '[^/]+$')
  log "Moving $pdf_file to $artifact_dir/$format_name/$doc_name/$pdf_name" 
  mkdir -p "$wd/$artifact_dir/$format_name/$doc_name"
  cp "$pdf_file" "$wd/$artifact_dir/$format_name/$doc_name/$pdf_name"

  echo "artifact-name=$artifact_name" >> $GITHUB_OUTPUT
  echo "artifact-dir=$artifact_dir" >> $GITHUB_OUTPUT
gha_fold --


echo "exit-build=$exitcode" >> $GITHUB_OUTPUT
if [[ "$exitcode" -gt 0 ]]; then
  fail "Build(s) of $dcs failed."
else
  succeed "Build(s) of $dcs succeeded."
fi
