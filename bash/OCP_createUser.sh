#!/bin/bash
# This script searches SAMAccountName of an user account in AD and creates user in OpenShift.
# OC Login required. OpenShift version: 3.11 
# The variables that starts with SRC comes from a source file (such as scriptname.sh.source)

OLDIFS=$IFS
IFS=$'\n'

SAMACCOUNTNAME=$1

################################ Check script usage ##############################

if [ $# -ne 1 ]; then
  echo "USAGE: $0 <username>"
  echo "Note: OC Login Required"
  exit 1
fi

###################### Check if user exists in OpenShift #########################

OCPUSER=$(oc get user $SAMACCOUNTNAME --no-headers -o name 2>/dev/null)
if [[ ! -z "$OCPUSER" ]]; then
  echo "*** $OCPUSER already exists in OpenShift ***"
  exit 2
fi

########### Get user attributes from ldap and create user ########################

source `basename "$0"`.source
for KV in $(ldapsearch -x -h $SRC_LDAPDC -D $SRC_LDAPUSER -w $SRC_LDAPPASS -b $SRC_LDAPBASEDN -s sub -LLL "(sAMAccountName=$SAMACCOUNTNAME)" sAMAccountName cn mail tcorganizationalmailgroup mobile)
do
  if [[ $KV = *"sAMAccountName:"* ]]; then USERSAM=$(echo $KV | cut -d ":" -f 2 | xargs | sed 's/+/00/g'); fi
  if [[ $KV = *"cn:"* ]]; then USERCN=$(echo $KV | cut -d ":" -f 2 | xargs); fi
  if [[ $KV = *"mail:"* ]]; then USERMAIL=$(echo $KV | cut -d ":" -f 2 | xargs | sed 's/@/-/g'); fi
  if [[ $KV = *"tcorganizationalmailgroup:"* ]]; then USERGROUP=$(echo $KV | cut -d ":" -f 2 | xargs); fi
  if [[ $KV = *"mobile:"* ]]; then USERMOBILE=$(echo $KV | cut -d ":" -f 2 | xargs | sed 's/+/00/g'); fi
done

if [[ -z "$USERSAM" ]]; then
  echo "*** LDAP query returned no results for $SAMACCOUNTNAME ***"
else
  echo "$SAMACCOUNTNAME does not exist in OpenShift. Creating..."
  echo "User Details: $USERCN | $USERMAIL | $USERGROUP | $USERMOBILE"
  oc create user $SAMACCOUNTNAME --full-name="$USERCN"
  oc create identity $SRC_LDAPDOMAIN:$SAMACCOUNTNAME
  oc create useridentitymapping $SRC_LDAPDOMAIN:$SAMACCOUNTNAME $SAMACCOUNTNAME
  oc label user/$SAMACCOUNTNAME tcmail=$USERMAIL tcgroup=$USERGROUP tcmobile=$USERMOBILE
fi

IFS=$OLDIFS

