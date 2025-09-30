#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'LifehackApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'LifehackApp' }

# Files to add
files_to_add = [
  'LifehackApp/Services/TrainingModeManager.swift',
  'LifehackApp/Features/Today/TrainingModeView.swift',
  'WatchApp/Views/WatchTrainingView.swift',
  'WatchApp/Views/WatchMainView.swift'
]

files_to_add.each do |file_path|
  next unless File.exist?(file_path)
  
  # Determine the appropriate group based on file path
  if file_path.include?('WatchApp/Views')
    group = project.main_group.find_subpath('WatchApp/Views', true)
  elsif file_path.include?('Services')
    group = project.main_group.find_subpath('LifehackApp/Services', true)
  elsif file_path.include?('Features/Today')
    group = project.main_group.find_subpath('LifehackApp/Features/Today', true)
  else
    group = project.main_group
  end
  
  # Add file to group
  file_ref = group.new_reference(file_path)
  
  # Add to target if it's not a WatchApp file (WatchApp files go to WatchApp target)
  if file_path.include?('LifehackApp/')
    target.add_file_references([file_ref])
  end
  
  puts "Added #{file_path} to project"
end

# Find WatchApp target and add WatchApp files to it
watch_target = project.targets.find { |t| t.name == 'WatchApp' }
if watch_target
  files_to_add.each do |file_path|
    next unless file_path.include?('WatchApp/')
    next unless File.exist?(file_path)
    
    # Find the file reference we just added
    file_ref = project.reference_for_path(file_path)
    if file_ref
      watch_target.add_file_references([file_ref])
      puts "Added #{file_path} to WatchApp target"
    end
  end
end

# Save the project
project.save

puts "Project updated successfully!"