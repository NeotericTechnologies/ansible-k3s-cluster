# Contributing to k3s Ansible Baseline

Thank you for considering contributing to this project! This document provides guidelines for contributions.

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Follow community best practices

## How to Contribute

### Reporting Issues

When reporting issues, please include:

1. **Environment details:**
   - OS version (Debian 11, Ubuntu 22.04, etc.)
   - Ansible version
   - k3s version
   - Python version

2. **Steps to reproduce:**
   - Complete inventory configuration (sanitized)
   - Exact command run
   - Expected vs actual behavior

3. **Logs and output:**
   - Ansible playbook output
   - Relevant journalctl logs
   - kubectl describe output if applicable

### Submitting Pull Requests

1. **Fork the repository**
   ```bash
   git clone https://github.com/your-username/ansible-k3s-cluster.git
   cd ansible-k3s-cluster
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Follow code standards (see below)
   - Add tests for new functionality
   - Update documentation

3. **Test your changes**
   ```bash
   # Lint playbooks
   cd ansible/
   ansible-lint playbooks/*.yml roles/*/tasks/*.yml
   
   # Run smoke tests
   ansible-playbook -i tests/ansible/inventories/local tests/ansible/smoke/smoke.yml
   
   # Test idempotence
   ansible-playbook -i tests/ansible/inventories/local tests/ansible/smoke/idempotence-test.yml
   ```

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: Add feature description"
   
   # Use conventional commits:
   # feat: New feature
   # fix: Bug fix
   # docs: Documentation changes
   # refactor: Code refactoring
   # test: Test additions/changes
   # chore: Maintenance tasks
   ```

5. **Push and create PR**
   ```bash
   git push origin feature/your-feature-name
   ```

## Code Standards

### Ansible Best Practices

**1. Use Fully Qualified Collection Names (FQCN):**
```yaml
# Good
- name: Install package
  ansible.builtin.apt:
    name: curl
    state: present

# Bad
- name: Install package
  apt:
    name: curl
    state: present
```

**2. Follow idempotent patterns:**
```yaml
# Good
- name: Check if file exists
  ansible.builtin.stat:
    path: /path/to/file
  register: file_status

- name: Create file if missing
  ansible.builtin.copy:
    content: "data"
    dest: /path/to/file
  when: not file_status.stat.exists

# Bad
- name: Always create file
  ansible.builtin.shell: echo "data" > /path/to/file
```

**3. Add changed_when guards to command/shell tasks:**
```yaml
# Good
- name: Check k3s version
  ansible.builtin.command:
    cmd: k3s --version
  register: k3s_version
  changed_when: false

# Bad
- name: Check k3s version
  ansible.builtin.command:
    cmd: k3s --version
  register: k3s_version
```

**4. Use descriptive task names:**
```yaml
# Good
- name: Install k3s control-plane with embedded etcd
  ansible.builtin.shell: ...

# Bad
- name: Install k3s
  ansible.builtin.shell: ...
```

**5. Document complex logic:**
```yaml
- name: Calculate control-plane nodes after removal
  ansible.builtin.set_fact:
    # Subtract removing_servers count from current count
    # This ensures we maintain quorum (minimum 1, prefer odd numbers)
    servers_after_removal: "{{ (current_servers.stdout_lines | length) - (removing_servers | length) }}"
```

**6. Use handlers for service restarts:**
```yaml
# tasks/main.yml
- name: Update k3s configuration
  ansible.builtin.template:
    src: k3s.service.j2
    dest: /etc/systemd/system/k3s.service
  notify: Restart k3s

# handlers/main.yml
- name: Restart k3s
  ansible.builtin.systemd:
    name: k3s
    state: restarted
    daemon_reload: yes
```

### File Organization

**Role structure:**
```
roles/
  role-name/
    tasks/
      main.yml         # Entry point
      install.yml      # Installation tasks
      configure.yml    # Configuration tasks
    templates/
      config.yaml.j2   # Jinja2 templates
    defaults/
      main.yml         # Default variables
    handlers/
      main.yml         # Service handlers
    README.md          # Role documentation
```

**Playbook structure:**
```
playbooks/
  cluster-core.yml     # Core provisioning
  cluster-addons.yml   # Optional add-ons
  scale-nodes.yml      # Scaling operations
  upgrade-k3s.yml      # Version upgrades
```

### Security Best Practices

**1. Never commit secrets:**
```yaml
# Good - Use Ansible Vault
vault_api_token: "secret_value"

# Reference in playbooks
api_token: "{{ vault_api_token }}"

# Bad - Plain text secrets
api_token: "my_secret_token_123"
```

**2. Use sudo carefully:**
```yaml
# Good - Explicit become
- name: Install package
  ansible.builtin.apt:
    name: curl
    state: present
  become: yes

# Bad - Global become for all tasks
```

**3. Validate inputs:**
```yaml
- name: Verify required variables are defined
  ansible.builtin.assert:
    that:
      - k3s_version is defined
      - control_plane_vip is defined
    fail_msg: "Required variables missing"
```

## Testing Requirements

### Pre-Submission Checklist

- [ ] Code passes ansible-lint without errors
- [ ] All smoke tests pass
- [ ] Idempotence test shows no changes on second run
- [ ] Tested on Debian 11 or Ubuntu 22.04
- [ ] Documentation updated (if applicable)
- [ ] No secrets or sensitive data in code
- [ ] Commit messages follow conventional commits
- [ ] PR description explains changes clearly

### Test Coverage

**For new roles:**
- Add role-specific smoke tests
- Document usage in role README.md
- Include example variable configurations

**For new playbooks:**
- Add smoke test scenarios
- Document in docs/ansible-k3s-baseline.md
- Include usage examples

**For bug fixes:**
- Add regression test if possible
- Document the issue and solution
- Update troubleshooting guide if relevant

## Pull Request Template

When submitting a PR, use this template:

```markdown
## Description
Brief description of what this PR does and why.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation update

## Testing
- [ ] ansible-lint passed
- [ ] smoke.yml passed
- [ ] idempotence-test.yml passed
- [ ] Tested on Debian 11
- [ ] Tested on Ubuntu 22.04

## Checklist
- [ ] FQCN modules used throughout
- [ ] Idempotent execution verified
- [ ] Documentation updated
- [ ] No secrets in code
- [ ] Commit messages follow conventional commits
- [ ] Tests added for new functionality

## Related Issues
Closes #123
```

## Development Workflow

### Local Testing

1. **Set up test environment:**
   ```bash
   # Use VMs or containers for testing
   vagrant up  # if using Vagrant
   # or
   docker-compose up  # if using containers
   ```

2. **Run playbooks in check mode:**
   ```bash
   ansible-playbook -i inventory playbooks/cluster-core.yml --check
   ```

3. **Test on fresh cluster:**
   - Always test on a clean environment
   - Verify idempotence (run twice, second run should show minimal changes)
   - Test failure scenarios

### Documentation

**Update documentation when:**
- Adding new features
- Changing existing behavior
- Adding new variables
- Fixing bugs that users might encounter

**Documentation locations:**
- `README.md` - Project overview and quick start
- `docs/ansible-k3s-baseline.md` - Comprehensive guide
- `docs/ansible-structure.md` - Project structure
- Role `README.md` files - Role-specific docs

## Release Process

1. **Version Bumping:**
   - Follow Semantic Versioning (MAJOR.MINOR.PATCH)
   - Update version in docs/ansible-k3s-baseline.md

2. **Changelog:**
   - Update CHANGELOG.md with changes
   - Group by: Added, Changed, Fixed, Removed

3. **Testing:**
   - Full integration test on supported OS versions
   - All smoke tests must pass

4. **Tagging:**
   ```bash
   git tag -a v1.1.0 -m "Release v1.1.0"
   git push origin v1.1.0
   ```

## Getting Help

- **Issues:** Use GitHub Issues for bugs and feature requests
- **Discussions:** Use GitHub Discussions for questions
- **Documentation:** Check docs/ directory first

## Code Review Guidelines

Reviewers should check for:

- [ ] Code follows style guidelines
- [ ] Tests are included and passing
- [ ] Documentation is updated
- [ ] No security issues (secrets, unsafe commands)
- [ ] Changes are backwards compatible (or clearly documented)
- [ ] Commit messages are clear and follow conventions

## License

By contributing, you agree that your contributions will be licensed under the project's MIT License.

---

Thank you for contributing to k3s Ansible Baseline!
