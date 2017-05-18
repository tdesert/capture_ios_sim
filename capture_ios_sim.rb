#!/usr/bin/ruby

require 'date'
require 'open3'
require 'optparse'

###
# OPTIONS
###

LOG_LEVEL = {
	verbose: 	0,
	default: 	1
}

OPTIONS = {
	frame_rate: 15,
	width: 300,
	log_level: LOG_LEVEL[:default],
	output_file: "#{Dir.pwd}/capture.gif"
}

OptionParser.new do |opts|
	opts.banner = "Usage: #{$0} [options]"

	opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
		OPTIONS[:log_level] = LOG_LEVEL[:verbose]
	end
	opts.on("-r", "--framerate N", Integer, "Frames per second of output gif (default: #{OPTIONS[:frame_rate]})") do |v|
		OPTIONS[:frame_rate] = v
	end
	opts.on("-w", "--width N", Integer, "Width of output gif (default: #{OPTIONS[:width]})") do |v|
		OPTIONS[:width] = v
	end
	opts.on("-o", "--output <file>", String, "Output gif path (default: #{OPTIONS[:output_file]})") do |v|
		OPTIONS[:output_file] = v
	end
end.parse!

###
# MACROS
###

def verbose(message)
	puts "🗣  #{message}" unless OPTIONS[:log_level] > LOG_LEVEL[:verbose]
end

def clean()
	verbose("Clean #{MOV_FILE}")
	`rm -rf #{MOV_FILE}`

	verbose("Clean #{GIF_FILE}")
	`rm -rf #{GIF_FILE}`
end

def fail(message)
	puts "☠  #{message}"
	exit(1)
end

def cmd(command)
	verbose("Run: #{command}...")
	stdin, stdout, stderr, wait_thr = Open3.popen3(command)
	pid = wait_thr[:pid]
	verbose("PID: #{wait_thr.pid}")

	code = wait_thr.value
	fail("Your computer does not support Metal") if code.termsig == SIGIOT
	fail("#{command} failed (#{code}): #{stderr.read}") if code != 0
	yield(pid) if block_given?

	stdout.read
end

###
# CONSTANTS
###

SIGIOT = 6

timestamp = DateTime.now.to_time.to_i.to_s
MOV_FILE = "/tmp/capture-#{timestamp}.mov"
GIF_FILE = "/tmp/capture-#{timestamp}.gif"
verbose("Output files: #{MOV_FILE}, #{GIF_FILE}")

###
# Script
###

begin

	# Check dependencies
	commands = [:ffmpeg, :xcrun].map do |cmd|
		path = `which #{cmd}`
		fail("Command [#{cmd}] is missing. Please install it.") if path.length == 0
		{cmd => path[0...path.length - 1]}
	end.reduce({}, :merge)

	verbose("Options: #{OPTIONS.to_s}")

	print "📱  Launch your simulator, then hit return key to start recording..."
	readline

	# xcrun: start capture on booted ios sim
	cmd("#{commands[:xcrun]} simctl io booted recordVideo #{MOV_FILE}") do |pid|
		print "🔴  Recording simulator... Type return key to end capture..."
		readline
		Process.kill("INT", pid)
	end

	# ffmpeg: convert .mov to .gif
	cmd("#{commands[:ffmpeg]} -i #{MOV_FILE} -vf scale=#{OPTIONS[:width]}:-1 -r #{OPTIONS[:frame_rate]} -pix_fmt rgb24 #{GIF_FILE}") do |pid|
		puts "🎬  Processing ffmpeg..."
	end

	# final output
	cmd("cp #{GIF_FILE} #{OPTIONS[:output_file]}")

	puts "✅  Done! Your gif: #{OPTIONS[:output_file]}"
	cmd("open #{OPTIONS[:output_file]}")

rescue Interrupt # Intercept Ctrl-C

	puts ""
	puts "🚪  Exit"
	exit 0

ensure

	clean()

end
