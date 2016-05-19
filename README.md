# slack-post

Posts wercker build/deploy status to a [Slack] channel.

This project is forked from the awesome work of [kobim]

[Slack]: https://slack.com/
[kobim]: https://github.com/kobim/wercker-step-slack-post

<!-- [![wercker status](https://app.wercker.com/status/49d7c3919df2d65ed4679bcc86eb3477/m "wercker status")](https://app.wercker.com/project/bykey/49d7c3919df2d65ed4679bcc86eb3477) -->

### Required fields

* `url` - Your incoming webhook url (get it at https://slack.com/services/new/incoming-webhook).

### Optional fields

* `channel` - The Slack Channel you wish to post to (default - `#general`).
* `username` - The robot's username (default - `werckerbot`).

### How to configure?

Under your project settings, add new Pipeline variable named `SLACK_URL` with your WebHook url. You then reference this variable in your [wercker.yml](http://devcenter.wercker.com/articles/werckeryml/).


# Example

Add `SLACK_URL` as deploy target or application environment variable.

  build:
    after-steps:
      - tarwich/slack-post:
        url:      $SLACK_URL
        channel:  dev        # OPTIONAL
        username: builder    # OPTIONAL

# License

The MIT License (MIT)

Copyright (c) 2013 wercker

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
