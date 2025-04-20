#!/bin/bash

# Check if the templates directory was provided as an argument
if [ -z "$1" ]; then
  echo "Error: You need to provide the templates directory as an argument."
  exit 1
fi

# Directory containing the templates
TEMPLATES_DIR="$1"

# Check if the directory exists
if [ ! -d "$TEMPLATES_DIR" ]; then
  echo "Error: The directory '$TEMPLATES_DIR' does not exist."
  exit 1
fi

# Enable recursive globbing
shopt -s globstar

# Output kustomization file path
KUSTOMIZATION_FILE="$TEMPLATES_DIR/kustomization.yaml"

# Write kustomization header
cat <<EOF > "$KUSTOMIZATION_FILE"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
EOF

# Find all .yaml files recursively and add them (except values.yaml)
for file in "$TEMPLATES_DIR"/**/*.yaml; do
  filename=$(basename "$file")

  # Skip the kustomization.yaml and values.yaml files
  if [[ "$file" == "$KUSTOMIZATION_FILE" || "$filename" == "values.yaml" ]]; then
    continue
  fi

  # Use relative path
  rel_path=$(realpath --relative-to="$TEMPLATES_DIR" "$file")
  echo "  - $rel_path" >> "$KUSTOMIZATION_FILE"
done

echo "kustomization.yaml generated successfully at $KUSTOMIZATION_FILE"
