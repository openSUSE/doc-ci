#!/bin/bash
# shellcheck disable=SC2143
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

# shellcheck disable=SC2027,SC2046
log + "Running "$(basename "$0")", "$(sha1sum "$0" | cut -b1-8)" [ verify locally with: sha1sum "$(basename "$0")" | cut -b1-8 ]."

gha_fold "Environment variables"
  for var in GITHUB_JOB GITHUB_EVENT_NAME \
      GITHUB_ACTOR GITHUB_REPOSITORY_OWNER GITHUB_REPOSITORY GITHUB_REF GITHUB_SHA \
      HOME RUNNER_TEMP RUNNER_WORKSPACE \
      GITHUB_ACTION_REPOSITORY GITHUB_ACTION_REF; do
    echo "$var=\"${!var:-EMPTY-}\""
  done
gha_fold --

usecase='soundness'
mergeruns='true'
# GHA appears to allow for 4 simultaneous runners. 8 is a multiple of 4. In
# many repos, with this setting, you will still get individual runners for
# each DC file which at lowish numbers of runners is good for both speed and
# aiding comprehension of results. But for repos with lots of DC files (e.g.
# SBP's 70+ DC files) we can capitalize☭ on the avoidance of extra container
# image downloads/inits which tends to take 1 minute each time currently.
# Maybe upping to a maximum of twelve runners would be an option too?
mergerun_threshold=8
original_org=''

allow_build='true'

while [[ $1 ]]; do
  case $1 in
    mode=*)
      usecase=$(echo "$1" | cut -f2- -d'=')
      shift
      ;;
    merge-runs=*)
      [[ $(echo "$1" | cut -f2- -d'=') = 'false' ]] && mergeruns=''
      shift
      ;;
    original-org=*)
      original_org=$(echo "$1" | cut -f2- -d'=')
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
  # shellcheck disable=SC2125
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

  # This may be caused by intermittent networking issues, it would probably
  # be best not to fail too early because of this (FIXME). However, for
  # simplicity, we just fail here.
  [[ $code -eq 0 ]] || { fail "Cannot determine whether to build, configuration file $branchconfig is unavailable or invalid. Will not build.\n(Check the configuration at $branchconfig_repo.)\n"; }

  # GitHub gives us "org/repo", we really only care about the repo
  repo=$(echo "$GITHUB_REPOSITORY" | sed -r 's#^[^/]+/##')

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
        dc_list_prelim+=$(xml sel -t -v '//doc[@cat="'"$cat"'"][@branches[contains(concat(" ",.," "), " '"$branchname"' ")]]/@doc' "$configxml")'\n'
      done
    done
    dc_list_prelim=$(echo -e "$dc_list_prelim" | tr ' ' '\n' | sed -r -e 's/^(.)/DC-\1/' -e 's/^DC-DC-/DC-/' | sort -u | sed -n '/^$/ !p')
    if [[ -z "$dc_list_prelim" ]]; then
      log - "No DC files enabled for building. $branchconfig is probably invalid.\n(Check the configuration at $branchconfig_repo.)\n"
    else

      for dc in $dc_list_prelim; do
        [[ ! -f "$dc" ]] && { log - "$dc is configured to be built but does not exist"; allow_build='false'; continue; }
        hash=$(/docserv-dchash "$dc" "FAKE_ROOT_ID")
        dc_list+="$hash $dc\n"
      done

      dc_list=$(echo -e "$dc_list" | sort -u | cut -d' ' -f2)

    fi

  else
    log "The branch \"$ci_branch\" of \"$repo\" does not appear to be configured to build.\n(Check the configuration at $branchconfig_repo.)\n"
    allow_build='false'
  fi

  if [[ -n "$original_org" ]]; then
    if [[ ! $(echo "$original_org" | sed -r 's/.+/\L&/i') = $(echo "$GITHUB_REPOSITORY_OWNER" | sed -r 's/.+/\L&/i') ]]; then
      log - "Repository owner environment variable (\"$GITHUB_REPOSITORY_OWNER\") does not match 'original-org' setting (\"$original_org\"). Builds cannot be published and will be disabled."
      allow_build='false'
    else
      log + "Repository owner environment variable matches 'original-org' setting (\"$original_org\"). Normally, this should mean that builds can be published."
    fi
  else
    log "Parameter 'original-org' is unset, cannot determine whether publishing results would work."
  fi

else
  fail "Use case \"$usecase\" is unknown."
fi


# Create a JSON of jobs, optimize for 8 runners (with 8 = $mergerun_threshold)

# Do not sort $dc_list_formatted again! Builds are faster when we can reuse
# existing profiling results, which is why we use a non-alphabetic sort for
# the build list.
dc_list_formatted=$(echo "$dc_list" | tr ' ' '\n' | sed -n '/^$/ !p')
dc_list_length=$(echo -e "$dc_list_formatted" | wc -l)
dc_per_runner=1
early_runner=0
runners=$dc_list_length
if [[ "$mergeruns" = 'true' && "$dc_list_length" -gt "$mergerun_threshold" ]]; then
  log "Merging runs because there are more than $mergerun_threshold runs and merging runs is enabled ('merge-runs=true')."
  dc_per_runner=$(( dc_list_length / mergerun_threshold ))
  early_runner=$(( dc_list_length % mergerun_threshold ))
  runners=$mergerun_threshold
elif [[ ! "$mergeruns" = 'true' ]]; then
  log "Not merging runs because merging runs is disabled ('merge-runs=false')."
else
  log "Not merging runs because there are fewer than or exactly $mergerun_threshold runs."
fi
dc_list_json+="["

if [[ -n "$dc_list_formatted" ]]; then
  d=1
  for r in $(seq 1 $runners); do

    dc_per_thisrunner="$dc_per_runner"
    [[ $r -le $early_runner ]] && dc_per_thisrunner=$(( dc_per_thisrunner + 1 ))

    dc_list_json+='"'
    for i in $(seq 1 $dc_per_thisrunner); do
      dc_list_json+=$(echo -e "$dc_list_formatted" | sed -n "$d p" )
      [[ "$i" -lt "$dc_per_thisrunner" ]] && dc_list_json+=' '

      d=$(( d + 1 ))
    done
    dc_list_json+='"'

    [[ "$r" -lt "$runners" ]] && dc_list_json+=','
  done
fi

dc_list_json+="]"


log + "Generated $usecase with the following DC files (DC files on the same line have the same runner):\n"
echo "$dc_list_json" | jq || fail "Generated JSON was invalid:\n$dc_list_json"

echo "::set-output name=dc-list::$dc_list_json"
if [[ "$usecase" = 'list-build' ]]; then
  echo "::set-output name=allow-build::$allow_build"
  relevantbranches=$(echo -e "$relevantbranches" | tr '\n' ' ')
  echo "::set-output name=relevant-branches::$relevantbranches"

  [[ "$allow_build" = 'true' ]] && log + "Builds will be enabled."
  [[ "$allow_build" = 'false' ]] && log - "Builds will be disabled."
fi

succeed "Successfully generated $usecase."
