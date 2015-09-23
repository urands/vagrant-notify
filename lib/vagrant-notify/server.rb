require 'socket'               # Get sockets from stdlib

module Vagrant
  module Notify
    class Server
      HTTP_RESPONSE = "Hi! You just reached the vagrant notification server"

      def self.run(env, port)
        id           = env[:machine].id
        machine_name = env[:machine].name
        provider     = env[:machine].provider_name

        $stdout.puts "notify-send: self.run( port: #{port} id:#{id} name: #{machine_name} prov: #{provider}"

        Thread.start do
          $0 = "vagrant-notify-server (#{port})"
          tcp_server = TCPServer.new('localhost',port)
          server = self.new(id, machine_name, provider)

          system("notify-send test test")

         # system("cmd &")

          $stdout.puts "notify-send: server: #{tcp_server} port: #{port} id:#{id} name: #{machine_name} prov: #{provider} ver: #{RUBY_VERSION}"
          Process.daemon
          
          loop {
            Thread.start(tcp_server.accept) { |client|

              
              $stdout.puts "notify-send: server start"
              server.receive_data(client)
            }
          }
        end
      end

      def initialize(id, machine_name = :default, provider = :virtualbox)
        @id           = id
        @machine_name = machine_name
        @provider     = provider
      end

      def receive_data(client)
        args = read_args(client)
        if http_request?(args)
          client.puts HTTP_RESPONSE
        else
          fix_icon_path!(args)
          system("notify-send #{args}")
        end
        client.close
      rescue => ex
        log ex.message
      end

      private

      def log(message)
        File.open("/tmp/vagrant-notify-error-#{@id}.log", 'a+') do |log|
          log.puts "#{message}"
          puts "#{message}"
        end
      end

      def read_args(client)
        ''.tap do |args|
          while tmp = client.gets and tmp !~ /^\s*$/
            args << tmp
          end
        end
      end

      def http_request?(args)
        args =~ /^GET/
      end

      def fix_icon_path!(args)
        return unless args =~ /-i '([^']+)'/
        icon = $1
        # TODO: Handle system icons
        host_file = "/tmp/vagrant-notify/#{@id}/#{icon.gsub('/', '-')}"
        args.gsub!(icon, host_file)
      end
    end
  end
end
