# envmail

#### Table of Contents

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
3. [Installation and Usage](#installation-and-usage)
4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)

## Overview

This is a plug-in puppet report processor to send report mail based on environment.

## Module Description

This module is a [report processor](https://docs.puppetlabs.com/guides/reporting.html) plugin to generate a report similar to the built-in tagmail. The envmail report sends all log messages for a particular environment via email.
The recipient email address is defined in a configuration file called `envmail.conf`.  To use the plugin, add `envmail` to the reports configuration in the [master] section of puppet.conf.

```
[master]
reports = puppetdb,console,tagmail,envmail
```

On the agent ensure pluginsync is enabled. It is enabled by default.

```
[agent]
report = true
pluginsync = true
```

## Installation and Usage

To use this report, you must create a `envmail.conf` file on the puppet master in the $confdir. The `envmail.conf` is a simple file that maps environments to email addresses:  Any log messages in the report that originate from the specified environment will be sent to the specified email addresses. 

An example `envmail.conf`:
```
production: admins@domain.com
development: devs@domain.com
```
If you are using anti-spam controls such as grey-listing on your mail server, you should whitelist the sending email address (controlled by `reportfrom` configuration option) to ensure your email is not discarded as spam.
The tagmail.conf file contains a list of tags and email addresses separated by colons. Multiple tags and email addresses can be specified by separating them with commas.

Other settings can also be optionally in puppet.conf to control the email notification settings: `smtpserver`, `smtpport`, `smtphelo`, `sendmail`.

## Reference

It is based on the original [tagmail report processor](https://github.com/puppetlabs/puppet/blob/3.7.3/lib/puppet/reports/tagmail.rb) which is a part of core puppet.
