# Netlify Deployment

**Language / 언어:** [English](netlify-deployment.md) | [한국어](netlify-deployment.ko.md)

On October 4, 2026, the observed Netlify UI required a Pro upgrade to attach this private organization repository through native Git builds. The project did not upgrade. This is a historical account-specific observation, not a current pricing guarantee.

The selected path is **GitHub Actions → Netlify CLI → existing Netlify site**, preserving the private organization repository, site URL, and production environment settings.

- Repository: `Disciple-International-Christian-School/danielyi-jeoul`
- Existing site ID: `df6ae713-42c1-4e56-bb5a-e134553fcb24`
- Workflow: `.github/workflows/netlify-deploy.yml`
- CLI pinned to `27.10.2`; the token is passed only to deployment after dependency/CLI installation.
- Runs for main app/build-file changes or manual Run workflow.
- PRs validate without reading deployment credentials or deploying.
- Same-branch deployments run sequentially without canceling a running deployment.

## Initial connection

1. Set repository secret NETLIFY_AUTH_TOKEN under Settings → Secrets and variables → Actions. Never put it in code, documentation, or chats.
2. Merge only after PR validation succeeds.
3. Verify validation and actual deployment in Actions.
4. Compare the Actions deploy ID with Netlify's production-ready state and site ID.
5. After checking production, stop the old personal-repository Git builds to avoid duplicate deployment. Keep the site itself.

Missing tokens stop deployment explicitly. Configuration merge or green CI alone does not establish successful deployment.

## Build and environment

`deploy --prod --context=production` reads netlify.toml and publishes only dist. Do not publish repository roots, docs, SQL, or rosters. Use existing production VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY. Browser bundles may contain only publishable/anon keys, never service_role. This workflow does not apply DB migrations.

## Verification scope

PR validation runs npm ci, typecheck, and build. Production environment/Functions/authentication validity requires an actual authorized deployment. Reference: [Netlify CLI deploy command](https://cli.netlify.com/commands/deploy/).
