#!/bin/bash -e
#
# From the GitHub repository:
# https://github.com/openSUSE/doc-ci
#
# License: MIT
#
# Written by Thomas Schraitle

VERSION="v0.9.0"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[33;1m'
NC='\033[0m' # No Color
URI='http://www.oasis-open.org/docbook/xml/4.5/dbcentx.mod'


# -----------------------------------------------------------
function travis_fold_start() {
  echo -e "travis_fold:start:$1${YELLOW}$2${NC}"
}

function travis_fold_end() {
  echo -e "\ntravis_fold:end:$1\r"
}

function travis_exec() {
  echo "$*"
  $*
}

# -----------------------------------------------------------
echo "*** $0 $VERSION ***
 Using variables:
   CACHE='${CACHE:?No CACHE variable in Travis defined}'
   XML_CATALOG_FILES='${XML_CATALOG_FILES:?No XML_CATALOG_FILES variable in Travis defined}'"

# -----------------------------------------------------------
travis_fold_start entitycache "List cache"
travis_exec ls $CACHE
travis_fold_end entitycache

# -----------------------------------------------------------
travis_fold_start catalog_creation "Create XML catalog"
travis_exec xmlcatalog --noout --create catalog.xml

travis_exec xmlcatalog --noout --add system \
    "$URI" \
    "$CACHE/dbcentx.mod" \
    catalog.xml
travis_fold_end catalog_creation


travis_fold_start catalog_check "Check XML catalog"
travis_exec xmlcatalog catalog.xml "$URI"
travis_fold_end catalog_check


# ---------------------
travis_fold_start download "Download and cache"
if [[ ! -e $CACHE/ent ]]; then
  travis_exec mkdir -p $CACHE
  travis_exec wget -P $CACHE http://docbook.org/xml/4.5/docbook-xml-4.5.zip
  travis_exec unzip -o -d $CACHE $CACHE/docbook-xml-4.5.zip
else
  echo "Using existing cache"
fi
travis_fold_end download


# ---------------------
travis_fold_start entities "Copy entities"
test -e xml || mkdir xml
cp -vi $CACHE/*.mod xml/
cp -avi $CACHE/ent xml/
travis_fold_end entities


# ---------------------
travis_fold_start xmlcheck "Check all XML files"
for file in $*; do
    printf ">>> Checking $file... $result"
    message=$(xmllint --nonet --noout --noent $file 2>&1)
    ret=$?
    if [[ $ret -eq 0 ]]; then
       result="${GREEN}Ok${NC}"
       printf "$result\n"
    else
        result="${RED}Error${NC}"
        printf "$result\n$message"
    fi
    result=""
done
travis_fold_end xmlcheck
