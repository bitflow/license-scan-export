# license-scan-export

Exports needed files regarding dependencies for BitFlow's license scan.

Run the Docker image with
```
docker run -it --rm -v /path/to/code:/code ghcr.io/bitflow/license-scan-export
```
or the script directly (assumes GNU coreutils, tree, and zip are installed):
```
curl -sSL https://raw.githubusercontent.com/bitflow/license-scan-export/refs/heads/main/export.sh | bash
```

The script will copy files like `package.json` etc., preserving the folder structure, output the tree of copied files and generate a `bitflow-license-scan.zip` archive with all required files.

Please check `export.sh` for your used package managers and let us know if you are using something that is not covered.

The script will not copy any source code. Therefore, we can't check if you copied individual copyrighted source files.
Please delete any leftover files from build/bundle processes (e.g. `dist`). Ideally these files are git-ignored such that you can delete them using `git clean`.

If you have folders with third-party source code that don't come from a package manager (e.g. `vendor/jquery.js`), please share these files with us as well (they are not copied automatically since `vendor/*.js` may include internal source code).
