require "optparse"

module Racecar
  module Cli
    def self.main
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: racecar MyConsumer [options]"

        opts.on("-r", "--require LIBRARY", "Require the LIBRARY before starting the consumer") do |lib|
          require lib
        end

        opts.on_tail("--version", "Show Racecar version") do
          require "racecar/version"
          puts "Racecar #{Racecar::VERSION}"
          exit
        end
      end

      parser.parse!(ARGV)

      consumer_name = ARGV.first or raise "No consumer specified"
      config_file = "config/racecar.yml"

      puts "=> Starting Racecar consumer #{consumer_name}..."

      begin
        require "rails"

        puts "=> Detected Rails, booting application..."

        require "./config/environment"

        Racecar.config.load_file(config_file, Rails.env)

        if Racecar.config.log_to_stdout
          # Write to STDOUT as well as to the log file.
          console = ActiveSupport::Logger.new($stdout)
          console.formatter = Rails.logger.formatter
          console.level = Rails.logger.level
          Rails.logger.extend(ActiveSupport::Logger.broadcast(console))
        end

        Racecar.logger = Rails.logger
      rescue LoadError
        # Not a Rails application.
      end

      # Find the consumer class by name.
      consumer_class = Kernel.const_get(consumer_name)

      # Load config defined by the consumer class itself.
      Racecar.config.load_consumer_class(consumer_class)

      Racecar.config.validate!

      puts "=> Wrooooom!"
      puts "=> Ctrl-C to shutdown consumer"

      processor = consumer_class.new

      Racecar.run(processor)

      puts "=> Shut down"
    end
  end
end
