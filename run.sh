#!/bin/bash

if [ -z "$WERCKER_SLACK_POST_URL" ]; then
  fail 'Missing url property'
fi

DEPLOY=true

if [ -z "$WERCKER_SLACK_POST_USERNAME" ]; then
  # Default username - werckerbot
  if [ -n "$DEPLOY" ] ; then
    export WERCKER_SLACK_POST_USERNAME=deploybot
  else
    export WERCKER_SLACK_POST_USERNAME=buildbot
  fi
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
  export WERCKER_ACT="build"
  export WERCKER_ACT_TITLE="Build"
  export WERCKER_SLACK_POST_WURL="<$WERCKER_BUILD_URL|#${WERCKER_BUILD_ID:0:7}>"
else
  export WERCKER_ACT="deploy"
  export WERCKER_ACT_TITLE="Deploy"
  export WERCKER_SLACK_POST_WURL="<$WERCKER_DEPLOY_URL|#${WERCKER_DEPLOY_ID:0:7}>"
fi

if [[ $WERCKER_GIT_DOMAIN == bitbucket* ]]; then export GIT_TREE="commits"; else export GIT_TREE="commit"; fi

# Get the time of the build
WERCKER_TIME_START=${WERCKER_MAIN_PIPELINE_STARTED-$(date +"%s")}
WERCKER_TIME_END=$(date +"%s")
WERCKER_TIME_DIFF=$(($WERCKER_TIME_END-$WERCKER_TIME_START))
WERCKER_TIME_SPENT="$(($WERCKER_TIME_DIFF / 60)) min $(($WERCKER_TIME_DIFF % 60)) sec."

LATEST_COMMIT=$(git log -1 --pretty=%B)
COMMIT_HEADER="$(echo "$LATEST_COMMIT" | head -n 1 )"
COMMIT_BODY=$(echo "$LATEST_COMMIT" | tail -n +2)
COMMIT_BODY=${COMMIT_BODY#"${COMMIT_BODY%%[![:space:]]*}"}
export WERCKER_SLACK_POST_GIT="<http://$WERCKER_GIT_DOMAIN/$WERCKER_GIT_OWNER/$WERCKER_GIT_REPOSITORY/$GIT_TREE/$WERCKER_GIT_COMMIT|$WERCKER_GIT_REPOSITORY/$WERCKER_GIT_BRANCH@${WERCKER_GIT_COMMIT:0:3}..>"
export WERCKER_SLACK_POST_GIT="<http://$WERCKER_GIT_DOMAIN/$WERCKER_GIT_OWNER/$WERCKER_GIT_REPOSITORY/$GIT_TREE/$WERCKER_GIT_COMMIT|#${WERCKER_GIT_COMMIT:0:7}>"

WERCKER_SLACK_FALLBACK_MESSAGE="$WERCKER_APPLICATION_NAME:\
 $WERCKER_ACT_TITLE #${WERCKER_DEPLOY_ID:0:5}\
 [$WERCKER_GIT_REPOSITORY/$WERCKER_GIT_BRANCH@${WERCKER_GIT_COMMIT:0:7}]\
 by $WERCKER_STARTED_BY $WERCKER_RESULT."

export SUMMARY="$WERCKER_ACT_TITLE $WERCKER_SLACK_POST_WURL\
 ${WERCKER_RESULT} in $WERCKER_TIME_SPENT"

case "$WERCKER_RESULT" in
  "passed") export MESSAGE_COLOR="#36A64F" ;;
  "failed") export MESSAGE_COLOR="#A63636" ;;
  *)        export MESSAGE_COLOR="#3663A6" ;;
esac

function json_escape() {
  echo -n "$1" | python -c 'import json,sys; print json.dumps(sys.stdin.read())'
}

# This is a build. Send a build message
[ -z "$DEPLOY" ] && json=$(cat <<END
{
  "fallback": "$WERCKER_SLACK_FALLBACK_MESSAGE",
  "channel":  "#$WERCKER_SLACK_POST_CHANNEL",
  "icon_url": "https://raw.githubusercontent.com/tarwich/wercker-step-slack-post/master/icons/${WERCKER_ACT}-${WERCKER_RESULT}.png",
  "username": "$WERCKER_SLACK_POST_USERNAME",
  "attachments": [{
    "fallback":    "Build $WERCKER_RESULT in $WERCKER_TIME_SPENT",
    "color":       "$MESSAGE_COLOR",
    "author_name": "$WERCKER_STARTED_BY",
    "author_link": "https://github.com/$WERCKER_STARTED_BY",
    "title":       $(json_escape "$COMMIT_HEADER"),
    "title_link":  "http://$WERCKER_GIT_DOMAIN/$WERCKER_GIT_OWNER/$WERCKER_GIT_REPOSITORY/$GIT_TREE/$WERCKER_GIT_COMMIT",
    "text":        $(json_escape "$COMMIT_BODY"),
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
        },
        {
            "title": "$WERCKER_ACT_TITLE $WERCKER_RESULT",
            "value": "$WERCKER_SLACK_POST_WURL",
            "short": true
        },
        {
            "title": "Time",
            "value": "$WERCKER_TIME_SPENT",
            "short": true
        }
    ]
  }]
}
END
)


DEPLOY_MESSAGE="Deployment of $WERCKER_APPLICATION_NAME\
 from branch \`$WERCKER_GIT_BRANCH\` *${WERCKER_RESULT}* for commit\
 $WERCKER_SLACK_POST_GIT"

# This is a deployment. Send a deployment message
[ -n "$DEPLOY" ] && json=$(cat <<END
{
  "fallback": "$WERCKER_SLACK_FALLBACK_MESSAGE",
  "channel":  "#$WERCKER_SLACK_POST_CHANNEL",
  "icon_url": "https://raw.githubusercontent.com/tarwich/wercker-step-slack-post/master/icons/${WERCKER_ACT}-${WERCKER_RESULT}.png",
  "username": "$WERCKER_SLACK_POST_USERNAME",
  "attachments": [{
    "fallback":    "Deploy $WERCKER_RESULT in $WERCKER_TIME_SPENT",
    "color":       "$MESSAGE_COLOR",
    "mrkdwn_in":   ["text"],
    "text":        "$DEPLOY_MESSAGE"
  }]
}
END
)

RESULT=`curl -d "payload=$json" -s  "$WERCKER_SLACK_POST_URL" --output $WERCKER_STEP_TEMP/result.txt -w "%{http_code}"`

if [ "$RESULT" = "500" ]; then
  # Show the JSON payload
  warn "$json\n"

  if grep -Fqx "No token" $WERCKER_STEP_TEMP/result.txt; then
    fail "No token is specified."
  elif grep -Fqx "No hooks" $WERCKER_STEP_TEMP/result.txt; then
    fail "No hook can be found for specified subdomain/token"
  elif grep -Fqx "Invalid channel specified" $WERCKER_STEP_TEMP/result.txt; then
    fail "Could not find specified channel for subdomain/token."
  elif grep -Fqx "No text specified" $WERCKER_STEP_TEMP/result.txt; then
    fail "No text specified."
  else
    fail "$(cat $WERCKER_STEP_TEMP/result.txt)"
  fi
fi

if [ "$RESULT" = "404" ]; then
  fail "Subdomain or token not found."
fi

echo "Result:  $RESULT"
