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

    # Keep default GITHUB_TOKEN permissions read-only.
    # Individual workflows/jobs should request write permissions explicitly when needed.
    gh api \
      --method PUT \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2026-03-10" \
      "/repos/$OWNER/$REPO/actions/permissions/workflow" \
      -f default_workflow_permissions=read \
      -F can_approve_pull_request_reviews=false

    # Create repository ruleset for main.
    # Required check contexts must match workflow job names.
    gh api \
      --method POST \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2026-03-10" \
      "/repos/$OWNER/$REPO/rulesets" \
      --input - <<'JSON'
    {
      "name": "main protection",
      "target": "branch",
      "enforcement": "active",
      "conditions": {
        "ref_name": {
          "include": ["refs/heads/main"],
          "exclude": []
        }
      },
      "rules": [
        {
          "type": "pull_request",
          "parameters": {
            "required_approving_review_count": 0,
            "dismiss_stale_reviews_on_push": false,
            "require_code_owner_review": false,
            "require_last_push_approval": false,
            "required_review_thread_resolution": false,
            "allowed_merge_methods": ["squash", "merge", "rebase"]
          }
        },
        {
          "type": "required_status_checks",
          "parameters": {
            "strict_required_status_checks_policy": true,
            "do_not_enforce_on_create": true,
            "required_status_checks": [
              { "context": "Dependency Review" },
              { "context": "Pre-commit" },
              { "context": "Test" }
            ]
          }
        },
        {
          "type": "non_fast_forward"
        },
        {
          "type": "copilot_code_review",
          "parameters": {
            "review_on_push": true,
            "review_draft_pull_requests": false
          }
        }
      ]
    }
    JSON

    echo " Created and cloned: $OWNER/$REPO"
    echo " Configured workflow permissions and main branch ruleset"
    echo " Next:"
    echo "  cd $REPO"
  '';
}

# { pkgs }:
#
# pkgs.writeShellApplication {
#   name = "create-project";
#   runtimeInputs = with pkgs; [
#     gh
#     git
#   ];
#   text = ''
#     set -euo pipefail
#     OWNER="''${1:?OWNER is required}"
#     REPO="''${2:?REPO is required}"
#     VISIBILITY="''${3:-public}"
#     case "$VISIBILITY" in
#       public)
#         visibility_flag="--public"
#         ;;
#       private)
#         visibility_flag="--private"
#         ;;
#       internal)
#         visibility_flag="--internal"
#         ;;
#       *)
#         echo "VISIBILITY must be public, private, or internal" >&2
#         exit 1
#         ;;
#     esac
#     gh auth status >/dev/null
#     gh repo create "$OWNER/$REPO" \
#       --template 5h0utat0t2uka/template \
#       "$visibility_flag" \
#       --clone
#     gh api \
#       --method PUT \
#       -H "Accept: application/vnd.github+json" \
#       -H "X-GitHub-Api-Version: 2022-11-28" \
#       "/repos/$OWNER/$REPO/actions/permissions/workflow" \
#       -f default_workflow_permissions=write \
#       -F can_approve_pull_request_reviews=false
#     gh api \
#       -H "Accept: application/vnd.github+json" \
#       -H "X-GitHub-Api-Version: 2022-11-28" \
#       "/repos/$OWNER/$REPO/actions/permissions/workflow"
#
#     echo " Created and cloned: $OWNER/$REPO"
#     echo " Next:"
#     echo "  cd $REPO"
#   '';
# }
#
