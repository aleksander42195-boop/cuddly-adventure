#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'LifehackApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'LifehackApp' }

# Remove files with incorrect paths first
project.files.each do |file|
  if file.path && (file.path.include?('LifehackApp/LifehackApp/') || file.path.include?('WatchApp/WatchApp/'))
    puts "Removing incorrect file reference: #{file.path}"
    file.remove_from_project
  end
end

# Files to add with correct paths
files_to_add = [
  ['LifehackApp/Services/TrainingModeManager.swift', 'LifehackApp/Services'],
  ['LifehackApp/Features/Today/TrainingModeView.swift', 'LifehackApp/Features/Today'],
  ['WatchApp/Views/WatchTrainingView.swift', 'WatchApp/Views'],
  ['WatchApp/Views/WatchMainView.swift', 'WatchApp/Views']
]

files_to_add.each do |file_path, group_path|
  next unless File.exist?(file_path)
  
  # Check if file already exists in project
  existing_file = project.files.find { |f| f.path == file_path }
  if existing_file
    puts "File #{file_path} already exists in project, skipping"
    next
  end
  
  # Find or create the appropriate group
  group = project.main_group.find_subpath(group_path, true)
  
  # Add file to group
  file_ref = group.new_reference(file_path)
  
  # Add to target if it's not a WatchApp file
  if file_path.include?('LifehackApp/')
    target.add_file_references([file_ref])
    puts "Added #{file_path} to LifehackApp target"
  end
end

# Find WatchApp target and add WatchApp files to it
watch_target = project.targets.find { |t| t.name == 'WatchApp' }
if watch_target
  files_to_add.each do |file_path, group_path|
    next unless file_path.include?('WatchApp/')
    next unless File.exist?(file_path)
    
    # Find the file reference
    file_ref = project.files.find { |f| f.path == file_path }
    if file_ref && !watch_target.source_build_phase.files_references.include?(file_ref)
      watch_target.add_file_references([file_ref])
      puts "Added #{file_path} to WatchApp target"
    end
  end
end

# Save the project
project.save

puts "Project updated successfully!"