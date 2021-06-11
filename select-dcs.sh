#!/bin/bash
# Select DC files for later building/validation with DAPS

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


echo "Running "$(basename "$0")", "$(sha1sum "$0" | cut -b1-8)" [ verify locally with: sha1sum "$(basename "$0")" | cut -b1-8 ]."

gha_fold "Environment variables"
  for var in GITHUB_JOB GITHUB_EVENT_NAME \
      GITHUB_ACTOR GITHUB_REPOSITORY_OWNER GITHUB_REPOSITORY GITHUB_REF GITHUB_SHA \
      HOME RUNNER_TEMP RUNNER_WORKSPACE \
      GITHUB_ACTION_REPOSITORY GITHUB_ACTION_REF; do
    echo "$var=\"${!var:-EMPTY-}\""
  done
gha_fold --

usecase='soundness'

while [[ $1 ]]; do
  case $1 in
    use-case=*)
      usecase=$(echo "$1" | cut -f2- -d'=')
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

dc_list=''

# USE CASE 1
if [[ "$usecase" = 'soundness' ]]; then
  log "Checking all DC files for basic soundness"

  # Check /all/ DC files in repo root for basic soundness
  check_dcs=DC-*

  unsounddc=
  for dc in $check_dcs; do
    [[ -d $dc ]] && unsounddc+="- $dc is a directory.\n" && continue
    [[ ! -e $dc ]] && unsounddc+="- $dc does not exist.\n" && continue
    [[ ! $(grep -oP '^\s*MAIN\s*=\s*.*' "$dc") ]] && unsounddc+="- $dc does not have a valid \"MAIN\" value.\n" && continue
    [[ $(grep -oP '^\s*MAIN\s*=\s*.*' "$dc" | wc -l) -gt 1 ]] && unsounddc+="- $dc has multiple \"MAIN\" values.\n" && continue
    main=$(get_dc_value 'MAIN' "$dc")
    dir_prefix=$(dirname "$dc")
    dir="xml"
    [[ $(echo "$main" | grep -oP '\.adoc$') ]] && dir="adoc"
    [[ ! -f "$dir_prefix/$dir/$main" ]] && unsounddc+="- The \"MAIN\" file referenced in $dc does not exist.\n"
  done

  if [[ -n "$unsounddc" ]]; then
    fail "The following DC file(s) from the repository are not sound:\n$unsounddc\n"
  else
    succeed "All DC files are sound."
  fi


# USE CASE 2
elif [[ "$usecase" = 'list-validate' ]]; then

  log "Creating list of DCs to validate"
  # Prioritize checking DC-*-all files, because that is probably less
  # confusing to writers
  check_dc_sets=$(ls DC-*-all 2>/dev/null)
  check_dcs=$(ls DC-* 2>/dev/null)

  known_hashes=''
  for dc in $check_dc_sets $check_dcs; do
    hash=$(/docserv-dchash "$dc" "FAKE_ROOT_ID")
    [[ $(echo -e "$known_hashes" | sort -u | grep '^'"$hash"'$') ]] || dc_list+=' '"$dc"
    known_hashes="$known_hashes\n$hash"
  done


# USE CASE 3
elif [[ "$usecase" = 'list-build' ]]; then

  log "Creating list of DC files to build"

  # Configuration file for navigation page
  branchconfig_repo='https://github.com/SUSEdoc/susedoc.github.io'
  branchconfig_branch='master'
  branchconfig='config.xml'
  dtd='_stuff/config.dtd'

  dir_config_repo="$HOME/build-config-repo"
  mkdir -p "$dir_config_repo"
  cfg_git="git -C $dir_config_repo"
  # We noticed that curl'ing the config file was too slow sometimes due to
  # GitHub's caching. This is a (unfortunately slightly expensive) workaround
  # for the issue.
  git clone \
    --no-tags --no-recurse-submodules --depth=1 \
    --branch "$branchconfig_branch" \
    "$branchconfig_repo" "$dir_config_repo"
  configxml="$dir_config_repo/$branchconfig"
  configdtd="$dir_config_repo/$dtd"

  # If $configxml is a valid XML document and produces no errors...
  xmllint --noout --noent --dtdvalid "$configdtd" "$configxml"
  code=$?

  # This may be caused by intermittent networking issues, it's probably best
  # not to fail on this (..?) or maybe it is better, FIXME: think again.
  [[ $code -eq 0 ]] || { fail "Cannot determine whether to build, configuration file $branchconfig is unavailable or invalid. Will not build.\n(Check the configuration at $branchconfig_repo.)\n"; }

  # GitHub gives us "org/repo", we really only care about the repo
  repo=$(echo "$GITHUB_REPOSITORY" | sed 's#^[^/]+/##')

  # GitHub gives us a full Git ref like "refs/heads/main", not just a branch
  # name
  ci_branch=$(echo "$GITHUB_REF" | sed -r 's#^refs/heads/##')
  ci_branch_abbrev=$(echo "$ci_branch" | sed -r 's#^main(t(enance)?)?/##')

  relevantcats=$(xml sel -t -v '//cats/cat[@repo="'"$repo"'"]/@id' "$configxml")

  relevantbranches=
  for cat in $relevantcats; do
    relevantbranches+=$(xml sel -t -v '//doc[@cat="'"$cat"'"]/@branches' "$configxml")'\n'
  done

  relevantbranches=$(echo -e "$relevantbranches" | tr ' ' '\n' | sort -u)

  if [[ $(echo -e "$relevantbranches" | grep "^$ci_branch\$") ]] || \
   [[ $(echo -e "$relevantbranches" | grep "^$ci_branch_abbrev\$") ]]; then
    for cat in $relevantcats; do
      for branchname in "$ci_branch" "$ci_branch_abbrev"; do
        dc_list+=$(xml sel -t -v '//doc[@cat="'"$cat"'"][@branches[contains(concat(" ",.," "), " '"$branchname"' ")]]/@doc' "$configxml")'\n'
      done
    done
    dc_list=$(echo -e "$dc_list" | tr ' ' '\n' | sed -r -e 's/^(.)/DC-\1/' -e 's/^DC-DC-/DC-/' | sort -u | sed -n '/^$/ !p' | tr '\n' ' ')
    [[ -z "$dc_list" ]] && log "No DC files enabled for building. $branchconfig is probably invalid.\n(Check the configuration at $branchconfig_repo.)\n"
  else
    log "The branch \"$ci_branch\" of \"$repo\" does not appear to be configured to build.\n(Check the configuration at $branchconfig_repo.)\n"
  fi

else
  fail "Use case \"$usecase\" is unknown."
fi

log + "Came up with the following list of DC files:\n$dc_list"

dc_list_json=$(echo "$dc_list" | tr ' ' '\n' | sed -n '/^$/ !p' | jq -R -s -c 'split("\n")[:-1]')

echo "::set-output name=dc-list::$dc_list_json"
