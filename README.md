# Gitea Package Deletion Action

This action sets execute permissions on shell scripts and runs a Gitea package deletion script with proper Gitea token configuration.

## Usage

```yaml
- uses: kekxv/gitea-package-deletion-action@v1
  with:
    gitea_token: ${{ secrets.GITEA_TOKEN }}
    gitea_url: 'https://gitea.example.com'
    gitea_owner: 'your-username-or-org'
```

## Inputs

| Input | Description | Required | Default |
| ----- | ----------- | -------- | ------- |
| gitea_token | Gitea Personal Access Token | Yes | - |
| gitea_url | Gitea instance URL | Yes | - |
| gitea_owner | Package owner in Gitea | Yes | - |
| delete_script_path | Path to the delete script | No | `${{ github.action_path }}/delete_gitea_package.sh` |
| main_script | Main script to execute | No | `${{ github.action_path }}/auto_delete_multi_module.sh` |
| directory | Directory to run the script in | No | . |

## Setup

1. Create a Personal Access Token in your Gitea instance with package deletion permissions
2. Add it as a secret in your repository settings (Settings > Secrets > Actions)
3. Reference it in your workflow as shown in the usage example

## Features

- Automatically sets execute permissions on shell scripts
- Runs Gitea package deletion scripts with proper token configuration
- Uses absolute paths for reliable script execution
- Works with any shell scripts in your repository
- Securely handles Gitea Personal Access Token