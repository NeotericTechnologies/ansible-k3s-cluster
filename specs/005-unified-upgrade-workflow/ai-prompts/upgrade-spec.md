The goal of this pass is to refactor the scope and experience of the upgrade process.

Currently, upgrades require conscious effort, a carefully managed set of steps, and a completely different workflow.  If done incorrectly or out of order the upgrade can fail and the state of the cluster can be left in an inconsistent and possibly inoperable state.

For example:

Deploying and configuring the cluster initially is a simple two step process, though it would be nice if this was a single step process:
```bash
# Deploy k3s core cluster (control-plane + workers + kube-vip)
ansible-playbook -i ansible/inventories/production ansible/playbooks/cluster-core.yml

# Deploy optional platform add-ons
ansible-playbook -i ansible/inventories/production ansible/playbooks/cluster-addons.yml
```

Upgrading the cluster requires a completely different workflow which includes the upgrade-k3s playbook when installing a new version of k3s:
```bash
ansible-playbook -i ansible/inventories/production ansible/playbooks/upgrade-k3s.yml
```
Further, the upgrade-k3s playbook is specific to upgrading k3s on all the nodes.

It is more likely for a k3s upgrade to be triggered by a new release of Rancher, since Rancher is the limiting factor in terms of compatibility.

As it stands such an upgrade would require a carefully managed set of steps in order to be successful:
- The version of Rancher would need to be updated first using the cluster-addons playbook.
- The version of k3s would then need to upgraded separately, to the most recent compatible version using the upgrade-k3s playbook.
- Then any additional updates to other components would need to be applied using a combination of the cluster-core and cluster-addons playbooks.

This process requires an in-depth understanding of the scripts as well as the dependencies between different components and the version of k3s being installed.

Goals:
- Abstract the installation and upgrade process so the same user level workflow can be used for both installation and upgrade.
  - A single top level playbook that can handle both installation and upgrades.
- Support upgrading Rancher and k3s together.
- Allow the user to define what they want to upgrade, and have the scripts figure out:
  - What is being upgraded vs what is not.
  - Only affect the components being upgraded.
  - Determine the order of operations based on dependencies.
