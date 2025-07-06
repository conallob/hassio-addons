# Home Assistant Add-on: Vector

## Overview

Vector is a high-performance observability data pipeline that puts you in
control of your data.

## Installation

Follow these steps to get the add-on installed on your system:

1. Navigate in your Home Assistant frontend to **Supervisor** -> **Add-on Store
   **.
2. Click the 3-dots menu at upper right -> **Repositories** and add this
   repository URL: `https://github.com/conallob/hassio-addons`
3. Find the "Vector" add-on and click it.
4. Click on the "INSTALL" button.

## Configuration

**Note**: _Remember to restart the add-on when the configuration is changed._

Example add-on configuration:

```yaml
log_level: info
```

### Option: `log_level`

The `log_level` option controls the level of log output by the addon and can
be changed to be more or less verbose, which might be useful when you are
dealing with an unknown issue. Possible values are:

- `trace`: Show every detail, like all called internal functions.
- `debug`: Shows detailed debug information.
- `info`: Normal (usually) interesting events.
- `warning`: Exceptional occurrences that are not errors.
- `error`: Runtime errors that do not require immediate action.
- `fatal`: Something went terribly wrong. Add-on becomes unusable.

Please note that each level automatically includes log messages from a
more severe level, e.g., `debug` also shows `info` messages. By default,
the `log_level` is set to `info`, which is the recommended setting unless
you are troubleshooting.

## Vector Configuration

The Vector configuration file is located at `/config/vector/vector.yaml`. You
can edit this file to customize Vector according to your needs.

By default, the add-on is configured to:

1. Collect host metrics from the system
2. Collect Home Assistant logs
3. Output these to the console in JSON format

For more information on how to configure Vector, please refer to
the [Vector documentation](https://vector.dev/docs/).

## Support

Got questions?

You can open an issue on
GitHub: [https://github.com/conallob/hassio-addons/issues](https://github.com/conallob/hassio-addons/issues)
