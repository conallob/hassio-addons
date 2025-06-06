# Home Assistant Add-on: Omnivore

![Omnivore Logo](https://raw.githubusercontent.com/omnivore-app/omnivore/main/packages/web/public/icons/icon-512x512.png)

## About

[Omnivore](https://omnivore.app) is a complete, open source read-it-later
solution for people who like reading.

This add-on provides a self-hosted version of Omnivore that you can run directly
on your Home Assistant instance.

### Features

- Highlighting, notes, search, and sharing
- Full keyboard navigation
- Automatically saves your place in long articles
- Add newsletter articles via email (with substack support)
- PDF support
- Labels (aka tagging)

## Installation

Follow these steps to get the add-on installed on your system:

1. Navigate in your Home Assistant frontend to **Settings** -> **Add-ons** -> *
   *Add-on Store**.
2. Find the "Omnivore" add-on and click it.
3. Click on the "INSTALL" button.

## How to use

1. Start the add-on.
2. Check the logs to ensure it's running properly.
3. Click "OPEN WEB UI" to open the Omnivore interface.
4. On first run, a demo account will be created with:
    - Email: demo@omnivore.app
    - Password: demo_password

## Configuration

### Option: `log_level`

The `log_level` option controls the level of log output by the add-on and can be
changed to be more or less verbose, which might be useful when you are dealing
with an unknown issue. Possible values are:

- `trace`: Show every detail, like all called internal functions.
- `debug`: Shows detailed debug information.
- `info`: Normal (usually) interesting events.
- `warning`: Exceptional occurrences that are not errors.
- `error`: Runtime errors that do not require immediate action.
- `fatal`: Something went terribly wrong. Add-on becomes unusable.

Please note that each level automatically includes log messages from a more
severe level, e.g., `debug` also shows `info` messages. By default, the
`log_level` is set to `info`, which is the recommended setting unless you are
troubleshooting.

## Database

This add-on uses the Home Assistant PostgreSQL database if available. If not, it
will use an internal database configuration.

## Support

Got questions?

- Join the [Omnivore Discord server](https://discord.gg/h2z5rppzz9)
- The [Home Assistant Discord chat server](https://discord.gg/c5DvZ4e) for
  general Home Assistant discussions and questions.

## Authors & contributors

The original Omnivore application is developed by
the [Omnivore team](https://github.com/omnivore-app).

This Home Assistant add-on is created and maintained
by [Conall O'Brien](https://github.com/conallob).

## License

MIT License

Copyright (c) 2025 Conall O'Brien

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
