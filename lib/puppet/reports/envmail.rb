require 'puppet'
require 'pp'

require 'net/smtp'
require 'time'

Puppet::Reports.register_report(:envmail) do
  desc "This report sends puppet log messages to specific email addresses
    based on the environment.

    To use this report, you must create a `envmail.conf` file in the puppet
    $confdir.  This is a simple file that maps enviroments to email addresses.

    Lines in the `envmail.conf` file consist of an environment, a colon
    and a comma-separated list of email addresses.
    
    An example `envmail.conf`:

        development: devs@domain.com
        uat: uat@domain.com

    This will send all messages from the development environment to `devs@domain.com` etc.

    If you are using anti-spam controls such as grey-listing on your mail
    server, you should whitelist the sending email address (controlled by
    `reportfrom` configuration option) to ensure your email is not discarded as spam.
    "

  # Find all matching messages.
  def match(envlists)
    matching_logs = []
    envlists.each do |emails, environment|
      messages = nil
      if self.environment == environment
        messages = self.logs

        if messages.empty?
          Puppet.info "No messages to report to #{emails.join(",")}"
          next
        else
          matching_logs << [emails, messages.collect { |m| m.to_report }.join("\n")]
        end
      end
    end

    matching_logs
  end

  # Load the config file
  def parse(text)
    envlists = []
    text.split("\n").each do |line|
      envlist = emails = nil
      case line.chomp
      when /^\s*#/; next
      when /^\s*$/; next
      when /^\s*(.+)\s*:s*(.+)\s*$/
        environment = $1
        emails = $2.sub(/#.*$/,'')
      else
        raise ArgumentError, "Invalid envmail config file"
      end

      # Now split the emails
      emails = emails.sub(/\s+$/,'').split(/\s*,\s*/)
      envlists << [emails, environment]
    end
    envlists
  end

  # Process the report.  This just calls the other associated messages.
  def process
    configfile = File.join([File.dirname(Puppet.settings[:config]), "envmail.conf"])
    unless File.exist?(configfile)
      Puppet.notice "Cannot send envmail report; no envmail.conf file #{configfile}"
      return
    end

   metrics = raw_summary['resources'] || {} rescue {}

    if metrics['out_of_sync'] == 0 && metrics['changed'] == 0
      Puppet.notice "Not sending envmail report; no changes"
      return
    end

    envlists = parse(File.read(configfile))

    # Now find any appropriately tagged messages.
    reports = match(envlists)

    send(reports) unless reports.empty?
  end

  # Send the email reports.
  def send(reports)
    pid = Puppet::Util.safe_posix_fork do
      if Puppet[:smtpserver] != "none"
        begin
          Net::SMTP.start(Puppet[:smtpserver], Puppet[:smtpport], Puppet[:smtphelo]) do |smtp|
            reports.each do |emails, messages|
              smtp.open_message_stream(Puppet[:reportfrom], *emails) do |p|
                p.puts "From: #{Puppet[:reportfrom]}"
                p.puts "Subject: Puppet Report for #{self.host}"
                p.puts "To: " + emails.join(", ")
                p.puts "Date: #{Time.now.rfc2822}"
                p.puts
                p.puts messages
              end
            end
          end
        rescue => detail
          message = "Could not send report emails through smtp: #{detail}"
          Puppet.log_exception(detail, message)
          raise Puppet::Error, message, detail.backtrace
        end
      elsif Puppet[:sendmail] != ""
        begin
          reports.each do |emails, messages|
            # We need to open a separate process for every set of email addresses
            IO.popen(Puppet[:sendmail] + " " + emails.join(" "), "w") do |p|
              p.puts "From: #{Puppet[:reportfrom]}"
              p.puts "Subject: Puppet Report for #{self.host}"
              p.puts "To: " + emails.join(", ")
              p.puts
              p.puts messages
            end
          end
        rescue => detail
          message = "Could not send report emails via sendmail: #{detail}"
          Puppet.log_exception(detail, message)
          raise Puppet::Error, message, detail.backtrace
        end
      else
        raise Puppet::Error, "SMTP server is unset and could not find sendmail"
      end
    end

    # Don't bother waiting for the pid to return.
    Process.detach(pid)
  end
end

