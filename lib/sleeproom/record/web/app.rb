# frozen_string_literal: true

require "roda"
module SleepRoom
  module Web
    class App < Roda
      plugin :default_headers,
             "Content-Type" => "application/json",
             "X-Frame-Options" => "deny",
             "X-Content-Type-Options" => "nosniff",
             "X-XSS-Protection" => "1; mode=block"
      plugin :content_security_policy do |csp|
        csp.default_src :none
        csp.style_src :self
        csp.form_action :self
        csp.script_src :self
        csp.connect_src :self
        csp.base_uri :none
        csp.frame_ancestors :none
      end
      plugin :public
      plugin :multi_route
      plugin :not_found do
      end
      plugin :error_handler do |e|
        $stderr.print "#{e.class}: #{e.message}\n"
        warn e.backtrace
        next exception_page(e, assets: true) if ENV["RACK_ENV"] == "development"
      end

      route "status" do |r|
        SleepRoom.load_status.sort_by { |hash| hash[:group] }.to_json
      end

      route "lists" do |r|
        r.get do
          SleepRoom.load_config(:record).to_json
        end

        r.post do
        end
      end
      route do |r|
        r.public
        r.multi_route

        r.root do
          "SleepRoom Web API"
        end
      end
    end
  end
end
