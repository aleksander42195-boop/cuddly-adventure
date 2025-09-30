#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'LifehackApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'LifehackApp' }

puts "Cleaning up project file references..."

# Remove ALL references to the files we're trying to add (in case they have wrong paths)
files_to_clean = [
  'TrainingModeManager.swift',
  'TrainingModeView.swift',
  'WatchTrainingView.swift',  
  'WatchMainView.swift'
]

project.files.each do |file|
  if file.path && files_to_clean.any? { |f| file.path.include?(f) }
    puts "Removing file reference: #{file.path}"
    file.remove_from_project
  end
end

# Now add the files with correct paths
files_to_add = [
  'LifehackApp/Services/TrainingModeManager.swift',
  'LifehackApp/Features/Today/TrainingModeView.swift'
]

files_to_add.each do |file_path|
  next unless File.exist?(file_path)
  
  puts "Adding file: #{file_path}"
  
  # Get the parent directory for the group
  parent_dir = File.dirname(file_path)
  
  # Find or create the appropriate group
  group = project.main_group.find_subpath(parent_dir, true)
  
  # Add file to group
  file_ref = group.new_reference(file_path)
  
  # Add to target
  target.add_file_references([file_ref])
  
  puts "Successfully added #{file_path} to LifehackApp target"
end

# Handle WatchApp files separately
watch_files = [
  'WatchApp/Views/WatchTrainingView.swift',
  'WatchApp/Views/WatchMainView.swift'
]

watch_target = project.targets.find { |t| t.name == 'WatchApp' }

watch_files.each do |file_path|
  next unless File.exist?(file_path)
  
  puts "Adding watch file: #{file_path}"
  
  # Get the parent directory for the group
  parent_dir = File.dirname(file_path)
  
  # Find or create the appropriate group
  group = project.main_group.find_subpath(parent_dir, true)
  
  # Add file to group
  file_ref = group.new_reference(file_path)
  
  # Add to WatchApp target if it exists
  if watch_target
    watch_target.add_file_references([file_ref])
    puts "Successfully added #{file_path} to WatchApp target"
  end
end

# Save the project
project.save

puts "Project cleanup and file addition completed successfully!"