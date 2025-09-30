#!/usr/bin/env ruby

require 'xcodeproj'

PROJECT_PATH = 'LifehackApp.xcodeproj'
WATCH_TARGET_NAME = 'LifehackWatchApp Watch App'
IOS_TARGET_NAME = 'LifehackApp'
WATCH_GROUP_PATH = 'LifehackWatchApp Watch App'

# Specific files we want in the Watch target
WATCH_SOURCE_FILES = [
  'LifehackWatchApp Watch App/LifehackWatchAppApp.swift',
  'LifehackWatchApp Watch App/ContentView.swift',
  'LifehackWatchApp Watch App/WatchMainView.swift',
  'LifehackWatchApp Watch App/WatchTrainingView.swift',
  'LifehackWatchApp Watch App/WatchTrainingManager.swift',
  'LifehackWatchApp Watch App/WatchTrainingSettingsView.swift',
  'LifehackWatchApp Watch App/Secrets.swift'
]
WATCH_RESOURCE_FILES = [
  'LifehackWatchApp Watch App/Assets.xcassets',
  'LifehackWatchApp Watch App/Secrets.plist'
]

# iOS resources
IOS_RESOURCE_FILES = [
  'Config/Secrets.plist'
]

project = Xcodeproj::Project.open(PROJECT_PATH)

watch_target = project.targets.find { |t| t.name == WATCH_TARGET_NAME }
ios_target   = project.targets.find { |t| t.name == IOS_TARGET_NAME }

unless watch_target
  abort "Watch target '#{WATCH_TARGET_NAME}' not found"
end
unless ios_target
  abort "iOS target '#{IOS_TARGET_NAME}' not found"
end

# Ensure watch files are referenced and added to build phases
main_group = project.main_group

added_sources = []
WATCH_SOURCE_FILES.each do |path|
  next unless File.exist?(path)
  file_ref = project.files.find { |f| f.path == path } || main_group.new_reference(path)
  unless watch_target.source_build_phase.files_references.include?(file_ref)
    watch_target.add_file_references([file_ref])
    added_sources << path
  end
end

added_resources_watch = []
WATCH_RESOURCE_FILES.each do |path|
  next unless File.exist?(path)
  file_ref = project.files.find { |f| f.path == path } || main_group.new_reference(path)
  unless watch_target.resources_build_phase.files_references.include?(file_ref)
    watch_target.resources_build_phase.add_file_reference(file_ref)
    added_resources_watch << path
  end
end

# Add iOS Secrets.plist to iOS target resources
added_resources_ios = []
IOS_RESOURCE_FILES.each do |path|
  next unless File.exist?(path)
  config_group = project.main_group.find_subpath('Config', true)
  file_ref = project.files.find { |f| f.path == path } || config_group.new_reference(path)
  unless ios_target.resources_build_phase.files_references.include?(file_ref)
    ios_target.resources_build_phase.add_file_reference(file_ref)
    added_resources_ios << path
  end
end

project.save

puts "Added to Watch Sources: #{added_sources}" unless added_sources.empty?
puts "Added to Watch Resources: #{added_resources_watch}" unless added_resources_watch.empty?
puts "Added to iOS Resources: #{added_resources_ios}" unless added_resources_ios.empty?
puts 'Sync complete.'
