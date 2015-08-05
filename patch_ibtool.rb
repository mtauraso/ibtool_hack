#!/usr/bin/ruby
# Use system ruby
#
# This is a very paranoid patcher for the IBCompiler.xcspec file. We use a regex to rewrite the ibtool CommandLine declaration at the beginning of the file to use ibtool_wrapper.rb.
# The bug in ibtool that this works around is explained more in ibtool_wrapper.rb.
#
# This script supports two operations, and expects to be run as root.
#
# Patch:
#   sudo ./patch_ibtool.rb
#
#   Result:
#     Does sanity checking
#     Creates a backup in `pwd`/backup/IBCompiler.xcspec.original
#     Rewrites IBCompiler.xcspec under /Applications/Xcode.app
#     Attempts to restore from backup if destructive operations fail
#
# Reverse Patch:
#   sudo ./patch_ibtool.rb -r
#   (also accepts --reverse and --restore)
#
#   Result:
#     Does sanity checking.
#     Copies backup from `pwd`/backup/IBCompiler.xcspec.original to its location under /Applications/Xcode.app
#
require 'fileutils'

IBTOOL_XCSPEC = "/Applications/Xcode.app/Contents/PlugIns/Xcode3Core.ideplugin/Contents/SharedSupport/Developer/Library/Xcode/Plug-ins/IBCompilerPlugin.xcplugin/Contents/Resources/IBCompiler.xcspec"
BACKUP_DIR = "#{Dir.pwd}/backup"
IBTOOL_WRAPPER = "#{Dir.pwd}/ibtool_wrapper.sh"

IBTOOL_COMMANDLINE_RE = /CommandLine = "(.*?ibtool_wrapper\.sh )?ibtool \[options\]/

ibtool_wrapper_replacement = "CommandLine = \"#{IBTOOL_WRAPPER} ibtool [options]"
ibtool_backup_location = "#{File.join(BACKUP_DIR, File.basename(IBTOOL_XCSPEC))}.original"

if Process.euid != 0
  puts "This script must be run as root"
  exit 1
end

if ARGV.length > 0 && (ARGV[0] == "--reverse" || ARGV[0] == "-r" || ARGV[0] == "--restore")
  if File.exists?(ibtool_backup_location)
    puts "Restoring from backup"
    FileUtils.cp(ibtool_backup_location, IBTOOL_XCSPEC)
    exit 0
  end
  puts "No backup found at #{ibtool_backup_location} Cannot restore."
  puts "Did you mean to patch by running with no args?"
  exit 1
end

if File.exists?(ibtool_backup_location)
  puts "Backup already exists. This may indicate a failed patch."
  puts "Please delete the backup manually if you know this is not true."
  puts "Did you mean to restore? Pass --restore, -r, or --reverse to do so."
  exit 1
end

begin
  FileUtils.mkdir_p(BACKUP_DIR)
  FileUtils.cp(IBTOOL_XCSPEC, ibtool_backup_location)
rescue Exception => e
  puts "Could not make backup copy of IBCompiler xcspec"
  puts e.inspect
  puts e.backtrace.join("\n")
  raise e
end

begin
  data = nil
  File.open(IBTOOL_XCSPEC, "rb") do |file_ro|
    data = file_ro.read()
  end

  if IBTOOL_COMMANDLINE_RE.match(data).nil?
    puts "Could not match regex. The format of the file we're patching may have changed."
    puts "Please update this script."
    exit 1
  end

  # Do our destructive operations. Truncate the file to zero before writing.
  File.open(IBTOOL_XCSPEC, "wb") do |file_w|
    file_w.write(data.gsub(IBTOOL_COMMANDLINE_RE, ibtool_wrapper_replacement))
  end
  puts "Successfully patched #{IBTOOL_XCSPEC} to add #{IBTOOL_WRAPPER} to all CompileXIB commands."

rescue Exception => e
  puts "Caught error while replacing IBCompiler xcspec"
  puts e.inspect
  puts e.backtrace.join("\n")
  puts "Attempting to return backup copy to original location"
  begin
    FileUtils.cp(ibtool_backup_location, IBTOOL_XCSPEC)
  rescue Exception => f
    puts "Failed to Restore IBCompiler xcspec. This build slave is probably broken and will require manual matinence."
    puts "Backup file is at #{ibtool_backup_location}"
    raise f
  end
end

