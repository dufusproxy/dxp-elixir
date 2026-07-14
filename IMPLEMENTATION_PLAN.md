# DXP Elixir Implementation Plan

## Project Overview

This plan implements a multi-tenant DXP using Elixir/Phoenix with the Ash framework. The implementation follows strict dependency chains and architectural principles from the specification documents.

**Current State:** Empty Elixir project (no source files exist)
**Primary Goal:** Reach Phase 1 dogfood deployment with functional asset graph, component rendering pipeline, and AshAdmin developer UI

**Tech Stack:**
- Backend: Elixir/Phoenix
- ORM: Ash framework
- Database: PostgreSQL 16+ (AshPostgres)
- Storage: MinIO (S3-compatible)
- Cache: Cachex (tier-1) + Redis (tier-2) + ETS (ASTs)
- Background: Oban via AshOban
- Identity: Keycloak + AshAuthentication
- Observability: OpenTelemetry → Grafana stack

---

## Milestone 1: Project Scaffolding (Spec 01)
**PR:** #1
**Blocks:** All subsequent work
**Dependencies:** None

### Tasks
- [ ] Create Ash project with `mix igniter.new core --install ash`
- [ ] Add `ash_postgres` dependency and configure for PostgreSQL 16+
- [ ] Configure Ash `:attribute` multitenancy strategy with `tenant_id` from first resource
- [ ] Set up `docker-compose.yml` with PostgreSQL service
- [ ] Configure CI pipeline:
  - [ ] Compile with warnings-as-errors
  - [ ] `mix format --check-formatted`
  - [ ] Credo linting
  - [ ] Test execution
- [ ] Verify basic Ash resource creation/querying in `iex -S mix`

### Acceptance Criteria
- `docker compose up` brings up PostgreSQL successfully
- `mix deps.get` completes without errors
- `iex -S mix` allows creating and querying Ash resource backed by Postgres
- All resources have tenant-scoped queries from first commit
- Build passes with zero warnings
- CI pipeline passes all checks

---

## Milestone 2: Asset Model - Core Resources (Spec 02, Part A)
**PR:** #2
**Blocks:** 03, 04, 07, 11, 12
**Dependencies:** Milestone 1 complete

### Tasks
- [ ] Create `Core.Assets.Asset` Ash resource:
  - [ ] `uuid_primary_key :id`
  - [ ] `attribute :type, :atom` (required)
  - [ ] `attribute :role, :atom`
  - [ ] `timestamps()`
  - [ ] `attribute :tenant_id` for multitenancy
  - [ ] Extensions:
    - [ ] `AshPaperTrail.Resource` (versioning with full_diff)
    - [ ] `AshArchival.Resource` (soft-delete)
    - [ ] `AshOban`
- [ ] Implement state machine with `AshStateMachine`:
  - [ ] States: `draft → review → live → safe_edit → archived`
  - [ ] Define valid transitions
  - [ ] Add `attribute :state, :atom`
- [ ] Create `Core.Assets.AssetLink` Ash resource (DAG edges):
  - [ ] `attribute :parent_id, :uuid`
  - [ ] `attribute :child_id, :uuid`
  - [ ] `attribute :link_type, :atom` (primary, secondary, notice)
  - [ ] Multitenancy on `tenant_id`
  - [ ] Cycle prevention on link creation
- [ ] Implement DAG traversal Ash calculations:
  - [ ] `ancestors` - calculate all parent assets
  - [ ] `descendants` - calculate all child assets
  - [ ] `paths` - calculate paths between assets
- [ ] Create `Core.Metadata.MetadataSchema` resource:
  - [ ] Schema definitions for typed metadata
- [ ] Create `Core.Metadata.MetadataValue` resource:
  - [ ] Instance values bound to schemas
  - [ ] Asset association
- [ ] Create `Core.Workflows.Workflow` resource:
  - [ ] Workflow definition structures
- [ ] Create `Core.Workflows.WorkflowRun` resource:
  - [ ] Workflow execution tracking
- [ ] Create `Core.Assets.Permission` resource:
  - [ ] `attribute :asset_id, :uuid`
  - [ ] `attribute :principal_id, :uuid`
  - [ ] `attribute :level, :atom` (:read, :write, :admin)
- [ ] All resources include AshPaperTrail versioning
- [ ] All resources include `tenant_id` multitenancy

### Acceptance Criteria
- Asset resource with all extensions configured
- AssetLink prevents cycles on creation
- DAG calculations return correct ancestor/descendant lists
- All mutations produce AshPaperTrail versions
- Soft-deleted assets are restorable
- No query can cross tenant boundaries
- Tests cover DAG integrity, versioning, and multitenancy

---

## Milestone 3: Asset Model - Implications System (Spec 02, Part B)
**PR:** #3
**Blocks:** 03, 04, 07, 11, 12
**Dependencies:** Milestone 2 complete

### Tasks
- [ ] Design and implement `Core.Implications` Spark DSL extension:
  - [ ] `implies` directive in asset definitions
  - [ ] Per-implication configuration:
    - [ ] `default` value
    - [ ] `surfaced_as` (:inline_field or :advanced_panel)
    - [ ] `on_delete` (:cascade or :convert_to_redirect)
- [ ] Implement implied asset creation logic:
  - [ ] Trigger on parent asset creation
  - [ ] Create implied assets with appropriate type/role
  - [ ] Apply default values
  - [ ] Establish AssetLink relationships
- [ ] Implement cascade delete behavior:
  - [ ] On parent delete, delete implied assets with `on_delete: :cascade`
  - [ ] On parent delete, convert implied assets to redirects with `on_delete: :convert_to_redirect`
- [ ] Create `Core.Content.Page` example asset:
  - [ ] `implies :url` with surfaced_as :inline_field
  - [ ] `implies :metadata_record` with surfaced_as :advanced_panel
- [ ] Write DSL compiler and validation
- [ ] Add tests for implication system

### Acceptance Criteria
- Creating a Page asset implicitly creates URL and metadata record assets
- Implied assets have correct AssetLink relationships
- Delete behavior matches `on_delete` configuration
- DSL validates correctly
- Tests cover all implication scenarios

---

## Milestone 4: Permissions & Policies (Spec 03)
**PR:** #4
**Blocks:** 04, 11, 12
**Dependencies:** Milestone 3 complete

### Tasks
- [ ] Verify `Core.Assets.Permission` resource from Milestone 2
- [ ] Implement `Core.Policies.HasAssetPermission` Ash policy check module:
  - [ ] Resolve effective permission level via DAG inheritance
  - [ ] Walk primary-parent chain
  - [ ] Nearest explicit grant wins
  - [ ] Return effective level (:read, :write, :admin, or nil)
- [ ] Wire policies on Asset resource:
  - [ ] `action_type(:read)` requires :read permission
  - [ ] `action_type([:create, :update])` requires :write permission
  - [ ] `action_type(:destroy)` requires :admin permission
- [ ] Implement ETS-backed permission cache:
  - [ ] Cache key: `{actor_id, asset_id}` → permission level
  - [ ] Cache invalidation on Permission mutations (Ash change hooks)
  - [ ] Cache invalidation on AssetLink mutations (affects inheritance)
  - [ ] Phoenix PubSub for cache busting across nodes
- [ ] Write property tests:
  - [ ] Permission inheritance through DAG
  - [ ] Multiple parent resolution
  - [ ] Permission revocation propagation
  - [ ] Cache coherence validation
- [ ] Write regression tests
- [ ] Implement load test for warm-cache authorization

### Acceptance Criteria
- Permission resource enforces asset-level access control
- Policy module correctly resolves inherited permissions
- ETS cache reduces authorization overhead to negligible latency
- All tests pass including property and regression tests
- Load test shows cache hits add minimal latency
- Multitenancy applies to Permission resource

---

## Milestone 5: Content API & Identity (Spec 04)
**PR:** #5
**Blocks:** 12
**Dependencies:** Milestone 4 complete

### Tasks
- [ ] Set up AshJsonApi domain:
  - [ ] Add `ash_json_api` dependency
  - [ ] Configure JSON API domain
- [ ] Implement API endpoints:
  - [ ] `POST /api/v1/assets` - create asset
  - [ ] `PATCH /api/v1/assets/:id` - update asset
  - [ ] `POST /api/v1/assets/:id/links` - add secondary/notice link
  - [ ] `POST /api/v1/assets/:id/permissions` - grant/revoke permissions
  - [ ] `POST /api/v1/assets/:id/workflow/transitions` - workflow transitions
  - [ ] `DELETE /api/v1/assets/:id` - soft-delete via AshArchival
- [ ] Configure response formats:
  - [ ] Include created asset in POST response
  - [ ] Include implied assets in create responses
  - [ ] Include PaperTrail version metadata
- [ ] Generate and serve OpenAPI document
- [ ] Implement domain events:
  - [ ] All Ash actions emit to Phoenix PubSub topics
  - [ ] Event structure includes actor, asset, action type
- [ ] Set up AshOban workers:
  - [ ] Subscribe to domain events
  - [ ] Process asynchronous tasks
- [ ] Identity setup:
  - [ ] Configure Keycloak for SSO/SAML
  - [ ] Add `ash_authentication` dependency
  - [ ] Configure service-to-service token authentication
  - [ ] Implement actor resolution from tokens
- [ ] Wire authentication to policy layer
- [ ] Define error envelope conventions
- [ ] Implement rate limiting
- [ ] Document API in `docs/api/` directory

### Acceptance Criteria
- All API endpoints functional and policy-enforced
- Create/update/delete produces PaperTrail versions
- Implied assets included in create responses
- Domain events published for all mutations
- AshOban workers receive and process events
- Authentication resolves actor for policy checks
- OpenAPI document available and accurate
- Authoring save P95 <300ms baseline met
- API documentation complete

---

## Milestone 6: Unified Component Model & Contract (Spec 05)
**PR:** #6
**Blocks:** 07, 08, 14, 15
**Dependencies:** Milestone 5 complete

### Tasks
- [ ] Define component contract specification:
  - [ ] Document `manifest.yaml` structure
  - [ ] Publish contract in `docs/component-contract.md`
- [ ] Create `Core.Components.Manifest` Elixir module:
  - [ ] Parser for YAML manifest format
  - [ ] Validator for contract compliance
  - [ ] JSON Schema validation for props blocks
- [ ] Create `Core.Components.Component` Ash resource:
  - [ ] `attribute :name, :string` (globally unique per tenant)
  - [ ] `attribute :current_version, :string` (semver)
  - [ ] `attribute :roles, {:array, :atom}`
  - [ ] `attribute :metadata, :map`
  - [ ] Multitenancy on tenant_id
  - [ ] AshPaperTrail for version tracking
- [ ] Create `Core.Components.ComponentVersion` Ash resource:
  - [ ] `attribute :component_id` (parent Component)
  - [ ] `attribute :version, :string` (semver)
  - [ ] `attribute :manifest, :map` (parsed manifest data)
  - [ ] `attribute :artefacts, :map` (storage paths)
  - [ ] `attribute :state, :atom` (:draft, :published, :archived)
  - [ ] Multitenancy on tenant_id
- [ ] Create `Core.Components.ComponentSubscription` Ash resource:
  - [ ] `attribute :site_id, :uuid` (asset reference)
  - [ ] `attribute :component_name, :string`
  - [ ] `attribute :version_range, :string` (semver range)
  - [ ] `attribute :pinned, :boolean` (per-asset override)
  - [ ] `attribute :pinned_version, :string`
  - [ ] AshPaperTrail for subscription changes
  - [ ] Multitenancy on tenant_id
- [ ] Implement semver range resolution:
  - [ ] Parse and validate semver ranges
  - [ ] Resolve specific version from range
  - [ ] Handle pinned versions
- [ ] Implement role/composition validation:
  - [ ] Validate page/layout/component role constraints
  - [ ] Validate slot type constraints
  - [ ] Validate expects_layout compatibility
- [ ] Create starter Phoenix-native component set:
  - [ ] Basic page component
  - [ ] Basic layout component
  - [ ] Basic component examples
  - [ ] Each with complete manifest.yaml
- [ ] Write tests for manifest validation
- [ ] Write tests for version resolution

### Acceptance Criteria
- Manifest violating contract fails with precise error message
- ComponentVersion stores valid manifests only
- Subscription resolution picks correct version per semver rules
- Pinned versions override range subscriptions
- Role/composition rules enforced
- Starter components render via Phoenix
- Contract published in documentation

---

## Milestone 7: Component Runtime Loading (Spec 06)
**PR:** #7
**Blocks:** 07, 08
**Dependencies:** Milestone 6 complete

### Tasks
- [ ] Set up object storage integration:
  - [ ] Add S3 client dependency (ExAws or similar)
  - [ ] Configure MinIO for local development
  - [ ] Define path structure: `tenants/{tenant_id}/components/{name}/{version}/`
  - [ ] Add to docker-compose.yml
- [ ] Create upload/ingest endpoint:
  - [ ] `POST /api/v1/components/upload`
  - [ ] Validate manifest before storage
  - [ ] Run layout-chain cycle analysis
  - [ ] Store artefacts in object storage
  - [ ] Create ComponentVersion record
- [ ] Implement `dxp deploy` CLI:
  - [ ] Create as Elixir escript or mix task
  - [ ] Accept component directory path
  - [ ] Package artefacts (manifest.yaml, HEEx, JS, CSS)
  - [ ] Call upload endpoint
- [ ] Implement Git webhook ingest:
  - [ ] Webhook endpoint for Git events
  - [ ] Extract component from repository
  - [ ] Trigger ingest process
- [ ] Implement HEEx loader:
  - [ ] Fetch template string from object storage
  - [ ] Compile via `Phoenix.LiveView.HTMLEngine`
  - [ ] Cache compiled AST in ETS
  - [ ] Cache key: `{component_name, version}`
  - [ ] Cache manifest structs
- [ ] Implement publish-time analysis:
  - [ ] Layout chain cycle detection
  - [ ] Reject components with cyclic dependencies
- [ ] Implement domain events and invalidation:
  - [ ] Publish event on component version create
  - [ ] Notify subscribed sites
  - [ ] Oban worker invalidates ETS cache
- [ ] Update docker-compose.yml with MinIO
- [ ] Document object storage structure

### Acceptance Criteria
- CLI uploads components successfully
- Git webhook triggers ingest
- Manifest validation rejects invalid contracts
- Layout cycle detection prevents cyclic dependencies
- HEEx templates load from object storage
- Compiled AST cached in ETS
- First render compiles from storage; subsequent hits use cache
- Publish triggers invalidation events
- Deploy-to-live <30s for component publish

---

## Milestone 8: Render Pipeline, Layouts & SSR (Spec 07)
**PR:** #8
**Blocks:** 08
**Dependencies:** Milestone 7 complete

### Tasks
- [ ] Implement route resolution:
  - [ ] URL asset → Page asset lookup
  - [ ] Page asset → component reference (by role)
  - [ ] Component reference → subscription/pin lookup
  - [ ] Subscription → ComponentVersion resolution
- [ ] Implement HEEx rendering:
  - [ ] Load compiled AST from ETS cache
  - [ ] Resolve props from asset content via Ash
  - [ ] Render HEEx with props
- [ ] Implement props validation:
  - [ ] Validate props against manifest JSON Schema
  - [ ] Return validation errors for invalid props
- [ ] Emit props payload:
  - [ ] Serialize props as JSON
  - [ ] Embed in HTML: `<script type="application/json" data-props-for="...">`
- [ ] Mark hydratable components:
  - [ ] Add `data-component` attribute
  - [ ] Add `data-component-id` attribute
- [ ] Link component styles:
  - [ ] Generate `<link>` tags for component CSS
  - [ ] Resolve paths from ComponentVersion artefacts
- [ ] Implement recursive slot-filling:
  - [ ] Match child components to parent slots
  - [ ] Validate slot type constraints
  - [ ] Render nested composition
- [ ] Implement expects_layout resolution:
  - [ ] Match component to layout by manifest declarations
  - [ ] Use default layout if specified
- [ ] Implement render-time depth limit:
  - [ ] Track nesting depth during render
  - [ ] Reject or truncate cycles detected
  - [ ] Configurable depth limit
- [ ] Implement static SSR mode (Phase 1):
  - [ ] Server-side rendering only
  - [ ] No LiveView hydration yet
- [ ] Create page controller and views:
  - [ ] Route handler for public pages
  - [ ] Error handling for missing assets
  - [ ] Cache headers
- [ ] Write render tests

### Acceptance Criteria
- End-to-end page render from authored content
- HTML complete and indexable with JS disabled
- Props validated against manifest schema
- Props embedded in HTML payload
- Component styles linked correctly
- Slot composition works recursively
- Layout resolution matches manifests
- Cyclic layouts caught by depth limit
- Public page render P95 <200ms (with task 08 caching)

---

## Milestone 9: Render Cache & Invalidation (Spec 08)
**PR:** #9 (combined with #10)
**Blocks:** Dogfood deployment
**Dependencies:** Milestone 8 complete

### Tasks
- [ ] Design cache key structure:
  - [ ] `{asset_id, page_component_version, layout_component_version, child_component_versions, locale, audience_segment}`
  - [ ] Implement composite key generation
- [ ] Implement Cachex tier-1 cache:
  - [ ] Add Cachex dependency
  - [ ] Configure cache layer
  - [ ] Store rendered HTML
  - [ ] Cache metadata (versions, timestamps)
- [ ] Add Redis tier-2 cache:
  - [ ] Add Redix dependency
  - [ ] Configure Redis connection
  - [ ] Implement two-tier caching (Cachex → Redis)
  - [ ] Add to docker-compose.yml
- [ ] Implement reference tracking:
  - [ ] Track which assets reference which components
  - [ ] Track which pages use which assets
- [ ] Implement AshOban invalidation workers:
  - [ ] Subscribe to domain events
  - [ ] Mark cache entries stale on mutations
  - [ ] Asset update → invalidate containing pages
  - [ ] Component publish → invalidate affected pages
  - [ ] AssetLink change → invalidate affected pages
- [ ] Implement regeneration-on-miss:
  - [ ] On cache miss, regenerate render
  - [ ] Write back to both cache tiers
  - [ ] Track regeneration metrics
- [ ] Add CDN integration hooks:
  - [ ] Cache invalidation API endpoints
  - [ ] Tag-based invalidation support
- [ ] Implement metrics:
  - [ ] Cache hit rate
  - [ ] Regeneration latency
  - [ ] Invalidation fan-out
  - [ ] Per-tenant statistics
- [ ] Configure LiveView opt-out:
  - [ ] Detect LiveView mode from manifest
  - [ ] Skip caching for LiveView pages
- [ ] Update docker-compose.yml with Redis
- [ ] Document cache strategy

### Acceptance Criteria
- Cachex tier-1 operational
- Redis tier-2 operational (optional dev, required prod)
- Cache hits serve HTML with minimal latency
- Asset updates invalidate only affected pages
- Component publishes invalidate affected pages
- Regeneration-on-miss writes to both tiers
- CDN can purge via API hooks
- Metrics exposed for monitoring
- LiveView pages not cached
- P95 <200ms origin on miss
- P95 <50ms edge on hit (with CDN)

---

## Milestone 10: Authoring UI - AshAdmin (Spec 12, Phase 1)
**PR:** #10
**Blocks:** Dogfood deployment
**Dependencies:** Milestone 5 complete (API & Identity)

### Tasks
- [ ] Add `ash_admin` dependency:
  - [ ] Install package
  - [ ] Configure admin domain
- [ ] Mount AshAdmin at `/admin`:
  - [ ] Add to router
  - [ ] Configure authentication
- [ ] Configure Keycloak integration:
  - [ ] Set up OAuth flow for admin
  - [ ] Map Keycloak roles to admin permissions
- [ ] Expose Asset resources in AshAdmin:
  - [ ] Asset CRUD interface
  - [ ] DAG links interface
  - [ ] Permissions interface
  - [ ] Version history browser
  - [ ] State transitions
- [ ] Expose Component resources:
  - [ ] Component CRUD
  - [ ] ComponentVersion CRUD
  - [ ] ComponentSubscription CRUD
- [ ] Expose Workflow resources:
  - [ ] Workflow configuration
  - [ ] WorkflowRun history
- [ ] Verify multi-tenant isolation:
  - [ ] Admin only sees tenant data
  - [ ] No cross-tenant queries
- [ ] Document admin interface usage
- [ ] (Optional) Create high-friction LiveView screens:
  - [ ] Page creation wizard
  - [ ] Component publish flow

### Acceptance Criteria
- AshAdmin accessible at `/admin`
- Keycloak authentication required
- All core resources manageable through UI
- Version history browsable
- State transitions executable
- DAG links editable
- Permissions assignable
- Multi-tenant isolation enforced
- Authoring save P95 <300ms

---

## Milestone 11: DAM v1 - Basic Image Support (Spec 09)
**PR:** #11
**Blocks:** Dogfood polish
**Dependencies:** Milestone 5 complete (API & Identity)

### Tasks
- [ ] Implement signed URL issuance:
  - [ ] `POST /api/v1/assets/upload/signed-url` endpoint
  - [ ] Generate time-limited signed URLs for S3/MinIO
  - [ ] Return upload URL and asset ID
- [ ] Add Image asset type:
  - [ ] Create `Core.Assets.Image` (extends Asset with type: :image)
  - [ ] Image-specific metadata attributes
- [ ] Create image metadata resources:
  - [ ] `Core.DAM.ImageMetadata` resource
  - [ ] Width, height, format, alt text attributes
- [ ] Implement upload completion flow:
  - [ ] Webhook or callback on upload complete
  - [ ] Create Image asset record
  - [ ] Trigger derivative generation
- [ ] Implement Oban derivative job:
  - [ ] Trigger on image upload
  - [ ] Generate standard sizes (thumbnails, responsive)
  - [ ] Store derivatives in object storage
  - [ ] Update metadata records
- [ ] Set up imgproxy sidecar:
  - [ ] Add to docker-compose.yml
  - [ ] Configure on-the-fly resize
  - [ ] Front through CDN
- [ ] Integrate DAM assets into permission system:
  - [ ] Image assets inherit DAG permissions
  - [ ] Policy checks apply
- [ ] Emit upload lifecycle events:
  - [ ] Publish to domain event stream
  - [ ] Include metadata changes
- [ ] Document DAM integration

### Acceptance Criteria
- Signed URLs issued for direct browser upload
- Image assets created on upload completion
- Image metadata stored in Postgres
- Binaries stored only in object storage
- Derivatives generated within 5 seconds of upload
- imgproxy serves resized images on-the-fly
- Upload events published to domain stream
- Image assets respect DAG permissions

---

## Milestone 12: Infrastructure & Observability (Spec 18)
**PR:** #12
**Blocks:** Dogfood deployment
**Dependencies:** Ongoing from Milestone 1

### Tasks (continuous through Phase 1):
- [ ] Complete docker-compose.yml:
  - [ ] PostgreSQL
  - [ ] Keycloak
  - [ ] MinIO
  - [ ] Redis
  - [ ] imgproxy
- [ ] Implement OpenTelemetry instrumentation:
  - [ ] Add OpenTelemetry dependencies
  - [ ] Configure tracing exporters
  - [ ] Instrument Phoenix endpoints
  - [ ] Instrument Ash actions
  - [ ] Instrument database queries
  - [ ] Instrument cache operations
- [ ] Set up Sentry error reporting:
  - [ ] Add Sentry dependency
  - [ ] Configure error capture
  - [ ] Add user context (tenant, actor)
- [ ] Set up Grafana stack:
  - [ ] Tempo (traces)
  - [ ] Loki (logs)
  - [ ] Prometheus (metrics)
  - [ ] Dashboards for hot-path targets
- [ ] Implement metrics:
  - [ ] Cache hit rate
  - [ ] Regeneration latency
  - [ ] Invalidation fan-out
  - [ ] API response times
  - [ ] Database query times
- [ ] Implement secrets management:
  - [ ] Configuration for environment variables
  - [ ] Document required secrets
- [ ] Implement Postgres RLS:
  - [ ] Row-level security policies
  - [ ] Defence-in-depth for multitenancy
- [ ] Set up backups:
  - [ ] Database backup strategy
  - [ ] Object backup strategy
  - [ ] Restore procedures
- [ ] Write runbooks in `docs/runbooks/`:
  - [ ] Backup and restore
  - [ ] Incident response
  - [ ] Deployment procedures
- [ ] Set up production deploy target:
  - [ ] Create `infrastructure/terraform/` structure
  - [ ] Define production infrastructure
- [ ] Add analytics:
  - [ ] PostHog integration
  - [ ] Plausible integration

### Acceptance Criteria
- All services running via docker compose
- OpenTelemetry traces exported
- Sentry capturing errors
- Grafana dashboards operational
- Metrics available for all hot paths
- Secrets managed securely
- RLS policies enforce tenant isolation
- Backup and restore documented and tested
- Production Terraform ready
- Fresh developer machine can run platform with `docker compose up` + `mix setup`

---

## Phase 1 Completion: Dogfood Deployment
**PR:** Final Phase 1 milestone
**Dependencies:** Milestones 1-12 complete

### Tasks
- [ ] Provision production infrastructure:
  - [ ] Run Terraform for production
  - [ ] Configure DNS
  - [ ] Set up CDN (Cloudflare)
- [ ] Deploy platform to production:
  - [ ] Build release
  - [ ] Deploy application
  - [ ] Run migrations
  - [ ] Configure environment
- [ ] Create dogfood tenant:
  - [ ] Seed initial tenant
  - [ ] Configure Keycloak realm
- [ ] Migrate or create one real site:
  - [ ] Create page assets
  - [ ] Upload components
  - [ ] Configure URLs
  - [ ] Upload images
- [ ] Verify all Phase 1 functionality:
  - [ ] Page rendering works
  - [ ] Cache operational
  - [ ] AshAdmin accessible
  - [ ] API functional
  - [ ] Observability dashboards live
- [ ] Measure performance against targets:
  - [ ] Public page render P95 <200ms origin
  - [ ] Public page render P95 <50ms edge
  - [ ] Authoring save P95 <300ms
  - [ ] Image upload derivatives <5s
  - [ ] Search query P95 <100ms (if implemented)
- [ ] Document Phase 1 completion
- [ ] Plan Phase 2 roadmap

### Acceptance Criteria
- Production environment operational
- Dogfood tenant serving real site
- All Phase 1 features functional
- Performance targets met
- Observability provides visibility
- AshAdmin usable for content management
- Phase 1 exit criteria satisfied

---

## Deferred: Phase 2+ Items

The following are explicitly **deferred** to Phase 2 or later:

### Phase 2 (Deferred)
- **Spec 10 - Search**: PostgreSQL FTS, pg_trgm, indexing pipeline, search API
- **Spec 11 (Phase 2 tasks)**: Workflow gates, safe-edit mode, version restore, notifications
- **Spec 12 (Phase 2 tasks)**: Editor UI decision (Vue vs LiveView), editor shell, content-shaped editor, progressive disclosure UI, asset-map view
- **Spec 13 - Multi-site, Localization, Forms**: Site concept, localization, form component
- **Spec 14 - Vite Plugin Spike**: Go/no-go decision point for Vite family
- **Spec 15 - Vite Plugin Family & Hydration**: vite-plugin-core, vite-plugin-astro, component-runtime, hydration spine
- **Spec 04 (Phase 2)**: AshGraphql alongside AshJsonApi

### Phase 3 (Deferred)
- **Spec 16**: LiveView mode, Channels mode, External mode, n8n iPaaS, RudderStack, A/B testing, RAG search, Meilisearch
- **Spec 07 (Phase 3)**: LiveView, channels, external rendering modes

### Phase 4 (Deferred)
- **Spec 17**: Agentic authoring, Content Intelligence crawler, ISO 27001, public component registry, self-host distribution

---

## Summary

This implementation plan covers **12 major milestones** for Phase 1:

1. Project scaffolding with Ash and PostgreSQL
2. Core asset model with DAG structure
3. Implications system for implicit assets
4. Permissions and policy enforcement
5. Content API and identity
6. Unified component model
7. Component runtime loading
8. Render pipeline and SSR
9. Render cache and invalidation
10. Authoring UI via AshAdmin
11. Basic DAM functionality
12. Infrastructure and observability

The plan follows strict dependency chains from the specification, ensuring each milestone builds on the previous. Phase 1 culminates in a dogfood deployment demonstrating all core functionality.

**Hot-path Performance Targets:**
- Public page render: P95 <200ms origin / <50ms edge
- Authoring save: P95 <300ms
- Image upload: derivatives <5s
- Search query: P95 <100ms (Phase 2)
- Component publish: deploy-to-live <30s
