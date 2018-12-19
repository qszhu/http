require "logger"
require "colorize"
require "time_format"
require "http/server/handler"

class Onyx::REST
  # HTTP handlers which log requests.
  module Loggers
    # Logs requests colorfully into specified standard *logger*.
    # It also logs the `HTTP::Request#id` if it's present.
    #
    # ```
    # logger = Onyx::REST::Loggers::Standard.new
    #
    # #   INFO -- :     GET /users 200 102μs
    # #   INFO -- :     GET /favicon.ico 404 52μs
    # #   INFO -- :    POST /users 201 3.74ms
    # ```
    class Standard
      include HTTP::Handler

      protected def color(status_code)
        case status_code
        when 100..199 then :cyan
        when 200..299 then :green
        when 300..399 then :yellow
        else               :red
        end
      end

      # Set *query* to `false` to turn off logging requests' queries.
      def initialize(
        @logger : Logger = Logger.new(STDOUT),
        *,
        @severity : Logger::Severity = Logger::INFO,
        @query : Bool = true
      )
      end

      def call(context)
        started_at = Time.monotonic
        id = context.request.id.not_nil![0...8] if context.request.id

        websocket = context.request.headers.includes_word?("Upgrade", "Websocket")
        if websocket
          id = "[#{id}] ".colorize(:dark_gray) if context.request.id
          method = "WS".rjust(7).colorize(color(100)).mode(:bold)
          progess = "pending".colorize(:dark_gray)

          resource = context.request.path

          unless resource.size < 2
            resource = resource.rstrip('/')
          end

          if @query && (query = context.request.query)
            resource += "?#{query}"
          end

          resource = resource.colorize(color(100))

          @logger.log(@severity, "#{id}#{method} #{resource} #{progess}")
        end

        begin
          call_next(context)
        ensure
          id = "[#{id}] ".colorize(:dark_gray) if context.request.id
          color = color(context.response.status_code)
          method = (websocket ? "WS" : context.request.method).rjust(7).colorize(color).mode(:bold)
          status_code = context.response.status_code.colorize(color).mode(:bold)

          resource = context.request.path

          unless resource.size < 2
            resource = resource.rstrip('/')
          end

          if @query && (query = context.request.query)
            resource += "?#{query}"
          end

          resource = resource.colorize(color)

          @logger.log(@severity, "#{id}#{method} #{resource} #{status_code} #{TimeFormat.auto(Time.monotonic - started_at).colorize(:dark_gray)}")
        end
      end
    end
  end
end
