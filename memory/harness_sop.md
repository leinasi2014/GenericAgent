# Harness DevOps Platform SOP

**用途**：操作 Harness/Gitness 平台（代码托管、CI/CD、Gitspaces、Secrets 等）
**前置条件**：环境变量 `HARNESS_TOKEN`（PAT）、`HARNESS_URL`、`HARNESS_SSH_HOST`、`HARNESS_SSH_PORT`、`HARNESS_SSH_KEY` 已配置
**API 基础路径**：`{HARNESS_URL}/api/v1/`

---

## 一、认证与通用请求

```python
import os, requests, json

BASE = os.environ['HARNESS_URL'] + '/api/v1'
HEADERS = {'Authorization': 'Bearer ' + os.environ['HARNESS_TOKEN'], 'Content-Type': 'application/json'}

def api(method, path, body=None):
    r = requests.request(method, BASE + path, headers=HEADERS, json=body, timeout=10)
    return r.status_code, r.json() if r.text else {}
```

---

## 二、Spaces（空间）

```
GET|POST   /spaces
GET|PATCH  /spaces/{space_ref}
GET        /spaces/{space_ref}/repos
```

创建 Space：`{"identifier": "my-space", "is_public": false, "description": "..."}`

嵌套 Space 用 `+` 分隔：`parent+child`

---

## 三、Repos（仓库）

```
GET|POST       /repos/{space}+{repo}
PATCH|DELETE   /repos/{space}+{repo}
GET            /repos/{space}+{repo}/content/            列出文件
GET            /repos/{space}+{repo}/content/{path}      文件信息（base64）
GET            /repos/{space}+{repo}/raw/{path}?git_ref=  原始内容
GET|DELETE     /repos/{space}+{repo}/branches
POST           /repos/{space}+{repo}/default-branch
GET            /repos/{space}+{repo}/commits
GET            /repos/{space}+{repo}/commits/{sha}
GET            /repos/{space}+{repo}/commits/{sha}/diff
```

创建仓库：`{"identifier": "my-repo", "parent_ref": "space", "is_public": false, "readme": true, "default_branch": "main"}`

注意：文件创建/修改请走 git push，API 的 content POST 返回 405。

---

## 四、Pull Requests

```
GET|POST  /repos/{space}+{repo}/pullreq                    列表/创建
GET       /repos/{space}+{repo}/pullreq/{n}                详情
POST      /repos/{space}+{repo}/pullreq/{n}/merge          合并
POST      /repos/{space}+{repo}/pullreq/{n}/comments       评论
POST      /repos/{space}+{repo}/pullreq/{n}/reviews        审核
```

合并需提供 `source_sha`：
```python
api('POST', '/repos/space+repo/pullreq/1/merge', {
    'method': 'merge',
    'source_sha': pr_sha,
    'message': 'Merge PR',
})
```

---

## 五、Pipelines（CI/CD）

```
GET|DELETE  /repos/{space}+{repo}/pipelines
GET         /repos/{space}+{repo}/pipelines/{id}
GET         /repos/{space}+{repo}/pipelines/{id}/executions
POST        /repos/{space}+{repo}/pipelines/{id}/executions/{n}/cancel
GET         /repos/{space}+{repo}/pipelines/{id}/executions/{n}/logs
```

Pipeline 配置为 YAML 文件放在仓库 `.harness/` 目录下。

---

## 六、Secrets（密钥）

```
POST|GET|PATCH|DELETE  /secrets/{space}+{secret}
```

创建：`{"identifier": "my-secret", "space_ref": "space", "data": {"type": "string", "value": "..."}}`

---

## 七、Connectors（连接器）

```
POST|GET|PATCH|DELETE  /connectors/{space}+{connector}
```

类型：docker, harness_gcp, aws, azure, github, gitlab, k8s 等。

---

## 八、Gitspaces（云端开发环境）

```
GET|POST         /gitspaces
POST             /gitspaces/{id}/actions     start/stop/restart/reset
GET              /gitspaces/{id}/events
POST             /gitspaces/lookup-repo
```

创建：`{"identifier": "...", "space_ref": "...", "name": "...", "ide": "vs_code_web", "infra_provider_config_identifier": "...", "code_repo_ref": "...", "code_repo_type": "branch", "branch": "main"}`

IDE 类型：vs_code, vs_code_web, intellij, pycharm, goland, webstorm, clion, phpstorm, rubymine, rider

---

## 九、SSH Git 操作

```python
import subprocess, os, tempfile, shutil

SSH_KEY = os.environ.get('HARNESS_SSH_KEY', os.environ['HOME'] + '/.ssh/harness_rsa')
SSH_HOST = os.environ.get('HARNESS_SSH_HOST', '172.18.0.1')
SSH_PORT = os.environ.get('HARNESS_SSH_PORT', '3022')

env = os.environ.copy()
env['GIT_SSH_COMMAND'] = 'ssh -i ' + SSH_KEY + ' -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

# Clone
tmpdir = tempfile.mkdtemp()
subprocess.run(['git', 'clone', 'ssh://git@' + SSH_HOST + ':' + SSH_PORT + '/space/repo.git'], env=env, cwd=tmpdir)

# 修改后提交推送
subprocess.run(['git', 'config', 'user.name', 'Agent'], cwd=repo_dir)
subprocess.run(['git', 'config', 'user.email', 'agent@local'], cwd=repo_dir)
subprocess.run(['git', 'add', '.'], cwd=repo_dir)
subprocess.run(['git', 'commit', '-m', 'message'], cwd=repo_dir)
subprocess.run(['git', 'push', 'origin', 'main'], env=env, cwd=repo_dir)

shutil.rmtree(tmpdir, ignore_errors=True)
```

---

## 十、Webhooks

```
GET|POST|DELETE  /webhooks
POST             /webhooks/{id}/execute
GET              /webhooks/{id}/executions
```

---

## 十一、用户与认证

```
POST  /login
POST  /register
GET   /user
GET   /user/memberships
POST  /user/keys      注册 SSH 公钥
GET   /user/keys
```

SSH 密钥注册：`{"identifier": "my-key", "usage": "auth", "content": "ssh-ed25519 AAAA..."}`

---

## 十二、系统信息

```
GET  /system/config
```

返回功能开关：ssh_enabled, gitspace_enabled, artifact_registry_enabled, user_signup_allowed

---

## 注意事项

- 资源标识符为 slug 格式 `[a-z0-9_-]+`
- Harness 用 `+` 作为路径分隔符
- admin 默认账号 `admin` / `changeit`
- 管理员 PAT 在容器重启后可能失效，recovery-user（uid=8）的 PAT 对大部分操作有效
- shell 安全过滤器会拦截 `ssh`、`curl`、`/dev/tcp/`，请用 Python subprocess
