#!/bin/bash -e
#
# From the GitHub repository:
# https://github.com/openSUSE/doc-ci
#
# License: MIT
#
# Written by Thomas Schraitle

RED='\e[31m'
GREEN='\e[32m'
BLUE='\e[34m'
BOLD='\e[1m'
RESET='\e[0m' # No Color

DCVALIDATE=".travis-check-docs"

# Configuration file for navigation page
BRANCHCONFIG_REPO='https://github.com/SUSEdoc/susedoc.github.io.git'
BRANCHCONFIG_BRANCH='master'
BRANCHCONFIG='config.xml'
DTD='_stuff/config.dtd'
BRANCHCONFIG_URL='https://github.com/SUSEdoc/susedoc.github.io/blob/master/config.xml'


DAPS="daps"
# Setting --styleroot makes sure that DAPS does not error out when the
# stylesheets requested by the DC file are not available in the container.
DAPS_SR="$DAPS --styleroot /usr/share/xml/docbook/stylesheet/suse2013-ns/"

# How many commits do we allow to accumulate in publishing repos before we
# reset the repo?
MAXCOMMITS=35

TRAVIS_FOLD_IDS=""


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

travis_fold() {
  humanname="$1"
  type='start'
  current_id="fold_"$(( ( RANDOM % 32000 ) + 1 ))
  if [[ $1 == '--' ]]; then
    humanname=''
    type='end'
    current_id=$(echo "$TRAVIS_FOLD_IDS" | grep -oP 'fold_[0-9]+$')
    TRAVIS_FOLD_IDS=$(echo "$TRAVIS_FOLD_IDS" | sed -r "s/ $current_id\$//")
  else
    TRAVIS_FOLD_IDS+=" $current_id"
  fi
  echo -en "travis_fold:$type:$current_id\\r" && log "$humanname"
}

get_dc_value() {
  dc_attribute=$1
  dc_file=$2
  grep -oP '^\s*'"$dc_attribute"'\s*=\s*.*' $dc_file | head -1 | sed -r -e 's/^\s*'"$dc_attribute"'\s*=\s*//' -e 's/"*//g' -e "s/'*//g" -e 's/(^\s*|\s*$)//g'
}

mkdir -p /root/.config/daps/
echo DOCBOOK5_RNG_URI="https://github.com/openSUSE/geekodoc/raw/master/geekodoc/rng/geekodoc5-flat.rnc" > /root/.config/daps/dapsrc

envfile=env.list

[[ -f "$envfile" ]] || fail "The env.list file is missing. Make sure that your .travis.yml file is set to generate this file."
source $envfile

# Determine whether we even *could* build HTML
BUILDDOCS=0
undefined_vars=''
[[ "$TRAVIS_BRANCH" ]] || undefined_vars+="TRAVIS_BRANCH "
[[ "$TRAVIS_REPO_SLUG" ]] || undefined_vars+="TRAVIS_REPO_SLUG "
[[ "$TRAVIS_COMMIT" ]] || undefined_vars+="TRAVIS_COMMIT "
[[ "$ENCRYPTED_PRIVKEY_SECRET" ]] || undefined_vars+="ENCRYPTED_PRIVKEY_SECRET "

if [[ "$undefined_vars" ]]; then
  BUILDDOCS=-1
  log "The following environment variables are not defined in $envfile:\n  $undefined_vars\nCannot build or push to susedoc.github.io, builds will be force-disabled."
fi


travis_fold "Variables"
PRODUCT=$(echo "$TRAVIS_BRANCH" | sed -r -e 's#^main(t(enance)?)?/##')
REPO=$(echo "$TRAVIS_REPO_SLUG" | sed -e 's/.*\///g')
echo "TRAVIS_REPO_SLUG=\"$TRAVIS_REPO_SLUG\""
echo "REPO=\"$REPO\""
echo "TRAVIS_BRANCH=\"$TRAVIS_BRANCH\""
echo "PRODUCT=\"$PRODUCT\""
echo "TRAVIS_PULL_REQUEST=\"$TRAVIS_PULL_REQUEST\""
echo "pwd=\"$(pwd)\""
[[ "$DISABLE_ID_CHECK" -ne 1 ]] && DISABLE_ID_CHECK=0
echo "DISABLE_ID_CHECK=\"$DISABLE_ID_CHECK\""

if [[ "$LIST_PACKAGES" ]] && [[ $LIST_PACKAGES -eq "1" ]]; then
  rpm -qa | sort
fi
travis_fold --


DCBUILDLIST=

travis_fold "Check whether repo/branch are configured for builds"
if [[ $BUILDDOCS -ne -1 ]]; then

  dir_configrepo=$(pwd)/configrepo
  cfg_git="git -C $dir_configrepo"
  # We noticed that curl'ing the config file was too slow sometimes due to
  # GitHub's caching. This is a (unfortunately rather expensive) workaround
  # for the issue.
  git clone $BRANCHCONFIG_REPO $dir_configrepo
  $cfg_git reset --hard origin/$BRANCHCONFIG_BRANCH
  CONFIGXML=$(cat "$dir_configrepo/$BRANCHCONFIG")
  CONFIGDTD="$dir_configrepo/$DTD"

  # If $CONFIGXML is a valid XML document and produces no errors...
  cd "$dir_configrepo"
  echo -e "$CONFIGXML" | xmllint --noout --noent --dtdvalid $CONFIGDTD -
  code=$?
  cd - >/dev/null 2>/dev/null

  if [[ $code -eq 0 ]]; then
    RELEVANTCATS=$(echo -e "$CONFIGXML" | xml sel -t -v '//cats/cat[@repo="'"$REPO"'"]/@id')

    RELEVANTBRANCHES=
    for CAT in $RELEVANTCATS; do
      RELEVANTBRANCHES+=$(echo -e "$CONFIGXML" | xml sel -t -v '//doc[@cat="'"$CAT"'"]/@branches')'\n'
    done

    RELEVANTBRANCHES=$(echo -e "$RELEVANTBRANCHES" | tr ' ' '\n' | sort -u)

    if [[ $(echo -e "$RELEVANTBRANCHES" | grep "^$TRAVIS_BRANCH\$") ]] || \
     [[ $(echo -e "$RELEVANTBRANCHES" | grep "^$PRODUCT\$") ]]; then
      BUILDDOCS=1
      log "Enabling builds.\n"
      for CAT in $RELEVANTCATS; do
        for BRANCHNAME in "$TRAVIS_BRANCH" "$PRODUCT"; do
          DCBUILDLIST+=$(echo -e "$CONFIGXML" | xml sel -t -v '//doc[@cat="'"$CAT"'"][@branches[contains(concat(" ",.," "), " '"$BRANCHNAME"' ")]]/@doc')'\n'
        done
      done
      DCBUILDLIST=$(echo -e "$DCBUILDLIST" | tr ' ' '\n' | sed -r 's/^(.)/DC-\1/' | sort -u)
      [[ -z "$DCBUILDLIST" ]] && log "No DC files enabled for build. $BRANCHCONFIG is probably invalid.\n"
    else
      log "This branch does not appear to be configured to build.\n"
    fi
  else
      log "Cannot determine whether to build, configuration file $BRANCHCONFIG is unavailable or invalid. Will not build.\n"
  fi

else
  log "Builds were force-disabled, skipping validation of build configuration file $BRANCHCONFIG."
fi
travis_fold --


# Check /all/ DC files for basic sanity
insanedc=
for DC in DC-*; do
    [[ ! -f $DC ]] && insanedc+="* $DC is a directory.\n" && continue
    [[ ! $(grep -oP '^\s*MAIN\s*=\s*.*' $DC) ]] && insanedc+="* $DC does not have a valid \"MAIN\" value.\n" && continue
    [[ $(grep -oP '^\s*MAIN\s*=\s*.*' $DC | wc -l) -gt 1 ]] && insanedc+="* $DC has multiple \"MAIN\" values.\n" && continue
    main=$(get_dc_value 'MAIN' "$DC")
    dir="xml"
    [[ $(echo "$main" | grep -oP '\.adoc$') ]] && dir="adoc"
    [[ ! -f "$dir/$main" ]] && insanedc+="* The \"MAIN\" file referenced in $DC does not exist.\n"
done

if [[ ! -z "$insanedc" ]]; then
    fail "The following DC file(s) from the repository are not valid:\n$insanedc\n"
fi

DCLIST=$(ls DC-*-all 2>/dev/null)
if [[ -f "$DCVALIDATE" ]]; then
    DCLIST=$(cat "$DCVALIDATE")
elif [ -z "$DCLIST" ] ; then
    DCLIST=$(ls DC-*)
fi

if [ -z "$DCLIST" ] ; then
    fail "There are no DC files to validate in this repository."
fi

# Do this first, so this fails as quickly as possible.
unavailable=
for DCFILE in $DCLIST; do
    [[ ! -f $DCFILE ]] && unavailable+="$DCFILE "
done
if [[ ! -z $unavailable ]]; then
    fail "DC file(s) is/are configured in $DCVALIDATE but not present in repository:\n$unavailable"
fi

for DCFILE in $DCLIST; do
    travis_fold "Validating $DCFILE (with $(rpm -qv geekodoc))..."
    echo ""

    main=$(get_dc_value 'MAIN' "$DCFILE")
    if [[ $(echo "$main" | grep -oP '\.adoc$') ]]; then
        doctype='book'
        dir="adoc"
        [[ $(get_dc_value 'ADOC_TYPE' "$DCFILE") == 'article' ]] && doctype='article'
        asciidoctor_messages=$(asciidoctor --attribute=imagesdir! \
          --backend=docbook5 --doctype=$doctype \
          --out-file=/tmp/irrelevant $dir/$main 2>&1)
        [[ "$asciidoctor_messages" ]] && {
            echo -e "$asciidoctor_messages"
            fail "AsciiDoctor produces error or warning messages."
        }
    fi
    $DAPS_SR -vv -d $DCFILE validate || exit 1
    log "\nChecking for missing images in $DCFILE ...\n"
    MISSING_IMAGES=$($DAPS_SR -d $DCFILE list-images-missing)
    if [ -n "$MISSING_IMAGES" ]; then
        fail "Missing images:\n$MISSING_IMAGES"
    else
        log + "All images available."
    fi
    if [[ $DISABLE_ID_CHECK -eq 1 ]]; then
      travis_fold --
      log - "ID check is disabled!"
      continue
    fi
    log "\nChecking for IDs with characters that are not A-Z, a-z, 0-9, or - in $DCFILE ...\n"
    BIGFILE=$($DAPS_SR -d $DCFILE bigfile)
    FAILING_IDS=$(xml sel -t -v '//@xml:id|//@id' $BIGFILE | grep -P '[^-a-zA-Z0-9]' | sed -r 's/(^|$)/"/g')
    if [ -n "$FAILING_IDS" ]; then
        log "IDs must only contain characters from the following sets:\n  A-Z    a-z    0-9    -"
        fail "The following IDs have forbidden characters in them:\n$FAILING_IDS"
    else
        log + "All IDs comply with the allowed character set."
    fi
    travis_fold --
    wait
done

TEST_NUMBER='^[0-9]+$'
if [[ $TRAVIS_PULL_REQUEST =~ $TEST_NUMBER ]] ; then
    succeed "This is a Pull Request, therefore will not build.\nExiting cleanly.\n"
fi

if [[ $BUILDDOCS -eq 0 ]]; then
    succeed "The branch $TRAVIS_BRANCH is not configured for builds.\n(If that is unexpected, check whether the $PRODUCT branch of this repo is configured correctly in the configuration file at $BRANCHCONFIG_URL.)\nExiting cleanly.\n"
elif [[ $BUILDDOCS -eq -1 ]]; then
    succeed "Builds are force-disabled due to missing environment variables. See above output."
fi

buildunavailable=
for DCFILE in $DCBUILDLIST; do
    [[ ! -f $DCFILE ]] && buildunavailable+="$DCFILE "
done
if [[ -n $buildunavailable ]]; then
    fail "DC file(s) is/are configured in $BRANCHCONFIG but not present in repository:\n$buildunavailable"
fi

if [[ -z "$DCBUILDLIST" ]]; then
    fail "The branch $TRAVIS_BRANCH is enabled for building but there are no valid DC files configured for it. This should never happen. If it does, $BRANCHCONFIG is invalid or the travis.sh script from doc-ci is buggy.\n"
fi

travis_fold "Importing encrypted SSH deploy key"
# Decrypt the SSH private key
openssl aes-256-cbc -md md5 -pass "pass:$ENCRYPTED_PRIVKEY_SECRET" -in ./ssh_key.enc -out ./ssh_key -d -a
# SSH refuses to use the key if its readable to the world
chmod 0600 ssh_key
# Start the SSH authentication agent
eval $(ssh-agent -s)
# Display the key fingerprint from the file
ssh-keygen -lf ssh_key
# Import the private key
ssh-add ssh_key
# Display fingerprints of available SSH keys
ssh-add -l
travis_fold --

# Build HTML and single HTML as drafts
for DCFILE in $DCBUILDLIST; do
    travis_fold "Building $DCFILE"
    styleroot=$(grep -P '^\s*STYLEROOT\s*=\s*' $DCFILE | sed -r -e 's/^[^=]+=\s*["'\'']//' -e 's/["'\'']\s*//')
    dapsbuild=$DAPS
    if [[ ! -d "$styleroot" ]]; then
      dapsbuild=$DAPS_SR
      log - "$DCFILE requests style root $styleroot which is not installed. Replacing with default style root."
    fi
    log "\nBuilding HTML for $DCFILE ...\n"
    $dapsbuild -d $DCFILE html --draft || exit 1
    log "\nBuilding single HTML for $DCFILE ...\n"
    $dapsbuild -d $DCFILE html --single --draft || exit 1
    travis_fold --
    wait
done

# Now clone the GitHub pages repository, checkout the gh-pages branch and clean files
travis_fold "Cloning publishing repository and performing publishing repo maintenance"


# Set the git username and email used for the commits
git config --global user.name "Travis CI"
git config --global user.email "$COMMIT_AUTHOR_EMAIL"

mkdir ~/.ssh
ssh-keyscan github.com >> ~/.ssh/known_hosts
log "Cloning GitHub Pages repository\n"
PUBREPO=/tmp/$REPO
git clone ssh://git@github.com/SUSEdoc/$REPO.git $PUBREPO

GIT="git -C $PUBREPO"
BRANCH=gh-pages

$GIT checkout $BRANCH

# Every 35 commits ($MAXCOMMITS), we reset the repo, so it does not become too
# large. (When the repo becomes too large, that raises the probability of
# Travis failing because of a timeout while cloning.)
if [[ $(PAGER=cat $GIT log --oneline --format='%h' | wc -l) -ge $MAXCOMMITS ]]; then
  travis_fold "Resetting repository, so it does not become too large"
  # nicked from: https://stackoverflow.com/questions/13716658
  $GIT checkout --orphan new-branch
  $GIT add -A . >/dev/null
  $GIT commit -am "Repo state reset by travis.sh"
  $GIT branch -D $BRANCH
  $GIT branch -m $BRANCH
  $GIT push -f origin $BRANCH
  travis_fold --
fi

# Clean up build results of branches that we don't build anymore

# FIXME: the sed below is very dependent on the names of publishing formats,
# however, it seemed the best way to cover the case the we build a branch like
# "feature/bla" which in our directory structure will become dir "feature",
# subdir "bla".
PUBDIRS=$(find "$PUBREPO" -type d | \
    cut -b$(($(echo "$PUBREPO" | wc -c) + 1))- | \
    sed -n '/\./ !p' | \
    sed -r 's%/[^/]+(/(single-)?html(/[^/]+)*)?$%%' | \
    sort -u)

PUBDIRPREFIXES=$(echo -e "$PUBDIRS" | sed -n '/\// p' | cut -f1 -d'/')

RELEVANTPUBDIRS=$(comm -2 -3 <(echo -e "$PUBDIRS") <(echo -e "$PUBDIRPREFIXES"))

OLDPUBDIRS=$(comm -2 -3 <(echo -e "$RELEVANTPUBDIRS") <(echo -e "$RELEVANTBRANCHES"))

#for OLDDIR in $OLDPUBDIRS; do
#    log "Removing directory for branch $OLDDIR which is not built anymore."
#    rm -r $PUBREPO/$OLDDIR
#done

# Out with the old content...
rm -r $PUBREPO/$PRODUCT

travis_fold --

# In with the new content...
# Copy the HTML and single HTML files for each DC file
travis_fold "Moving built files to publishing repository"
echo ""

# Publish file names with an underscore:
# https://help.github.com/en/enterprise/2.14/user/articles/files-that-start-with-an-underscore-are-missing
touch $PUBREPO/.nojekyll

for DCFILE in $DCBUILDLIST; do
    MVFOLDER=$(echo $DCFILE | sed -e 's/DC-//g')
    htmldir="$PUBREPO/$PRODUCT/html/$MVFOLDER/"
    shtmldir="$PUBREPO/$PRODUCT/single-html/$MVFOLDER/"

    htmlurl="$PRODUCT/html/$MVFOLDER/"
    shtmlurl="$PRODUCT/single-html/$MVFOLDER/"

    legacyhtmldir="$PUBREPO/$PRODUCT/$MVFOLDER/html"
    legacyshtmldir="$PUBREPO/$PRODUCT/$MVFOLDER/single-html"

    log "Moving $DCFILE..."
    mkdir -p $htmldir $shtmldir
    echo "  /usr/src/app/build/$MVFOLDER/html -> $htmldir"
    mv /usr/src/app/build/$MVFOLDER/html/*/* $htmldir
    echo "  /usr/src/app/build/$MVFOLDER/single-html -> $shtmldir"
    mv /usr/src/app/build/$MVFOLDER/single-html/*/* $shtmldir
    echo "  Adding Beta warning messages to HTML files"
    # We need to avoid touching files twice (the regex is not quite safe
    # enough for that), hence it is important to exclude symlinks.
    warnfiles=$(find $htmldir -type f -name '*.html')' '$(find $shtmldir -type f -name '*.html')
    warningtext='This is a draft document that was built and uploaded automatically. It may document beta software and be incomplete or even incorrect. <strong>Use this document at your own risk.<\/strong>'
    warningbutton='I understand this is a draft'
    cookiedays="0.5" # retention time for cookie = .5 days aka 12 hours
    for warnfile in $warnfiles; do
      sed -r -i \
        -e 's/<\/head><body[^>]*/& onload="$('"'"'#betawarn-button-wrap'"'"').toggle();if (document.cookie.length > 0) {if (document.cookie.indexOf('"'"'betawarn=closed'"'"') != -1){$('"'"'#betawarn'"'"').toggle()}};"><div id="betawarn" style="position:fixed;bottom:0;z-index:9025;background-color:#FDE8E8;padding:1em;margin-left:10%;margin-right:10%;display:block;border-top:.75em solid #E11;width:80%"><p style="color:#333;margin:1em 0;padding:0;">'"$warningtext"'<\/p> <div id="betawarn-button-wrap" style="display:none;margin:0;padding:0;"><a href="#" onclick="$('"'"'#betawarn'"'"').toggle();var d=new Date();d.setTime(d.getTime()+('"$cookiedays"'*24*60*60*1000));document.cookie='"'"'betawarn=closed; expires='"'"'+d.toUTCString()+'"'"'; path=\/'"'"'; return false;" style="color:#333;text-decoration:underline;float:left;margin-top:.5em;padding:1em;display:block;background-color:#FABEBE;">'"$warningbutton"'<\/a><\/div><\/div/' \
        -e 's/ id="(_fixed-header-wrap|_white-bg)"/& style="background-color: #FABEBE;"/g'\
        $warnfile
    done

    mkdir -p $legacyhtmldir $legacyshtmldir
    echo '<html><head><meta http-equiv="refresh" content="0;URL='"'https://susedoc.github.io/$REPO/$htmlurl'"'"></head><title>Redirect</title><body><a href="'"https://susedoc.github.io/$htmlurl"'">'"$htmlurl"'</a></body></html>' > "$legacyhtmldir/index.html"
    echo '<html><head><meta http-equiv="refresh" content="0;URL='"'https://susedoc.github.io/$REPO/$shtmlurl'"'"></head><title>Redirect</title><body><a href="'"https://susedoc.github.io/$shtmlurl"'">'"$shtmlurl"'</a></body></html>' > "$legacyshtmldir/index.html"

    wait
done
travis_fold --

# Add all changed files to the staging area, commit and push
travis_fold "Deploying build results from original commit $TRAVIS_COMMIT (from $REPO) to GitHub Pages."
echo ""
$GIT add -A .
log "Commit"
$GIT commit -m "Deploy to GitHub Pages: ${TRAVIS_COMMIT}"
log "Push"
$GIT push origin $BRANCH
travis_fold --

succeed "We're done."
