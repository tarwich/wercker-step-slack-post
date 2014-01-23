#!/bin/bash

if [ ! -n "$WERCKER_SLACK_POST_SUBDOMAIN" ]; then
  fatal 'Missing subdomain property'
fi

if [ ! -n "$WERCKER_SLACK_POST_TOKEN" ]; then
  fatal 'Missing token property'
fi

if [ ! -n "$WERCKER_SLACK_POST_USERNAME" ]; then
  # Default username - werckerbot
  export WERCKER_SLACK_POST_USERNAME=werckerbot
fi

if [ ! -n "$WERCKER_SLACK_POST_CHANNEL" ]; then
  # Default channel - #general
  export WERCKER_SLACK_POST_CHANNEL=general
fi

if [[ $WERCKER_SLACK_POST_CHANNEL == \#* ]]; then
  # Remove leading "#"
  WERCKER_SLACK_POST_CHANNEL=${WERCKER_SLACK_POST_CHANNEL:1}
fi

if [ ! -n "$DEPLOY" ]; then
  export WERCKER_SLACK_POST_ACT="build"
  export WERCKER_SLACK_POST_URL="<$WERCKER_BUILD_URL|${WERCKER_BUILD_ID:0:5}...>"
else
  export WERCKER_SLACK_POST_ACT="deploy"
  export WERCKER_SLACK_POST_URL="<$WERCKER_DEPLOY_URL|${WERCKER_DEPLOY_ID:0:5}...>"
fi

if [[ $WERCKER_GIT_DOMAIN == bitbucket* ]]; then export GIT_TREE="commits"; else export GIT_TREE="commit"; fi

export WERCKER_SLACK_POST_GIT="<http://$WERCKER_GIT_DOMAIN/$WERCKER_GIT_OWNER/$WERCKER_GIT_REPOSITORY/$GIT_TREE/$WERCKER_GIT_COMMIT|$WERCKER_GIT_REPOSITORY/$WERCKER_GIT_BRANCH@${WERCKER_GIT_COMMIT:0:3}..>"

export WERCKER_SLACK_POST_MESSAGE="$WERCKER_APPLICATION_OWNER_NAME/<$WERCKER_APPLICATION_URL|$WERCKER_APPLICATION_NAME> $WERCKER_SLACK_POST_ACT #$WERCKER_SLACK_POST_URL [$WERCKER_SLACK_POST_GIT] by $WERCKER_STARTED_BY $WERCKER_RESULT."

json="{\"text\":\"$WERCKER_SLACK_POST_MESSAGE\",\"channel\":\"#$WERCKER_SLACK_POST_CHANNEL\",\"icon_url\":\"https://2.gravatar.com/avatar/f777ecfdf484eed89dc6f215b78fef11?d=57\",\"username\":\"$WERCKER_SLACK_POST_USERNAME\"}"

RESULT=`curl -d "payload=$json" -s  "https://$WERCKER_SLACK_POST_SUBDOMAIN.slack.com/services/hooks/incoming-webhook?token=$WERCKER_SLACK_POST_TOKEN" --output $WERCKER_STEP_TEMP/result.txt -w "%{http_code}"`

if [ "$RESULT" = "500" ]; then
  if grep -Fqx "No token" $WERCKER_STEP_TEMP/result.txt; then
    fatal "No token is specified."
  fi

  if grep -Fqx "No hooks" $WERCKER_STEP_TEMP/result.txt; then
    fatal "No hook can be found for specified subdomain/token"
  fi

  if grep -Fqx "Invalid channel specified" $WERCKER_STEP_TEMP/result.txt; then
    fatal "Could not find specified channel for subdomain/token."
  fi

  if grep -Fqx "No text specified" $WERCKER_STEP_TEMP/result.txt; then
    fatal "No text specified."
  fi
fi

if [ "$RESULT" = "404" ]; then
  fatal "Subdomain or token not found."
fi