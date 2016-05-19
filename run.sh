#!/bin/bash

if [ ! -n "$WERCKER_SLACK_POST_URL" ]; then
  fail 'Missing url property'
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
  export WERCKER_SLACK_POST_WURL="<$WERCKER_BUILD_URL|${WERCKER_BUILD_ID:0:5}...>"
else
  export WERCKER_SLACK_POST_ACT="deploy"
  export WERCKER_SLACK_POST_WURL="<$WERCKER_DEPLOY_URL|${WERCKER_DEPLOY_ID:0:5}...>"
fi

if [[ $WERCKER_GIT_DOMAIN == bitbucket* ]]; then export GIT_TREE="commits"; else export GIT_TREE="commit"; fi

# Get the time of the build
WERCKER_TIME_START=$WERCKER_MAIN_PIPELINE_STARTED
WERCKER_TIME_END=$(date +"%s")
WERCKER_TIME_DIFF=$(($WERCKER_TIME_END-$WERCKER_TIME_START))
WERCKER_TIME_SPENT="in $(($WERCKER_TIME_DIFF / 60)) min $(($WERCKER_TIME_DIFF % 60)) sec."

export LATEST_COMMIT=$(git log -1 --pretty=%B)
export WERCKER_SLACK_POST_GIT="<http://$WERCKER_GIT_DOMAIN/$WERCKER_GIT_OWNER/$WERCKER_GIT_REPOSITORY/$GIT_TREE/$WERCKER_GIT_COMMIT|$WERCKER_GIT_REPOSITORY/$WERCKER_GIT_BRANCH@${WERCKER_GIT_COMMIT:0:3}..>"
export WERCKER_SLACK_POST_GIT="<http://$WERCKER_GIT_DOMAIN/$WERCKER_GIT_OWNER/$WERCKER_GIT_REPOSITORY/$GIT_TREE/$WERCKER_GIT_COMMIT|$LATEST_COMMIT>"

WERCKER_SLACK_FALLBACK_MESSAGE="$WERCKER_APPLICATION_NAME:" \
" $WERCKER_SLACK_POST_ACT #${WERCKER_DEPLOY_ID:0:5}" \
" [$WERCKER_GIT_REPOSITORY/$WERCKER_GIT_BRANCH@${WERCKER_GIT_COMMIT:0:3}]" \
" by $WERCKER_STARTED_BY $WERCKER_RESULT."

export MESSAGE_TEXT="$WERCKER_SLACK_POST_ACT $WERCKER_SLACK_POST_WURL" \
" $WERCKER_RESULT in $WERCKER_TIME_SPENT" \

case "$WERCKER_RESULT" in
  "passed") export MESSAGE_COLOR="#36A64F" ;;
  "failed") export MESSAGE_COLOR="#A63636" ;;
  *)        export MESSAGE_COLOR="#3663A6" ;;
esac

# "channel":  "#$WERCKER_SLACK_POST_CHANNEL",
json=<<END
{
  "fallback": "$WERCKER_SLACK_FALLBACK_MESSAGE",
  "channel":  "#test",
  "icon_url": "https://2.gravatar.com/avatar/f777ecfdf484eed89dc6f215b78fef11?d=57",
  "username": "$WERCKER_SLACK_POST_USERNAME",
  "attachments": [{
    "fallback":    "Build $WERCKER_RESULT in $WERCKER_TIME_SPENT",
    "color":       "$MESSAGE_COLOR",
    "author_name": "$WERCKER_STARTED_BY",
    "title":       "$WERCKER_APPLICATION_NAME",
    "title_link":  "$WERCKER_APPLICATION_URL",
    "text":        "$MESSAGE_TEXT",
    "fields": [
        {
            "title": "Commit",
            "value": "$WERCKER_SLACK_POST_GIT",
            "short": true
        },
        {
            "title": "Branch",
            "value": "$WERCKER_GIT_BRANCH",
            "short": true
        }
    ],
    "image_url": "http://my-website.com/path/to/image.jpg",
    "thumb_url": "http://example.com/path/to/thumb.png"
  }]
}
END

RESULT=`curl -d "payload=$json" -s  "$WERCKER_SLACK_POST_URL" --output $WERCKER_STEP_TEMP/result.txt -w "%{http_code}"`

if [ "$RESULT" = "500" ]; then
  if grep -Fqx "No token" $WERCKER_STEP_TEMP/result.txt; then
    fail "No token is specified."
  fi

  if grep -Fqx "No hooks" $WERCKER_STEP_TEMP/result.txt; then
    fail "No hook can be found for specified subdomain/token"
  fi

  if grep -Fqx "Invalid channel specified" $WERCKER_STEP_TEMP/result.txt; then
    fail "Could not find specified channel for subdomain/token."
  fi

  if grep -Fqx "No text specified" $WERCKER_STEP_TEMP/result.txt; then
    fail "No text specified."
  fi
fi

if [ "$RESULT" = "404" ]; then
  fail "Subdomain or token not found."
fi


# https://thevoidray.slack.com/archives/flux/p1456943630000106
