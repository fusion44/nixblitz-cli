{lib, ...}: rec {
  pathIsRegularFile = path: let
    dir = builtins.dirOf path;
    dirListing =
      if builtins.pathExists dir
      then builtins.readDir dir
      else {};
    base = builtins.baseNameOf path;
  in
    builtins.pathExists dir
    && builtins.hasAttr base dirListing
    && dirListing.${base} == "regular";

  pathIsGitRepo = gitDir:
    builtins.pathExists gitDir && pathIsRegularFile (gitDir + "/HEAD");

  pathIsJjRepo = jjDir:
    builtins.pathExists (jjDir + "/repo");

  /**
  Get the current checkout commit of a Git repo.

  # Inputs

  `path`

  : Path to the `.git` directory

  # Examples
  :::{.example}
  ## `commitIdFromGitRepo` usage example

  ```nix
  commitIdFromGitRepo <nixpkgs/.git>
  ```
  :::
  */
  inherit (lib) commitIdFromGitRepo;

  /**
  Get the current checkout commit of a Jujutsu repo.

  # Inputs

  `{ jjDir, branch ? "main", default ? "unknown" }`

  : Attribute set with the path to the `.jj` directory, optional branch name,
    and an optional fallback value used when the Git export ref is not available.

  # Examples
  :::{.example}
  ## `commitIdFromJjRepo` usage example

  ```nix
  commitIdFromJjRepo { jjDir = <nixpkgs/.jj>; }
  ```
  :::
  */
  commitIdFromJjRepo = {
    jjDir,
    branch ? "main",
    default ? "unknown",
  }: let
    commitIdOrError = _commitIdFromJjRepoOrError jjDir branch;
  in
    if commitIdOrError ? value
    then commitIdOrError.value
    else
      builtins.trace
      ("commitIdFromJjRepo: " + commitIdOrError.error + "; using fallback \"" + default + "\"")
      default;

  /**
  Get the current checkout commit of a repository that may be Git or Jujutsu.

  # Inputs

  `{ repoRoot, branch ? "main", default ? "unknown" }`

  : Attribute set with the repository root directory, optional branch name
    (used for Jujutsu), and an optional fallback value returned when no VCS
    metadata is available.

  # Examples
  :::{.example}
  ## `commitIdFromRepo` usage example

  ```nix
  commitIdFromRepo { repoRoot = ./.; }
  ```
  :::
  */
  commitIdFromRepo = {
    repoRoot,
    branch ? "main",
    default ? "unknown",
  }: let
    gitDir = repoRoot + "/.git";
    gitAttempt =
      if pathIsGitRepo gitDir
      then let
        res = builtins.tryEval (commitIdFromGitRepo gitDir);
      in
        if res.success
        then res.value
        else
          builtins.trace
          ("commitIdFromRepo: failed to read " + toString gitDir + "; ignoring Git metadata")
          null
      else null;

    jjDir = repoRoot + "/.jj";
    jjAttempt =
      if builtins.pathExists jjDir
      then commitIdFromJjRepo {inherit branch default jjDir;}
      else null;
  in
    if gitAttempt != null
    then gitAttempt
    else if jjAttempt != null
    then jjAttempt
    else
      builtins.trace
      ("commitIdFromRepo: no .git or .jj directory found in "
        + toString repoRoot
        + "; using fallback \""
        + default
        + "\"")
      default;

  # Returns `{ value = commitHash }` or `{ error = "... message ..." }`.
  _commitIdFromJjRepoOrError = jjDir: branch: let
    repoDir = jjDir + "/repo";
    refFile = repoDir + "/store/git/refs/heads/${branch}";
  in
    if !builtins.pathExists jjDir
    then {error = "Jujutsu directory does not exist: " + toString jjDir;}
    else if !builtins.pathExists repoDir
    then {error = "Not a Jujutsu repo (missing repo/): " + toString jjDir;}
    else if !pathIsRegularFile refFile
    then {error = "Missing Git export ref: " + refFile;}
    else let
      commitId = lib.fileContents refFile;
    in
      if commitId == ""
      then {error = "Empty commit id in " + refFile;}
      else {value = commitId;};
}
