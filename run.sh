#!/bin/bash

function main() {
  load_env
  check_requirements
  gather_wercker_facts
  gather_git_facts
  gather_slack_facts
  build_json
  send_slack_message
}

#
# Prepare the json message that will be sent to Slack
#
function build_json() {
  # This is a build. Send a build message
  if [[ $WERCKER_ACTION = "build"  ]] ; then
    SLACK_JSON=$(cat <<END
      {
        "fallback": "$SLACK_FALLBACK_MESSAGE",
        "channel":  "#$SLACK_CHANNEL",
        "icon_url": "$SLACK_AVATAR",
        "username": "$SLACK_USERNAME",
        "attachments": [{
          "author_name": "$GIT_AUTHOR",
          "author_link": "https://$GIT_DOMAIN/$GIT_AUTHOR",
          "color":       "$SLACK_COLOR",
          "fallback":    "$SLACK_FALLBACK_MESSAGE",
          "mrkdwn_in":   ["text"],
          "text":        $(json_string "$COMMIT_BODY"),
          "title_link":  "$GIT_COMMIT_URL",
          "title":       $(json_string "$COMMIT_HEADER"),
          "fields": [
          {
            "title": "Commit",
            "value": "<$GIT_COMMIT_URL|#$GIT_COMMIT>",
            "short": true
          },
          {
            "title": "Branch",
            "value": "<https://$GIT_DOMAIN/$GIT_OWNER/$GIT_REPOSITORY/$GIT_TREE/$GIT_BRANCH|$GIT_BRANCH>",
            "short": true
          },
          {
            "title": "$(ucfirst $WERCKER_ACTION) $WERCKER_RESULT",
            "value": "<$WERCKER_JOB_URL|#$WERCKER_JOB_ID>",
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
  fi

  # This is a deployment. Send a deployment message
  if [[ "$WERCKER_ACTION" = "deploy" ]] ; then
    SLACK_JSON=$(cat <<END
      {
        "fallback":  "$SLACK_FALLBACK_MESSAGE",
        "channel":   "#$SLACK_CHANNEL",
        "icon_url":  "$SLACK_AVATAR",
        "username":  "$SLACK_USERNAME",
        "attachments": [{
          "fallback":  "Deploy $WERCKER_RESULT in $WERCKER_TIME_SPENT",
          "color":     "$SLACK_COLOR",
          "mrkdwn_in": ["text"],
          "text":      "$SLACK_DEPLOYMENT_MESSAGE"
        }]
      }
END
    )
  fi
}

#
# Ensure anything necessary is available in the system before we continue
#
function check_requirements() {
  # This script requires python at the moment, but later we might not
  type python 1>/dev/null 2>&1 || fail "This step requires python to be installed"
  type git 1>/dev/null 2>&1 || fail "This step requires git to be installed"
}

#
# Send an error message and then exit the script
#
# @param $1 {String} The error message to output
#
type fail 1>/dev/null 2>&1 || function fail() {
  echo -e "${C_RED}${1:-"An unknown error has occurred"}${C_RESET}"
  exit 1
}

#
# Get information about the current git tip
#
# Gathers information about the repository, the last git commit, and splits the
# latest commit message by first line to have a header and body
#
function gather_git_facts() {
  # I generally try to keep things sorted, but this function must run in the
  # order written. You can add new things alphabetically, but you can't re-order
  # the existing things
  GIT_BASE_URL=$(git config --get remote.origin.url)
  # ----------[ GIT_PROTOCOL ]----------------------------------------
  GIT_PROTOCOL="https"
  # ----------[ GIT_DOMAIN ]----------------------------------------
  GIT_DOMAIN=${GIT_BASE_URL#http*//}
  GIT_DOMAIN=${GIT_DOMAIN#git@}
  GIT_DOMAIN=${GIT_DOMAIN%%/*}
  GIT_DOMAIN=${GIT_DOMAIN%%:*}
  # ----------[ GIT_OWNER ]----------------------------------------
  GIT_OWNER=${GIT_BASE_URL#*$GIT_DOMAIN?}
  GIT_OWNER=${GIT_OWNER%%/*}
  # ----------[ GIT_REPOSITORY ]----------------------------------------
  GIT_REPOSITORY=${GIT_BASE_URL##*/}  # Slice off everything before the last '/'
  GIT_REPOSITORY=${GIT_REPOSITORY%.git*} # Slice off the .git if present
  # ----------[ GIT_COMMIT ]----------------------------------------
  GIT_COMMIT=$(git rev-parse --short HEAD)
  # ----------[ GIT_AUTHOR ]----------------------------------------
  GIT_AUTHOR=$(git log -1 --pretty=format:%an)
  # ----------[ GIT_TREE ]----------------------------------------
  # github.com uses http://.../commit but bitbucket uses http://.../commits
  case $GIT_DOMAIN in
    github.com)    GIT_TREE=tree   ;;
    bitbucket.com) GIT_TREE=branch ;;
    *)             GIT_TREE=branch ;;
  esac
  # ----------[ GIT_COMMITS ]----------------------------------------
  # github.com uses http://.../commit but bitbucket uses http://.../commits
  case $GIT_DOMAIN in
    github.com)    GIT_COMMITS=commit  ;;
    bitbucket.com) GIT_COMMITS=commits ;;
    *)             GIT_COMMITS=commit  ;;
  esac
  # ----------[ GIT_BRANCH ]----------------------------------------
  #
  GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  # ----------[ GIT_COMMIT_URL ]----------------------------------------
  GIT_COMMIT_URL="http://$GIT_DOMAIN/$GIT_OWNER/$GIT_REPOSITORY/$GIT_COMMITS/$GIT_COMMIT"
  # ----------[ COMMIT_HEADER ]----------------------------------------
  LATEST_COMMIT=$(git log -1 --pretty=%B)
  COMMIT_HEADER="$(echo "$LATEST_COMMIT" | head -n 1 )"
  COMMIT_HEADER=$(git log -1 --pretty=%s)
  # ----------[ COMMIT_BODY ]----------------------------------------
  COMMIT_BODY=$(echo "$LATEST_COMMIT" | tail -n +2)
  COMMIT_BODY=${COMMIT_BODY#"${COMMIT_BODY%%[![:space:]]*}"}
  COMMIT_BODY=$(git log -1 --pretty=%b)
}

#
# Gather information pertaining to slack
#
function gather_slack_facts() {
  # ----------[ SLACK_AVATAR ]----------------------------------------
  # The avatar that will appear in the slack message
  SLACK_AVATAR=$(echo WERCKER_SLACK_POST_ICON_${WERCKER_ACTION}_${WERCKER_RESULT} | tr a-z A-Z)
  SLACK_AVATAR="${!SLACK_AVATAR}?$WERCKER_STEP_VERSION"

  # ----------[ SLACK_CHANNEL ]----------------------------------------
  # What channel should we post in
  SLACK_CHANNEL=${WERCKER_SLACK_POST_CHANNEL#*\#} # Strip leading '#'

  # ----------[ SLACK_COLOR ]----------------------------------------
  # The message should be colored red on error and green on success
  case $WERCKER_RESULT in
    passed) SLACK_COLOR=${WERCKER_SLACK_POST_COLOR_PASSED} ;;
    failed) SLACK_COLOR=${WERCKER_SLACK_POST_COLOR_FAILED} ;;
    *)      SLACK_COLOR="#3663A6"                          ;;
  esac

  # ----------[ SLACK_DEPLOYMENT_MESSAGE ]----------------------------------------
  # The message that will be shown for deployment status
  SLACK_DEPLOYMENT_MESSAGE=$(echo Deployment of _${WERCKER_APPLICATION_NAME}_ \
    from branch "\`$GIT_BRANCH\`" *${WERCKER_RESULT}* for commit \
    "<$GIT_COMMIT_URL|#$GIT_COMMIT>")

  # ----------[ SLACK_FALLBACK_MESSAGE ]----------------------------------------
  # The message that Slack shows when it can only render a short text
  # description of the message (Such as with push notifications)
  SLACK_FALLBACK_MESSAGE=$(echo $(ucfirst $WERCKER_ACTION) of \
    $WERCKER_APPLICATION_NAME $WERCKER_RESULT for commit "#$GIT_COMMIT" of \
    $GIT_BRANCH)

  # ----------[ SLACK_JOB_URL ]----------------------------------------
  # When we make the message, we can dump this in various places to
  # have a link back to the job that started everything
  SLACK_JOB_URL="<$WERCKER_JOB_URL|#${WERCKER_JOB_ID:0:7}>"

  # ----------[ SLACK_URL ]----------------------------------------
  # The url, which serves as an access token for submitting to Slack
  SLACK_URL=${WERCKER_SLACK_POST_URL}
  [[ -z "$SLACK_URL" ]] && fail "Missing url property"

  # ----------[ SLACK_USERNAME ]----------------------------------------
  # The username to display when posting in Slack
  if [ -n "$WERCKER_SLACK_POST_USERNAME" ]; then
    SLACK_USERNAME=$WERCKER_SLACK_POST_USERNAME
  else
    # Default username - werckerbot
    if [ -n "$DEPLOY" ] ; then
      SLACK_USERNAME=${WERCKER_SLACK_POST_DEPLOY_USERNAME:-deploybot}
    else
      SLACK_USERNAME=${WERCKER_SLACK_POST_BUILD_USERNAME:-buildbot}
    fi
  fi
}

#
# Gather information pertaining to wercker
#
function gather_wercker_facts() {
  # ----------[ WERCKER_ACTION ]----------------------------------------
  # The type of build we're in -- either "build" or "deploy"
  if [[ -n "$DEPLOY" ]]; then
    WERCKER_ACTION="deploy"
    WERCKER_JOB_URL=$WERCKER_DEPLOY_URL
    WERCKER_JOB_ID=${WERCKER_DEPLOY_ID:0:7}
  else
    WERCKER_ACTION="build"
    WERCKER_JOB_URL=$WERCKER_BUILD_URL
    WERCKER_JOB_ID=${WERCKER_BUILD_ID:0:7}
  fi

  # ----------[ WERCKER_STEP_VERSION ]----------------------------------------
  # Get the current version of this step
  WERCKER_STEP_VERSION=$(grep -o '^version:.*' wercker-step.yml)
  WERCKER_STEP_VERSION=$(echo ${WERCKER_STEP_VERSION#*:})

  # ----------[ WERCKER_TIME_SPENT ]----------------------------------------
  # Find out how long it took to run this job
  WERCKER_TIME_START=${WERCKER_MAIN_PIPELINE_STARTED-$(date +"%s")}
  WERCKER_TIME_END=$(date +"%s")
  WERCKER_TIME_DIFF=$(($WERCKER_TIME_END-$WERCKER_TIME_START))
  WERCKER_TIME_SPENT="$(($WERCKER_TIME_DIFF / 60)) min $(($WERCKER_TIME_DIFF % 60)) sec."
}

#
# Escape an input string into a json string
#
function json_string() {
  echo -n "$1" | python -c 'import json,sys; print json.dumps(sys.stdin.read())'
}

#
# Load environment variables from local .env file for the purposes of local
# development and testing. Will have no effect in production, because (a) there
# won't be an .env file, and (b) the .env file is typically already loaded into
# the environment
#
function load_env() {
  # Load the local .env file if available
  [[ -f .env ]] && source .env

  # Import the variables prefixed by X_ into the local scope
  for VAR in $(compgen -v | grep ^X_) ; do
    local NEWVAR=${VAR#*X_}
    # declare -x ${NEWVAR}=${!VAR}
    export $NEWVAR=${!VAR}
  done

  # ----------[ Set defaults ]----------------------------------------
  WERCKER_SLACK_POST_CHANNEL=${WERCKER_SLACK_POST_CHANNEL:-general}
  WERCKER_SLACK_POST_BUILD_USERNAME=${WERCKER_SLACK_POST_BUILD_USERNAME:-buildbot}
  WERCKER_SLACK_POST_DEPLOY_USERNAME=${WERCKER_SLACK_POST_DEPLOY_USERNAME:-deploybot}
  WERCKER_SLACK_POST_ICON_BUILD_PASSED=${WERCKER_SLACK_POST_ICON_BUILD_PASSED:-https://raw.githubusercontent.com/tarwich/wercker-step-slack-post/master/icons/build-passed.png}
  WERCKER_SLACK_POST_ICON_BUILD_FAILED=${WERCKER_SLACK_POST_ICON_BUILD_FAILED:-https://raw.githubusercontent.com/tarwich/wercker-step-slack-post/master/icons/build-failed.png}
  WERCKER_SLACK_POST_ICON_DEPLOY_PASSED=${WERCKER_SLACK_POST_ICON_DEPLOY_PASSED:-https://raw.githubusercontent.com/tarwich/wercker-step-slack-post/master/icons/deploy-passed.png}
  WERCKER_SLACK_POST_ICON_DEPLOY_FAILED=${WERCKER_SLACK_POST_ICON_DEPLOY_FAILED:-https://raw.githubusercontent.com/tarwich/wercker-step-slack-post/master/icons/deploy-failed.png}
  WERCKER_SLACK_POST_COLOR_PASSED=${WERCKER_SLACK_POST_COLOR_PASSED:-"#36A64F"}
  WERCKER_SLACK_POST_COLOR_FAILED=${WERCKER_SLACK_POST_COLOR_FAILED:-"#A63636"}
}

#
# Capitalize the first letter of a string
#
# @param $1 {String} The string to work on
#
# @return Since BASH doesn't let you return things, this function `echo`s the
#         result, so you should call with a subshell like this: $()
#
function ucfirst() {
  echo -n ${1:0:1} | tr a-z A-Z
  echo -n ${1:1}
}

function send_slack_message() {
  if [[ -n "$DEBUG" ]] ; then info "$SLACK_JSON\n" ; fi

  RESULT=`curl -d "payload=$SLACK_JSON" -s  "$SLACK_URL" --output $WERCKER_STEP_TEMP/result.txt -w "%{http_code}"`

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
  elif [ "$RESULT" = "404" ]; then
    fail "Subdomain or token not found."
  elif [[  "$RESULT" = "200"  ]]; then
    info "Message sent"
  else
    warn "$json\n"
    fail "Unexpected result: $RESULT"
  fi
}

C_RESET=\\x1B[0m
C_GRAY=\\x1B[30m   # #3A463C# #
C_RED=\\x1B[31m    # #B12F31# #
C_GREEN=\\x1B[32m  # #2B7F27# #
C_YELLOW=\\x1B[33m # #A8A737# #
C_BLUE=\\x1B[34m   # #3B83D8# #
C_PURPLE=\\x1B[35m # #7A257E# #
C_CYAN=\\x1B[36m   # #349EB1# #
C_WHITE=\\x1B[37m  # #D0EAF1# #
C_NORMAL=\\x1B[38m # #849199# #

main $@
