# release-to-branch

This action has been created to automate the process of releasing (copying) selected files/directories to a specific branch. It was designed mainly for releasing custom GitHub Actions - especially those that must build/process some files before they can be used. Eg. TypeScript files that must be compiled to JavaScript.

## Usage

```yaml
- name: Release to major version branch
  uses: cdqag/release-to-branch@v1
  with:
    branch: my-branch
    dirs: "dist" 
```

## Inputs

* `branch` **Required**

    Destination branch. Can be for example `v1`.

* `dirs` _Default: 'src'_

    Space-separated list of directories to release

* `files` _Default: 'action.ya?ml LICENSE README.md'_

    Space-separated list of files (may be regexp) to be copied

* `exclude` _Default: ''_

    Space-separated list of names to exclude (note: .git is always excluded)

## Outputs

_None_

## Example

An example of a workflow that builds a JS project and releases it to a branch with a major version number.

```yaml
name: 📦 Release

on:
  workflow_dispatch:
    inputs:
      version:
        type: string
        description: 'Version to release (eg. 1.2.3 or v1.2.3)'
        required: true

jobs:
  release:
    runs-on: ubuntu-latest
    
    steps:
      - name: Normalize version
        id: version
        uses: cdqag/normalize-version@v1
        with:
          version: ${{ inputs.version }}

      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version-file: '.nvmrc'
  
      - name: Install dependencies
        run: npm ci
  
      - name: Build
        run: npm run build

      - name: Configure git user
        uses: snow-actions/git-config-user@v1.0.0
        with:
          name: github-actions[bot]
          email: github-actions[bot]@users.noreply.github.com

      - name: Release dist to major version branch
        uses: cdqag/release-to-branch@v1
        with:
          branch: ${{ steps.version.outputs.major }}
          dirs: dist

      - name: Release
        uses: ncipollo/release-action@v1
        with:
          token: ${{ github.token }}
          commit: refs/heads/${{ steps.version.outputs.major }}
          tag: ${{ steps.version.outputs.semver }}
```

## License

This project is licensed under the Apache-2.0 License. See the [LICENSE](LICENSE) file for details.
