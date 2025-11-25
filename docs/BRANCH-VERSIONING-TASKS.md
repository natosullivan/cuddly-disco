# Branch-Based Versioning - Implementation Tasks

This document breaks down the branch-based versioning implementation into manageable, testable tasks using a hybrid approach: build core infrastructure first, then add incremental automation.

## Task Breakdown Strategy

**Approach**: Hybrid - core infrastructure then incremental features
- Each task delivers testable functionality
- Tasks build on each other but can be validated independently
- Early tasks use manual steps that later tasks automate
- Allows for learning and adjustment between tasks

---

## Task 1: Manual Branch Deployment (Foundation)

**Goal**: Prove the end-to-end workflow works manually before automating.

**Scope**:
- Manually create values file for a test branch
- Update ApplicationSet to discover branch values files
- Deploy to dev cluster and test access via header
- Manual cleanup

**Deliverables**:
1. New ApplicationSet: `k8s/argocd-appsets/team-apps-branches.yaml`
   - Uses Git file generator to discover `values-dev-*.yaml` files
   - Excludes static versions (v1, v2) using pattern matching
2. Template values file: `k8s/team-apps/frontend/values-dev-TEMPLATE.yaml`
   - Documents structure for branch values files
   - Includes comments explaining each field
3. Manual test case:
   - Create `values-dev-test-branch.yaml` (copy from template)
   - Commit and push
   - Verify ArgoCD creates Application
   - Test access with `curl -H "X-Version: test-branch"`
   - Verify correct backend routing
   - Delete values file and verify cleanup
4. Documentation: `docs/MANUAL-BRANCH-DEPLOY.md`
   - Step-by-step manual deployment process
   - Testing checklist
   - Troubleshooting guide

**Testing Checklist**:
- [ ] ApplicationSet discovers new values file within 3 minutes
- [ ] ArgoCD Application created with correct name pattern
- [ ] Deployment succeeds and pods are running
- [ ] Service and HTTPRoute created correctly
- [ ] Can access via `X-Version` header
- [ ] Frontend can reach backend (if both deployed)
- [ ] Deleting values file triggers ArgoCD to prune resources
- [ ] All resources cleaned up within 2 minutes

**Success Criteria**:
- Complete manual deployment and cleanup in <15 minutes
- All resources have correct naming (unique per branch)
- Header-based routing works as expected
- Documentation clear enough for other developers to follow

**Estimated Effort**: 2-3 hours
**Dependencies**: None
**Risks**: Git file generator may not work as expected (can fall back to manual list in ApplicationSet)

---

## Task 2: CI Workflow for Branch Builds

**Goal**: Automate container image building and publishing for feature branches.

**Scope**:
- Add new jobs to CI workflow for branch detection and building
- Build and publish images with branch-specific tags
- No Helm values automation yet (still manual from Task 1)

**Deliverables**:
1. Updated `.github/workflows/ci.yml`:
   - New job: `detect-changes` (detects which apps changed)
   - New job: `get-version-info` (generates version string)
   - New job: `build-branch-frontend` (conditional on changes)
   - New job: `build-branch-backend` (conditional on changes)
2. Branch name sanitization script:
   - Reusable shell function for consistent sanitization
   - Unit tests for edge cases (special characters, long names, etc.)
3. Image tagging strategy:
   - Format: `vX.X.X-<sanitized-branch-name>`
   - Published to GHCR
4. Testing:
   - Create test branch with frontend changes only
   - Verify only frontend image built
   - Create test branch with both changes
   - Verify both images built with same tag

**Testing Checklist**:
- [ ] Push to feature branch triggers workflow
- [ ] Workflow skips on push to main (existing workflow handles main)
- [ ] `detect-changes` correctly identifies frontend changes
- [ ] `detect-changes` correctly identifies backend changes
- [ ] `detect-changes` correctly identifies both changes
- [ ] Version string format matches spec (vX.X.X-branch-name)
- [ ] Branch name sanitization works for all test cases
- [ ] Frontend image published only when frontend changed
- [ ] Backend image published only when backend changed
- [ ] Images tagged correctly in GHCR
- [ ] Can pull and run images locally

**Test Cases for Branch Sanitization**:
```bash
feature/add-user-auth          → add-user-auth
bugfix/fix-timeout-issue       → fix-timeout-issue
PROJ-123/implement-feature     → proj-123-implement-feature
user/john/experimental         → john-experimental
add_user_auth                  → add-user-auth
add.user.auth                  → add-user-auth
feature/CAPS-and-123           → caps-and-123
very/long/nested/branch/name   → long-nested-branch-name (or truncate?)
```

**Success Criteria**:
- Branch push builds images in <5 minutes
- Only changed apps are built (saves time and resources)
- Images are accessible in GHCR
- Version string is consistent and readable

**Estimated Effort**: 3-4 hours
**Dependencies**: Task 1 (for testing deployment of built images)
**Risks**:
- GHCR rate limits (mitigate: use caching, conditional builds)
- Branch name sanitization edge cases (mitigate: comprehensive test suite)

---

## Task 3: Automated Helm Values Generation

**Goal**: Automatically create and update Helm values files when branch images are built.

**Scope**:
- Generate values files from template
- Commit values files to Git repository
- Handle both creation and updates

**Deliverables**:
1. Values file template with variable substitution:
   - Use environment variables for dynamic values
   - Separate templates for frontend and backend
2. New CI job: `update-branch-helm-values`
   - Depends on build jobs
   - Generates values files using template + variables
   - Determines backend URL (branch-specific vs default)
   - Commits to Git using bot token
   - Uses `[skip ci]` to prevent trigger loops
3. Logic for backend URL selection:
   - If both frontend and backend changed: point to branch backend
   - If only frontend changed: point to default backend (v1)
4. Update existing template: `values-dev-TEMPLATE.yaml` → script/generator

**Testing Checklist**:
- [ ] Push to frontend-only branch generates frontend values file
- [ ] Push to backend-only branch generates backend values file
- [ ] Push to both generates both values files
- [ ] Values file has correct image tag
- [ ] Values file has correct version name (sanitized branch)
- [ ] Frontend values file points to correct backend URL
- [ ] Values file committed to Git with `[skip ci]`
- [ ] ArgoCD detects values file and deploys (from Task 1)
- [ ] Subsequent push updates existing values file (doesn't duplicate)
- [ ] Git commit message is clear and informative

**Backend URL Test Cases**:
```
Frontend changed only:
  backendUrl: http://backend-dev-v1-backend-app.backend.svc.cluster.local:5000

Both changed:
  backendUrl: http://backend-dev-<branch>-backend-app.backend.svc.cluster.local:5000

Backend changed only:
  N/A (no frontend values file created)
```

**Success Criteria**:
- End-to-end workflow works: push → build → values → deploy
- No manual steps required after pushing to branch
- Values files are correct and deployable
- Git history is clean (meaningful commit messages)

**Estimated Effort**: 4-5 hours
**Dependencies**: Task 1 (ApplicationSet), Task 2 (image builds)
**Risks**:
- Git conflicts if multiple pushes in quick succession (mitigate: pull before commit)
- Bot token permissions (mitigate: test token scopes)
- Infinite loop if `[skip ci]` doesn't work (mitigate: test thoroughly)

---

## Task 4: Automated Cleanup Workflow

**Goal**: Automatically remove branch deployments when branches are merged or deleted.

**Scope**:
- Detect branch merge/delete events
- Remove Helm values files
- Let ArgoCD prune Kubernetes resources
- Optional: Clean up GHCR images

**Deliverables**:
1. New workflow: `.github/workflows/cleanup-branch-version.yml`
   - Triggered on `pull_request: closed` and `delete: branch`
   - Extracts and sanitizes branch name
   - Detects which values files exist
   - Deletes values files
   - Commits deletion with `[skip ci]`
2. Optional GHCR cleanup:
   - Delete container images for branch
   - Configurable via workflow input (default: keep images)
3. Manual cleanup script: `infrastructure/cleanup-branch-version.sh`
   - Backup method if workflow fails
   - Can be run locally for emergencies
4. Testing:
   - Create test branch, deploy, merge PR
   - Verify automatic cleanup
   - Create test branch, deploy, delete branch without PR
   - Verify automatic cleanup

**Testing Checklist**:
- [ ] PR merge triggers cleanup workflow
- [ ] Branch delete triggers cleanup workflow
- [ ] Workflow correctly identifies branch name from event
- [ ] Workflow detects frontend values file exists
- [ ] Workflow detects backend values file exists
- [ ] Workflow deletes only relevant values files
- [ ] Workflow doesn't fail if values files don't exist (idempotent)
- [ ] Git commit pushed successfully
- [ ] ArgoCD detects deletion and prunes resources
- [ ] All Kubernetes resources removed (Deployment, Service, HTTPRoute, ConfigMap)
- [ ] Cleanup completes within 2 minutes of merge/delete
- [ ] Manual cleanup script works as backup

**Edge Cases to Test**:
- Branch merged without values files (should not fail)
- Branch deleted while deployment is in progress (should still cleanup)
- Multiple branches deleted simultaneously
- Branch name with special characters (sanitization consistency)

**Success Criteria**:
- Fully automated cleanup on branch lifecycle completion
- No orphaned resources in dev cluster
- Manual backup method available for emergencies
- Cleanup completes quickly (<2 min)

**Estimated Effort**: 3-4 hours
**Dependencies**: Task 3 (values files exist to clean up)
**Risks**:
- GitHub event payload parsing (mitigate: test with multiple event types)
- Race condition if delete happens during deploy (mitigate: idempotent operations)

---

## Task 5: Developer Experience & Documentation

**Goal**: Make the system easy to use and troubleshoot.

**Scope**:
- Comprehensive documentation
- PR comments with deployment status
- Troubleshooting guide
- Developer onboarding materials

**Deliverables**:
1. Updated documentation:
   - Update `CLAUDE.md` with branch versioning workflow
   - Update `docs/KUBERNETES-DEPLOYMENT.md` with branch deployment section
   - Create `docs/BRANCH-DEPLOYMENT-GUIDE.md` for developers
2. PR comment automation:
   - Add step to `update-branch-helm-values` job
   - Comment on PR with deployment status and access instructions
   - Example: "✅ Frontend deployed to `dev` as version `add-user-auth`. Access with header `X-Version: add-user-auth` at http://dev.cuddly-disco.ai.localhost:3000"
3. Troubleshooting guide:
   - Common issues and solutions
   - How to check deployment status
   - How to manually trigger redeploy
   - How to manually cleanup
4. Developer onboarding:
   - Quick start guide (5-minute read)
   - Video walkthrough (optional)
   - FAQ section

**Documentation Sections**:

**For Developers**:
- How to deploy your branch (2-step process: push to branch)
- How to access your deployment (curl command, browser extension)
- How to check deployment status (GitHub Actions, ArgoCD UI)
- How to troubleshoot failed deployments
- How to manually cleanup (if needed)

**For Operations**:
- How the system works (architecture overview)
- Monitoring and alerting
- Resource quota management
- Manual intervention procedures
- Disaster recovery

**Testing Checklist**:
- [ ] Documentation is accurate and up-to-date
- [ ] PR comments appear on test PR
- [ ] PR comments include correct version name and URL
- [ ] Troubleshooting guide covers common issues
- [ ] New developer can follow quick start successfully
- [ ] FAQ answers real questions from team

**Success Criteria**:
- Developer can deploy and test branch without assistance
- Common issues have documented solutions
- PR comments provide all necessary information
- Positive feedback from team on usability

**Estimated Effort**: 2-3 hours
**Dependencies**: Tasks 1-4 (complete workflow to document)
**Risks**: None significant

---

## Task 6: Monitoring & Observability (Optional/Future)

**Goal**: Add visibility into branch deployment health and resource usage.

**Scope**:
- Metrics for branch deployments
- Dashboard showing active versions
- Alerts for failures and resource issues

**Deliverables**:
1. Metrics collection:
   - Number of active branch versions (by app)
   - Age of branch versions
   - Resource utilization per branch
   - Deployment success/failure rate
2. Grafana dashboard:
   - Active branch versions table
   - Resource usage graphs
   - Deployment timeline
3. Alerting rules:
   - Failed branch deployment
   - Resource quota approaching limit
   - Stale branch version (>7 days old)
   - Cleanup workflow failure

**Testing Checklist**:
- [ ] Metrics collected correctly
- [ ] Dashboard displays accurate information
- [ ] Alerts trigger on failure scenarios
- [ ] Alert routing works (Slack/email/etc.)

**Success Criteria**:
- Full visibility into branch deployment state
- Proactive alerting on issues
- Easy to identify and cleanup stale versions

**Estimated Effort**: 4-6 hours
**Dependencies**: Tasks 1-4 (complete workflow to monitor)
**Risks**: Depends on existing monitoring infrastructure
**Priority**: Lower - can be added after core functionality working

---

## Testing Strategy

### Unit Testing
- Branch name sanitization (multiple test cases)
- Version string generation
- Template rendering
- Backend URL logic

### Integration Testing
Each task has its own integration test checklist (see above).

### End-to-End Testing
After Task 3 is complete:

**Test Scenario 1: Frontend-Only Change**
1. Create branch `feature/update-ui`
2. Make change to `apps/frontend/app/page.tsx`
3. Push to GitHub
4. Verify:
   - Only frontend image built
   - Only frontend values file created
   - Frontend deployed to dev
   - Can access via `X-Version: update-ui`
   - Frontend uses default backend (v1)
5. Merge PR
6. Verify automatic cleanup

**Test Scenario 2: Backend-Only Change**
1. Create branch `feature/new-messages`
2. Make change to `apps/backend/app.py`
3. Push to GitHub
4. Verify:
   - Only backend image built
   - Only backend values file created
   - Backend deployed to dev
   - Default frontend (v1) can call new backend via header
5. Delete branch
6. Verify automatic cleanup

**Test Scenario 3: Full-Stack Change**
1. Create branch `feature/add-user-auth`
2. Make changes to both frontend and backend
3. Push to GitHub
4. Verify:
   - Both images built with same version tag
   - Both values files created
   - Both deployed to dev
   - Frontend points to branch-specific backend
   - Can access full stack via `X-Version: add-user-auth`
5. Make additional changes and push
6. Verify values files updated (not duplicated)
7. Merge PR
8. Verify automatic cleanup of both apps

**Test Scenario 4: Multiple Concurrent Branches**
1. Create 3 branches with different changes
2. Push all within short time window
3. Verify:
   - All deploy successfully
   - No resource conflicts
   - Each accessible via unique header
   - Resource quotas not exceeded
4. Merge all PRs
5. Verify all cleaned up

### Performance Testing
- Build time: <5 minutes from push to deployed
- Cleanup time: <2 minutes from merge to resources removed
- Resource usage: Multiple branches don't exhaust cluster resources

### Failure Testing
- Push fails mid-build → verify no partial deployment
- Values file commit fails → verify no orphaned images
- ArgoCD sync fails → verify error visible in PR comment
- Cleanup workflow fails → verify manual cleanup script works

---

## Rollout Plan

### Phase 1: Internal Testing (Tasks 1-3)
- Deploy to dev environment only
- Test with 2-3 internal developers
- Gather feedback on workflow
- Iterate on issues
- Duration: 1-2 weeks

### Phase 2: Team Rollout (Task 4)
- Add cleanup automation
- Announce to full team
- Provide training/demo session
- Monitor for issues
- Duration: 1-2 weeks

### Phase 3: Documentation & Polish (Task 5)
- Complete all documentation
- Add PR comments
- Create troubleshooting guides
- Duration: 1 week

### Phase 4: Monitoring (Task 6 - Optional)
- Add observability
- Set up alerts
- Create dashboards
- Duration: 1 week

### Total Estimated Timeline: 4-6 weeks

---

## Risk Mitigation

### Technical Risks

**Risk**: Git file generator doesn't work as expected
- **Mitigation**: Test in Task 1, fall back to manual list if needed
- **Impact**: Medium - would require manual ApplicationSet updates

**Risk**: GHCR rate limits or quota issues
- **Mitigation**: Use Docker layer caching, only build changed apps
- **Impact**: Low - unlikely with current usage

**Risk**: ArgoCD performance with many Applications
- **Mitigation**: Monitor ApplicationSet reconciliation time, add quotas
- **Impact**: Medium - may need to limit concurrent branches

**Risk**: Git history pollution with bot commits
- **Mitigation**: Use `[skip ci]`, clear commit messages, consider separate branch
- **Impact**: Low - cosmetic issue mostly

### Process Risks

**Risk**: Developers create too many branch versions
- **Mitigation**: Add resource quotas, automated cleanup of stale versions
- **Impact**: Medium - could exhaust cluster resources

**Risk**: Confusion about which version to test
- **Mitigation**: Clear PR comments, documentation, naming convention
- **Impact**: Low - education issue

**Risk**: Breaking changes to ApplicationSet affect existing deployments
- **Mitigation**: Separate ApplicationSet for branch versions, thorough testing
- **Impact**: High - use separate ApplicationSet to isolate risk

---

## Success Metrics

### Task Completion Metrics
- [ ] Task 1: Manual deployment works end-to-end
- [ ] Task 2: CI builds branch images automatically
- [ ] Task 3: Values files auto-generated and deployed
- [ ] Task 4: Cleanup automated on merge/delete
- [ ] Task 5: Documentation complete and validated
- [ ] Task 6: Monitoring in place (optional)

### Operational Metrics
- Time from push to deployed: <5 minutes (target)
- Cleanup time: <2 minutes (target)
- Developer satisfaction: Positive feedback
- Resource utilization: <50% of dev cluster capacity
- Deployment success rate: >95%

---

## Appendix: Task Dependencies

```
Task 1 (Manual Deploy)
  ↓
Task 2 (CI Builds) ←──┐
  ↓                    │
Task 3 (Auto Values) ──┤
  ↓                    │
Task 4 (Cleanup) ──────┘
  ↓
Task 5 (Documentation)
  ↓
Task 6 (Monitoring) [Optional]
```

**Task 2 depends on Task 1** for testing (need ApplicationSet to deploy built images)
**Task 3 depends on Tasks 1 & 2** (needs ApplicationSet and images)
**Task 4 depends on Task 3** (needs values files to clean up)
**Task 5 depends on Tasks 1-4** (documents complete workflow)
**Task 6 depends on Tasks 1-4** (monitors complete workflow)

---

## Next Steps

1. Review this task breakdown with team
2. Adjust task scope/order based on feedback
3. Assign owners for each task (or work sequentially)
4. Create GitHub issues for each task with checklists
5. Start with Task 1 to validate approach
6. Iterate and adjust plan as you learn

**Ready to start Task 1?**
