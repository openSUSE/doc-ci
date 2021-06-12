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

while [[ $1 ]]; do
  case $1 in
    dc-files=*)
      dcs=$(echo "$1" | cut -f2- -d'=')
      shift
      ;;
    format-html=*)
      [[ $(echo "$1" | cut -f2- -d'=') == 'false' ]] && html=''
      shift
      ;;
    format-single-html=*)
      [[ $(echo "$1" | cut -f2- -d'=') == 'false' ]] && single=''
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
  styleroot=$(grep -P '^\s*STYLEROOT\s*=\s*' "$dc" | sed -r -e 's/^[^=]+=\s*["'\'']//' -e 's/["'\'']\s*//')
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

  exitthisdoc=$(( exitlasthtml + exitlastsingle))
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


gha_fold "Zipping documents for later upload as a GitHub artifact"
  wd="$PWD"
  artifact_dir=docs-artifact-collect
  artifact_zip=docs-artifact.zip
  artifact_name='builds-'$(echo "$dcs" | sha1sum | cut -b1-8)
  html_dirs=$(find "$builddir" -type d -name 'html')
  single_dirs=$(find "$builddir" -type d -name 'single-html')

  mkdir -p "$wd/$artifact_dir"

  for dir in $html_dirs $single_dirs; do
    log "Moving $dir to $artifact_dir"
    format_name=$(echo "$dir" | grep -oP '[^/]+$')
    doc_name=$(echo "$dir" | grep -oP '[^/]+/[^/]+$' | grep -oP '^[^/]+')
    mkdir -p "$artifact_dir/$format_name"
    cp -r "$dir" "$artifact_dir/$format_name/$doc_name"
  done
  log "Zipping $wd/$artifact_dir into $wd/$artifact_zip ($artifact_name)"
  ( cd "$wd/$artifact_dir"; zip -r "$wd/$artifact_zip" ./* )

  echo "::set-output name=artifact-name::$artifact_name"
  echo "::set-output name=artifact-file::$artifact_zip"
gha_fold --



echo "::set-output name=exit-build::$exitcode"
if [[ "$exitcode" -gt 0 ]]; then
  fail "Build(s) of $dcs failed."
else
  succeed "Build(s) of $dcs succeeded."
fi
