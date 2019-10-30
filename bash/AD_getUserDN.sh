#!/bin/bash
# This script searches SAMAccountName of an user account in AD and prints userDN attribute if succeeds.
# The variables that starts with SRC comes from a source file (such as scriptname.sh.source)
 
OLDIFS=$IFS
IFS=$'\n'

bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
magenta=$(tput setaf 5)
cyan=$(tput setaf 6)
white=$(tput setaf 7)

SAMACCOUNTNAME=$1

############ Check script usage ##############################

if [ $# -ne 1 ]; then
  echo "USAGE: $0 <username>"
  exit 1
fi

########### Get user attributes from ldap ########################

source `basename "$0"`.source
for KV in $(ldapsearch -o ldif-wrap=no -x -h $SRC_LDAPDC -D $SRC_LDAPUSER -w $SRC_LDAPPASS -b $SRC_LDAPBASEDN -s sub -LLL "(sAMAccountName=$SAMACCOUNTNAME)" distinguishedName)
do
  if [[ $KV = *"distinguishedName:"* ]]; then USERDN=$(echo $KV | cut -d ":" -f 2 | xargs); fi
done

if [[ -z "$USERDN" ]]; then
  echo "*** LDAP query returned no results for $SAMACCOUNTNAME ***"
else
  printf "User Details: ${white}${bold}$USERDN${reset}\n"
fi

IFS=$OLDIFS

