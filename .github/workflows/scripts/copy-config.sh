#!/bin/bash
root_path=$(pwd)

TEMPLATE_CONFIG_FILE="app_config_template.dart"
TARGET_CONFIG_FILE="app_config.dart"
DEMOS_FOLDER="$root_path/demos"  # Update the path to your demo folder

# Function to find and copy config files
copy_config_files() {
  local demos_folder=$1

  # Iterate over the files found by find
  find "$demos_folder" -type f -name "$TEMPLATE_CONFIG_FILE" | while read -r template_config; do
    # Ensure it's a regular file before attempting to copy
    if [ -f "$template_config" ]; then
      # Create a new file app_config.dart with the contents of app_config_template.dart
      echo -n > "${template_config%/*}/$TARGET_CONFIG_FILE"
      cat "$template_config" >> "${template_config%/*}/$TARGET_CONFIG_FILE"
      echo "Copied contents of $template_config to ${template_config%/*}/$TARGET_CONFIG_FILE"
    fi
  done

  # Create a new file .env for supabase-trello demo
  echo -n > demos/supabase-trello/.env
}

# Call the function for the single demos folder
copy_config_files "$DEMOS_FOLDER"
