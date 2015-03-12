#!/usr/bin/env ruby
# Chef Exception and Reporting Handler for Sumo Logic
#
# Author:: Duc T. Ha<mailto:duc@sumologic.com>
# Copyright:: Copyright 2015, SumoLogic Inc.
# License:: Apache License 2.0
#
#
require 'rubygems'
require 'chef'
require 'chef/handler'
require 'rest-client'

class Chef
	class Handler
		class SumoLogic < Chef::Handler
			def initialize(args)
				@isLogLocally = "local"
				@collector_endpoint = args
			end

			def sendMsg(msg)
				if @collector_endpoint != @isLogLocally
					request = RestClient::Resource.new(@collector_endpoint)
					request.post(msg,:content_type => 'application/x-www-form-urlencoded')
				end
			end

			# Report Chef's run_status and metrics to SumoLogic HTTP source 
			def report_metrics(status)
				if @collector_endpoint!=@isLogLocally
					Chef::Log.info("SumoLogic Report will be sent to: "+@collector_endpoint)
				else	
					# write to the local Chef-Log channel
					Chef::Log.info("SumoLogic Report Handler Report: ")
				end
				run_data = { :host => node.fqdn, :ip_address => node.ipaddress, :start_time => run_status.start_time, :end_time => run_status.end_time, :elapsed_time => run_status.elapsed_time, :updated_resources => run_status.updated_resources.join("\t") }
				payload = run_data.collect{|k,v| [k,v].join('=')}.join('&')
				if status==true 
					prefix = "Chef-Client completed successfully : "
				else
					prefix = "Chef-Client did not complete: "
				end
				final_payload = prefix+payload

				if @collector_endpoint != @isLogLocally
					sendMsg(final_payload)
				else
					Chef::Log.info(final_payload)
				end
			end

			def report_exceptions
				Chef::Log.warn("SumoLogic Exception Handler: ")
				payload = Array(run_status.backtrace).join("%0D%0A")
				#final_payload = URI.escape("Exception: "+payload)
				run_data = { :host => node.fqdn,:ip_address => node.ipaddress, :start_time => run_status.start_time, :end_time => run_status.end_time, :elapsed_time => run_status.elapsed_time}.collect{|k,v| [k,v].join('=')}.join('&')
				final_payload = "Exception(s) on "+run_data+". Full list: "+payload
				if @collector_endpoint !=@isLogLocally
					sendMsg(final_payload)
				else
					Chef::Log.error(final_payload)
				end
			end

			def report
				report_metrics(run_status.success?)
				if run_status.failed?
					if @collector_endpoint !=@isLogLocally
						Chef::Log.warn("Sending exceptions to SumoLogic now")
					end
					report_exceptions
				end
			end
		end
	end
end
