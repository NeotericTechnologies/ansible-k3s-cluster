# Data Model: Kube-VIP Egress and HA Hardening

## 1. KubeVIPRoleConfig
Represents the kube-vip deployment settings rendered by the role.

### Fields
- `kube_vip_enabled`: enables or disables the role
- `kube_vip_version`: kube-vip image tag
- `kube_vip_cloud_provider_version`: cloud-provider image tag
- `kube_vip_interface`: control-plane / service interface name
- `kube_vip_lb_enable`: toggles LoadBalancer service support
- `kube_vip_lb_ip_range`: LB address pool or CIDR
- `control_plane_vip`: API virtual IP
- `api_port`: API port
- `svc_election_enabled`: derived service-election mode for LB services
- `egress_enabled`: derived environment-wide egress mode
- `dhcp_enabled`: derived environment-wide DHCP mode
- `rbac_gate_enabled`: derived RBAC hard-fail gate

### Relationships
- Consumed by `kube-vip` role templates.
- Drives both control-plane and LoadBalancer manifests.

## 2. KubeVIPServicePolicy
Represents behavior for a managed LoadBalancer service.

### Fields
- `namespace`
- `name`
- `loadBalancerClass`
- `loadBalancerIP`
- `externalTrafficPolicy`
- `egress_annotations`
- `dhcp_mode`
- `opt_out_annotations`
- `service_election_required`

### Relationships
- Must be compatible with the environment-level `KubeVIPRoleConfig`.
- Can be validated against RBAC and deployment rules.

## 3. RBACCapabilitySet
Represents the permissions kube-vip needs to operate.

### Fields
- `service_account`
- `cluster_role`
- `cluster_role_binding`
- `allowed_resources`
- `allowed_verbs`
- `validation_status`

### Relationships
- Used by the deployment gate.
- Must cover services, services/status, endpoints, endpointslices, nodes, configmaps, leases, and events as required by the current manifests and upstream behavior.

## 4. DeploymentVerificationRecord
Captures validation outcomes for a change or rollout.

### Fields
- `cluster_name`
- `feature_flags_checked`
- `egress_validation_result`
- `service_election_validation_result`
- `dhcp_validation_result`
- `rbac_validation_result`
- `timestamp`
- `operator`

### Relationships
- Produced by quickstart validation steps.
- Serves as evidence for the constitution traceability principle.

## State Notes
- `dhcp_enabled` is cluster-wide when enabled.
- `egress_enabled` defaults on and can be opted out per workload or namespace.
- RBAC validation is fail-fast for production rollout.
