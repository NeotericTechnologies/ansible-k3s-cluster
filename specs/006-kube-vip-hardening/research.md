# Research: Kube-VIP Egress and HA Hardening

## Decision 1: Reuse the existing kube-vip role and templates
- **Decision**: Extend `ansible/roles/kube-vip` and the existing cluster playbooks instead of introducing a new role or separate deployment path.
- **Rationale**: The repo already deploys kube-vip as the control-plane VIP and LoadBalancer provider, and the constitution requires minimal, focused playbooks.
- **Alternatives considered**: New wrapper role, separate addon playbook, or a second manifest pipeline. Rejected because they would duplicate lifecycle logic and weaken traceability.

## Decision 2: Make kube-vip egress the default, with explicit opt-out
- **Decision**: Treat kube-vip egress as enabled by default for managed LoadBalancer traffic and use explicit exclusion / ignore controls for exceptions.
- **Rationale**: Upstream kube-vip egress docs show service-scoped egress behavior, `kube-vip.io/egress`, `externalTrafficPolicy: Local`, per-port rules, and exclusion annotations. The spec requires default-on behavior with explicit opt-out support.
- **Alternatives considered**: Manual per-service opt-in or mixed default/override models. Rejected because they increase operator burden and make behavior less predictable.

## Decision 3: Use one DHCP mode for all kube-vip LoadBalancer services when enabled
- **Decision**: When DHCP mode is enabled, apply it uniformly across all kube-vip-managed LoadBalancer services in the environment.
- **Rationale**: Upstream docs support DHCP via the special `0.0.0.0` sentinel for services and via the cloud-provider DHCP CIDR behavior. The spec explicitly chose consistency over mixed-mode service-level control.
- **Alternatives considered**: Hybrid per-service DHCP, namespace-scoped DHCP, and mixed static/DHCP modes. Rejected because they create ambiguity and violate the agreed consistency rule.

## Decision 4: Enable service election through kube-vip's documented service-election path
- **Decision**: Keep service election enabled where kube-vip manages ARP LoadBalancer leadership, using the documented `svc_election: "true"` behavior and local-service semantics.
- **Rationale**: The upstream service docs describe leader election per service and require `svc_election` for local traffic policy behavior. The current role already uses leader election for control-plane VIPs.
- **Alternatives considered**: Single-leader-only service handling or no service election. Rejected because they preserve a bottleneck and reduce HA value.

## Decision 5: Hard-fail RBAC validation before rollout
- **Decision**: RBAC regression checks must stop deployment when permissions are incomplete.
- **Rationale**: The spec calls for hard-fail deployment gates, and prior RBAC issues already caused kube-vip breakage.
- **Alternatives considered**: Warning-only validation or production-only enforcement. Rejected because they allow known-bad bindings to ship.

## Decision 6: Treat kube-vip-cloud-provider as the source of LB address allocation
- **Decision**: Preserve the current kube-vip-cloud-provider-based address allocation flow and update its configuration for the DHCP and load-balancer requirements.
- **Rationale**: The repo already uses the cloud controller to populate `kube-vip.io/loadbalancerIPs` and the `KUBEVIP_CIDR` pool. The upstream cloud-provider docs confirm the same contract.
- **Alternatives considered**: Direct service mutation from a new controller or custom allocator. Rejected because the existing cloud-provider already matches kube-vip semantics.

## Evidence Notes
- Repo evidence: `ansible/roles/kube-vip/defaults/main.yml`, `ansible/roles/kube-vip/README.md`, `ansible/roles/kube-vip/templates/kube-vip-daemonset.yaml.j2`, `ansible/roles/kube-vip/templates/kube-vip-cloud-controller.yaml.j2`, `ansible/playbooks/cluster-core.yml`, `ansible/playbooks/cluster-addons.yml`.
- Upstream evidence: kube-vip egress docs, kube-vip service docs, kube-vip-cloud-provider docs.
- Confirmed behavior: service election for ARP LoadBalancer mode, DHCP sentinel `0.0.0.0`, and cloud-provider address allocation via annotations / configmap.
