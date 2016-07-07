# slack-post

Posts wercker build/deploy status to a [Slack] channel.

This project is forked from the awesome work of [kobim]

[Slack]: https://slack.com/
[kobim]: https://github.com/kobim/wercker-step-slack-post

[![wercker status](https://app.wercker.com/status/63eff42dccc87c427d30f68a11e726d0/m "wercker status")](https://app.wercker.com/project/bykey/63eff42dccc87c427d30f68a11e726d0)

### Required fields

| Field | Description |
|-------|-------------|
| `url` | Your incoming [webhook url] |

[webhook url]: https://slack.com/services/new/incoming-webhook

### Optional fields

| Field                | Default   | Description |
|----------------------|-----------|-------------|
| `channel`            | #general  | The Slack channel to post messages to |
| `build-username`     | buildbot  | Username for the bot when the action is a build |
| `deploy-username`    | deploybot | Username for the bot when the action is a deployment |
| `icon-build-passed`  | ![Green Icon](https://raw.githubusercontent.com/tarwich/wercker-step-slack-post/master/icons/build-passed.png?v1.0.3) | An icon to use when the build passes |
| `icon-build-failed`  | ![Red Icon](https://raw.githubusercontent.com/tarwich/wercker-step-slack-post/master/icons/build-failed.png?v1.0.3) | An icon to use when the build fails |
| `icon-deploy-passed` | ![Green Icon](https://raw.githubusercontent.com/tarwich/wercker-step-slack-post/master/icons/deploy-passed.png?v1.0.3) | An icon to use when the deployment fails |
| `icon-deploy-failed` | ![Red Icon](https://raw.githubusercontent.com/tarwich/wercker-step-slack-post/master/icons/deploy-failed.png?v1.0.3) | An icon to use when the deployment passes |
| `color-passed`       | \#36A64F  | The color of the message when the deployment or build passes |
| `color-failed`       | \#A63636  | The color of the message when the deployment or build fails |

### How to configure?

Under your project settings, add after-step in your [wercker.yml] and provide `url` and any other variables you wish to set.

**Important!** It's highly recommended that you provide url, by setting an [environment variable] such as `SLACK_URL`, and then placing it in the [wercker.yml] file as seen below in the example.

[wercker.yml]: http://devcenter.wercker.com/articles/werckeryml/
[environment variable]: http://devcenter.wercker.com/docs/environment-variables/creating-env-vars.html

#### Example

```yaml
build:
    after-steps:
        - tarwich/slack-post:
              url:                $SLACK_URL
              # The rest are optional. If you don't need them,
              # just leave them out so that if we push changes,
              # you'll get the new stuff.
              channel:            general
              build-username:     buildbot
              deploy-username:    deploybot
              # You get the point. Add any other settings
              # you wish to override.
```
