#!/usr/bin/ruby
# Use system ruby. This needs to work no matter what env Xcode has or what rvm ruby has been selected.

# ibtool has a bug where multiple instances of it race to create the localized strings dirs in the built product directory
# Two instances of ibtoold (a launchd daemon started by ibtool) both see that the directory doesn't exist. Both call mkdir
# mkdir fails for one and fails the build.
#
# Its actually ibtoold that races to create the dir, and there are more details here:
#
# On clean builds this race fails the build ~2% of the time.
#
# This wrapper (combined with a patch of /Applications/Xcode.app/Contents/PlugIns/Xcode3Core.ideplugin/Contents/SharedSupport/Developer/Library/Xcode/Plug-ins/IBCompilerPlugin.xcplugin/Contents/Resources/IBCompiler.xcspec)
# serves to pre-create these directories so that they are always available to any ibtool/ibtoold that runs.


# We do this by parsing the command line to ibtool. Two args are of particular importance
#
# There are several lines defining the strings files (in the source dir)
# --companion-strings-file ja:/Users/mtauraso/Development/register/iPhone/Resources/ja.lproj/CQOrderEntryViewController.strings
#
# And one defining the built nib (in the built products dir)
# --compile /Users/mtauraso/Library/Developer/Xcode/DerivedData/Register-fcqxjfycywbjpvckvchhzytqfelq/Build/Products/Debug-iphonesimulator/Square.app/Base.lproj/CQOrderEntryViewController.nib
#
# In this example we would want to create the following dir (in the built products dir)
# /Users/mtauraso/Library/Developer/Xcode/DerivedData/Register-fcqxjfycywbjpvckvchhzytqfelq/Build/Products/Debug-iphonesimulator/Square.app/ja.lproj
#
# We want to create likewise for any other --companion-strings-file given on the command line.

locale_dirs = []
bundle_dir = ""

ARGV.each_with_index do |arg, index|
  if arg == "--companion-strings-file"
    locale_dir = nil
    begin
      strings_file = ARGV[ index + 1 ].split(":")[1]
      # This will get us just the localization code + lproj, eg:"ja.lproj"
      locale_dir = File.basename(File.dirname(strings_file))
    rescue StandardError => e
      # just move on silently if our parsing doesn't work for some reason
      locale_dir = nil
    end
    locale_dirs << locale_dir unless locale_dir.nil?
  end
  if arg == "--compile"
    begin
      base_lproj_dir = File.dirname(ARGV[ index + 1 ])
      bundle_dir = File.dirname(base_lproj_dir)
    rescue StandardError => e
      # If our parsing didn't work, just carry on.
      bundle_dir = ""
    end
  end
end

# Even if we don't get the information we want from ARGV
# We ought still function as a transparent wrapper.
#
# Its better that we go back to having a rare race condtion
# than that every build fail in the middle of this hack
unless bundle_dir.empty?
  locale_dirs.each do |locale_dir|
    # Attempt creation. Eat EEXIST errors.
    # allow others to bubble up.
    begin
      Dir.mkdir(File.join(bundle_dir, locale_dir))
    rescue SystemCallError => e
      raise e unless e.errno == Errno::EEXIST::Errno
    end
  end
end

# Run ibtool normally
# Also run ibtool if the wrapper is called without mentioning ibtool.

# copy of argv we can alter.
argv = ARGV
if File.basename(ARGV[0]) == "ibtool"
  if File.executable?(ARGV[0]) && !File.directory?(ARGV[0])
    exec(*ARGV)
  end

  # If whatever's at the front looks like ibtool, but we can't find it directly,
  # lop it off and we'll look in ENV['PATH'] below.
  argv = ARGV[1..-1]
end

# We hope PATH is set to find the right ibtool when xcode calls us.
ibtool_binary = ""
unless ENV['PATH'].nil?
  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
    ibtool_binary = File.join(path, "ibtool")
    if File.executable?(ibtool_binary) && !File.directory?(ibtool_binary)
      break
    end
  end
else
  #Try where we think ibtool is in the currently selected xcode.
  ibtool_binary = File.join(`/usr/bin/xcode-select -p`.strip(), "usr", "bin","ibtool")
end

if !ibtool_binary.empty? &&
    File.executable?(ibtool_binary) &&
    !File.directory?(ibtool_binary)

  command_list = [ibtool_binary].concat(argv)
  exec(*command_list)
end

# We should have run exec by now. If this code is reached, something is terribly wrong.
puts "ERROR: Launched ibtool_wrapper.rb with ARGV of:"
puts ARGV.inspect
puts "Environment of:"
puts ENV.inspect
puts "ERROR: Could not find ibtool to run under these circumstances."
exit 1
