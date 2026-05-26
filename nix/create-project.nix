{ pkgs }:

pkgs.writeShellApplication {
  name = "create-project";
  runtimeInputs = with pkgs; [
    gh
    git
  ];
  text = ''
    set -euo pipefail
    OWNER="''${1:?OWNER is required}"
    REPO="''${2:?REPO is required}"
    VISIBILITY="''${3:-public}"
    case "$VISIBILITY" in
      public)
        visibility_flag="--public"
        ;;
      private)
        visibility_flag="--private"
        ;;
      internal)
        visibility_flag="--internal"
        ;;
      *)
        echo "VISIBILITY must be public, private, or internal" >&2
        exit 1
        ;;
    esac
    gh auth status >/dev/null
    gh repo create "$OWNER/$REPO" \
      --template 5h0utat0t2uka/template \
      "$visibility_flag" \
      --clone
    gh api \
      --method PUT \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "/repos/$OWNER/$REPO/actions/permissions/workflow" \
      -f default_workflow_permissions=write \
      -F can_approve_pull_request_reviews=false
    gh api \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "/repos/$OWNER/$REPO/actions/permissions/workflow"

    echo " Created and cloned: $OWNER/$REPO"
    echo " Next:"
    echo "  cd $REPO"
  '';
}

