# 配置

此模块整合了 Kubernetes 所有资源的配置。

## 配置最佳实践

https://kubernetes.io/zh/docs/concepts/configuration/overview/

## ConfigMap

ConfigMap 是一种 API 对象，用来将非机密性的数据保存到键值对中。使用时， [Pods](https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/) 可以将其用作环境变量、命令行参数或者存储卷中的配置文件。

ConfigMap 将您的环境配置信息和 [容器镜像](https://kubernetes.io/zh/docs/reference/glossary/?all=true#term-image) 解耦，便于应用配置的修改。

> 注意：ConfigMap 并不提供保密或者加密功能。 如果你想存储的数据是机密的，请使用 [Secret](https://kubernetes.io/zh/docs/concepts/configuration/secret/)， 或者使用其他第三方工具来保证你的数据的私密性，而不是用 ConfigMap。

### 动机

使用 ConfigMap 来将你的配置数据和应用程序代码分开。

比如，假设你正在开发一个应用，它可以在你自己的电脑上（用于开发）和在云上 （用于实际流量）运行。 你的代码里有一段是用于查看环境变量 `DATABASE_HOST`，在本地运行时， 你将这个变量设置为 `localhost`，在云上，你将其设置为引用 Kubernetes 集群中的公开数据库组件的 [服务](https://kubernetes.io/zh/docs/concepts/services-networking/service/)。

这让你可以获取在云中运行的容器镜像，并且如果有需要的话，在本地调试完全相同的代码。

ConfigMap 在设计上不是用来保存大量数据的。在 ConfigMap 中保存的数据不可超过 1 MiB。如果你需要保存超出此尺寸限制的数据，你可能希望考虑挂载存储卷或者使用独立的数据库或者文件服务。

### ConfigMap 对象

ConfigMap 是一个 API [对象](https://kubernetes.io/zh/docs/concepts/overview/working-with-objects/kubernetes-objects/)， 让你可以存储其他对象所需要使用的配置。 和其他 Kubernetes 对象都有一个 `spec` ，不同的是，ConfigMap 使用 `data` 和 `binaryData` 字段。这些字段能够接收键-值对作为其取值。`data` 和 `binaryData` 字段都是可选的。`data` 字段设计用来保存 UTF-8 字节序列，而 `binaryData` 则被设计用来保存二进制数据作为 base64 编码的字串。

ConfigMap 的名字必须是一个合法的 [DNS 子域名](https://kubernetes.io/zh/docs/concepts/overview/working-with-objects/names#dns-subdomain-names)。

`data` 或 `binaryData` 字段下面的每个键的名称都必须由字母数字字符或者 `-`、`_` 或 `.` 组成。在 `data` 下保存的键名不可以与在 `binaryData` 下出现的键名有重叠。

从 v1.19 开始，你可以添加一个 `immutable` 字段到 ConfigMap 定义中，创建 [不可变更的 ConfigMap](https://kubernetes.io/zh/docs/concepts/configuration/configmap/#configmap-immutable)。

### ConfigMaps 和 Pods

你可以写一个引用 ConfigMap 的 Pod 的 `spec`，并根据 ConfigMap 中的数据在该 Pod 中配置容器。这个 Pod 和 ConfigMap 必须要在同一个 [名字空间](https://kubernetes.io/zh/docs/concepts/overview/working-with-objects/namespaces/) 中。

这是一个 ConfigMap 的示例，它的一些键只有一个值，其他键的值看起来像是配置的片段格式。

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: configmap-demo
data:
  # 类属性键:每一个键都映射到一个简单的值
  nginx_server_port: "80"
  nginx_server_host: "www.missf.top"
  
  # 类文件键
  nginx.config: |
    location / {
        root /usr/local/nginx/html/;
        index index.html;
    }
```

你可以使用四种方式来使用 ConfigMap 配置 Pod 中的容器：

1. 在容器命令和参数内。
2. 容器的环境变量。
3. 在只读卷里面添加一个文件，让应用来读取。
4. 编写代码在 Pod 中运行，使用 Kubernetes API 来读取 ConfigMap。

这些不同的方法适用于不同的数据使用方式。 对前三个方法，[kubelet](https://kubernetes.io/docs/reference/generated/kubelet) 使用 ConfigMap 中的数据在 Pod 中启动容器。

第四种方法意味着你必须编写代码才能读取 ConfigMap 和它的数据。然而， 由于你是直接使用 Kubernetes API，因此只要 ConfigMap 发生更改，你的应用就能够通过订阅来获取更新，并且在这样的情况发生的时候做出反应。 通过直接进入 Kubernetes API，这个技术也可以让你能够获取到不同的名字空间里的 ConfigMap。

下面是一个 Pod 的示例，它通过使用 `configmap-demo` 中的值来配置一个 Pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: configmap-pod
  labels:
    app: configmap
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
    env:
      - name: NGINX_SERVER_PORT
        valueFrom:
          configMapKeyRef:
            name: configmap-demo
            key: nginx_server_port
      - name: NGINX_SERVER_HOST
        valueFrom:
          configMapKeyRef:
            name: configmap-demo
            key: nginx_server_host
    volumeMounts:
    - name: config
      mountPath: "/config"
      readOnly: true
  volumes:
    - name: config
      configMap:
        name: configmap-demo
        items:
        - key: "nginx.config"
          path: "nginx.config"
```

ConfigMap 不会区分单行属性值和多行类似文件的值，重要的是 Pods 和其他对象如何使用这些值。（能否自动更新也是看 Pods 如何去使用 ConfigMap）。

上面的例子定义了一个卷并将它作为 `/config` 文件夹挂载到 `demo` 容器内， 创建一个文件，`/config/nginx.config`。

### 使用 ConfigMap

ConfigMap 可以作为数据卷挂载。ConfigMap 也可被系统的其他组件使用，而不一定直接暴露给 Pod。例如，ConfigMap 可以保存系统中其他组件要使用的配置数据。

ConfigMap 最常见的用法是为同一命名空间里某 Pod 中运行的容器执行配置。 你也可以单独使用 ConfigMap。

比如，你可能会遇到基于 ConfigMap 来调整其行为的 [插件](https://kubernetes.io/zh/docs/concepts/cluster-administration/addons/) 或者 [operator](https://kubernetes.io/zh/docs/concepts/extend-kubernetes/operator/)。

#### 在 Pod 中将 ConfigMap 当做文件使用

1. 创建一个 ConfigMap 对象或者使用现有的 ConfigMap 对象。多个 Pod 可以引用同一个 ConfigMap。
2. 修改 Pod 定义，在 `spec.volumes[]` 下添加一个卷。 为该卷设置任意名称，之后将 `spec.volumes[].configMap.name` 字段设置为对你的 ConfigMap 对象的引用。
3. 为每个需要该 ConfigMap 的容器添加一个 `.spec.containers[].volumeMounts[]`。 设置 `.spec.containers[].volumeMounts[].readOnly=true` 并将 `.spec.containers[].volumeMounts[].mountPath` 设置为一个未使用的目录名， ConfigMap 的内容将出现在该目录中。
4. 更改你的镜像或者命令行，以便程序能够从该目录中查找文件。ConfigMap 中的每个 `data` 键会变成 `mountPath` 下面的一个文件名。

下面是一个将 ConfigMap 以卷的形式进行挂载的 Pod 示例：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mypod
spec:
  containers:
  - name: mypod
    image: redis
    volumeMounts:
    - name: foo
      mountPath: "/etc/foo"
      readOnly: true
  volumes:
  - name: foo
    configMap:
      name: myconfigmap
```

你希望使用的每个 ConfigMap 都需要在 `spec.volumes` 中被引用到。

如果 Pod 中有多个容器，则每个容器都需要自己的 `volumeMounts` 块，但针对每个 ConfigMap，你只需要设置一个 `spec.volumes` 块。

#### 被挂载的 ConfigMap 内容会被自动更新

当卷中使用的 ConfigMap 被更新时，所投射的键最终也会被更新。 kubelet 组件会在每次周期性同步时检查所挂载的 ConfigMap 是否为最新。 不过，kubelet 使用的是其本地的高速缓存来获得 ConfigMap 的当前值。 高速缓存的类型可以通过 [KubeletConfiguration 结构](https://github.com/kubernetes/kubernetes/blob/master/staging/src/k8s.io/kubelet/config/v1beta1/types.go) 的 `ConfigMapAndSecretChangeDetectionStrategy` 字段来配置。

ConfigMap 既可以通过 watch 操作实现内容传播（默认形式），也可实现基于 TTL 的缓存，还可以直接经过所有请求重定向到 API 服务器。 因此，从 ConfigMap 被更新的那一刻算起，到新的主键被投射到 Pod 中去，这一 时间跨度可能与 kubelet 的同步周期加上高速缓存的传播延迟相等。 这里的传播延迟取决于所选的高速缓存类型 （分别对应 watch 操作的传播延迟、高速缓存的 TTL 时长或者 0）。

以环境变量方式使用的 ConfigMap 数据不会被自动更新。 更新这些数据需要重新启动 Pod。

### 不可变更的 ConfigMap

Kubernetes 不可变更的 Secret 和 ConfigMap 提供了一种将各个 Secret 和 ConfigMap 设置为不可变更的选项。对于大量使用 ConfigMap 的集群（至少有数万个各不相同的 ConfigMap 给 Pod 挂载）而言，禁止更改 ConfigMap 的数据有以下好处：

- 保护应用，使之免受意外（不想要的）更新所带来的负面影响。
- 通过大幅降低对 kube-apiserver 的压力提升集群性能，这是因为系统会关闭对已标记为不可变更的 ConfigMap 的监视操作。

此功能特性由 `ImmutableEphemeralVolumes` [特性门控](https://kubernetes.io/zh/docs/reference/command-line-tools-reference/feature-gates/) 来控制。你可以通过将 `immutable` 字段设置为 `true` 创建不可变更的 ConfigMap。 例如：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  ...
data:
  ...
immutable: true
```

一旦某 ConfigMap 被标记为不可变更，则无法逆转这一变化，也无法更改 `data` 或 `binaryData` 字段的内容。你只能删除并重建 ConfigMap。 因为现有的 Pod 会维护一个对已删除的 ConfigMap 的挂载点，建议重新创建这些 Pods。

## Secret

`Secret` 对象类型用来保存敏感信息，例如密码、OAuth 令牌和 SSH 密钥。 将这些信息放在 `secret` 中比放在 [Pod](https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/) 的定义或者 [容器镜像](https://kubernetes.io/zh/docs/reference/glossary/?all=true#term-image) 中来说更加安全和灵活。 参阅 [Secret 设计文档](https://git.k8s.io/community/contributors/design-proposals/auth/secrets.md) 获取更多详细信息。

Secret 是一种包含少量敏感信息例如密码、令牌或密钥的对象。 这样的信息可能会被放在 Pod 规约中或者镜像中。 用户可以创建 Secret，同时系统也创建了一些 Secret。

**注意：**Kubernetes Secret 默认情况下存储为 base64-编码的、非加密的字符串。 默认情况下，能够访问 API 的任何人，或者能够访问 Kubernetes 下层数据存储（etcd） 的任何人都可以以明文形式读取这些数据。 为了能够安全地使用 Secret，我们建议你（至少）：

1. 为 Secret [启用静态加密](https://kubernetes.io/zh/docs/tasks/administer-cluster/encrypt-data/)；
2. [启用或配置 RBAC 规则](https://kubernetes.io/zh/docs/reference/access-authn-authz/authorization/)来限制对 Secret 的读写操作。 要注意，任何被允许创建 Pod 的人都默认地具有读取 Secret 的权限。

### Secret 概览

要使用 Secret，Pod 需要引用 Secret。 Pod 可以用三种方式之一来使用 Secret:

- 作为挂载到一个或多个容器上的 [卷](https://kubernetes.io/zh/docs/concepts/storage/volumes/) 中的[文件](https://kubernetes.io/zh/docs/concepts/configuration/secret/#using-secrets-as-files-from-a-pod)。
- 作为[容器的环境变量](https://kubernetes.io/zh/docs/concepts/configuration/secret/#using-secrets-as-environment-variables)
- 由 [kubelet 在为 Pod 拉取镜像时使用](https://kubernetes.io/zh/docs/concepts/configuration/secret/#using-imagepullsecrets)

Secret 对象的名称必须是合法的 [DNS 子域名](https://kubernetes.io/zh/docs/concepts/overview/working-with-objects/names#dns-subdomain-names)。 在为创建 Secret 编写配置文件时，你可以设置 `data` 与/或 `stringData` 字段。 `data` 和 `stringData` 字段都是可选的。`data` 字段中所有键值都必须是 base64 编码的字符串。如果不希望执行这种 base64 字符串的转换操作，你可以选择设置 `stringData` 字段，其中可以使用任何字符串作为其取值。

### Secret 的类型

在创建 Secret 对象时，你可以使用 [`Secret`](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.21/#secret-v1-core) 资源的 `type` 字段，或者与其等价的 `kubectl` 命令行参数（如果有的话）为其设置类型。 Secret 的类型用来帮助编写程序处理 Secret 数据。

Kubernetes 提供若干种内置的类型，用于一些常见的使用场景。 针对这些类型，Kubernetes 所执行的合法性检查操作以及对其所实施的限制各不相同。

| 内置类型                              | 用法                                     |
| ------------------------------------- | ---------------------------------------- |
| `Opaque`                              | 用户定义的任意数据                       |
| `kubernetes.io/service-account-token` | 服务账号令牌                             |
| `kubernetes.io/dockercfg`             | `~/.dockercfg` 文件的序列化形式          |
| `kubernetes.io/dockerconfigjson`      | `~/.docker/config.json` 文件的序列化形式 |
| `kubernetes.io/basic-auth`            | 用于基本身份认证的凭据                   |
| `kubernetes.io/ssh-auth`              | 用于 SSH 身份认证的凭据                  |
| `kubernetes.io/tls`                   | 用于 TLS 客户端或者服务器端的数据        |
| `bootstrap.kubernetes.io/token`       | 启动引导令牌数据                         |

通过为 Secret 对象的 `type` 字段设置一个非空的字符串值，你也可以定义并使用自己 Secret 类型。如果 `type` 值为空字符串，则被视为 `Opaque` 类型。 Kubernetes 并不对类型的名称作任何限制。不过，如果你要使用内置类型之一， 则你必须满足为该类型所定义的所有要求。

### 创建 Secret

有几种不同的方式来创建 Secret:

[使用 `kubectl` 命令创建 Secret](https://kubernetes.io/zh/docs/tasks/configmap-secret/managing-secret-using-kubectl/)

一个 `Secret` 可以包含 Pod 访问数据库所需的用户凭证。 例如，由用户名和密码组成的数据库连接字符串。 你可以在本地计算机上，将用户名存储在文件 `./username.txt` 中，将密码存储在文件 `./password.txt` 中。

```bash
echo -n 'admin' > ./username.txt
echo -n 'Er34ff5ghoo' > ./password.txt
```

在这些命令中，`-n` 标志确保生成的文件在文本末尾不包含额外的换行符。 这一点很重要，因为当 `kubectl` 读取文件并将内容编码为 base64 字符串时，多余的换行符也会被编码。

`kubectl create secret` 命令将这些文件打包成一个 Secret 并在 API 服务器上创建对象。

```bash
kubectl create secret generic db-user-pass --from-file=user=username.txt --from-file=pass=password.txt
```

输出类似于：

```bash
secret/db-user-pass created
```

默认密钥名称是文件名。 你可以选择使用 `--from-file=[key=]source` 来设置密钥名称。例如：

```bash
kubectl create secret generic db-user-pass \
  --from-file=username=./username.txt \
  --from-file=password=./password.txt
```

检查 secret 是否已创建：

```bash
kubectl get secrets
```

你可以查看 `Secret` 的描述：

```bash
kubectl describe secrets/db-user-pass
```

要查看创建的 Secret 的内容，运行以下命令：

```bash
kubectl get secret db-user-pass -o jsonpath='{.data}'
```

输出类似于：

```json
{"pass":"RXIzNGZmNWdob28=","user":"YWRtaW4="}
```

现在你可以解码 `pass` 的数据：

```bash
echo "RXIzNGZmNWdob28=" | base64 --decode
```

输出类似于：

```bash
Er34ff5ghoo
```

[使用配置文件来创建 Secret](https://kubernetes.io/zh/docs/tasks/configmap-secret/managing-secret-using-config-file/)

你可以先用 JSON 或 YAML 格式在文件中创建 Secret，然后创建该对象。 [Secret](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.21/#secret-v1-core) 资源包含2个键值对： `data` 和 `stringData`。 `data` 字段用来存储 base64 编码的任意数据。 提供 `stringData` 字段是为了方便，它允许 Secret 使用未编码的字符串。 `data` 和 `stringData` 的键必须由字母、数字、`-`，`_` 或 `.` 组成。

例如，要使用 Secret 的 `data` 字段存储两个字符串，请将字符串转换为 base64 ，如下所示：

```bash
echo -n 'admin' | base64
echo -n 'Er34ff5ghoo' | base64
```

输出类似于：

```bash
YWRtaW4=
RXIzNGZmNWdob28=
```

编写一个 Secret 配置文件，如下所示：

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  username: YWRtaW4=
  password: RXIzNGZmNWdob28=
```

对于某些场景，你可能希望使用 `stringData` 字段。 这字段可以将一个非 base64 编码的字符串直接放入 Secret 中， 当创建或更新该 Secret 时，此字段将被编码。

例如，如果你的应用程序使用以下配置文件：

```yaml
apiUrl: "https://my.api.com/api/v1"
username: "<user>"
password: "<password>"
```

你可以使用以下定义将其存储在 Secret 中：

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
stringData:
  config.yaml: |
    apiUrl: "https://my.api.com/api/v1"
    username: <user>
    password: <password>
```

[使用 kustomize 来创建 Secret](https://kubernetes.io/zh/docs/tasks/configmap-secret/managing-secret-using-kustomize/)

你可以在 `kustomization.yaml` 中定义 `secreteGenerator`，并在定义中引用其他现成的文件，生成 Secret。 例如：下面的 kustomization 文件 引用了 `./username.txt` 和 `./password.txt` 文件：

```yaml
secretGenerator:
- name: db-user-pass
  files:
  - username.txt
  - password.txt
```

你也可以在 `kustomization.yaml` 文件中指定一些字面量定义 `secretGenerator`。 例如：下面的 `kustomization.yaml` 文件中包含了 `username` 和 `password` 两个字面量：

```yaml
secretGenerator:
- name: db-user-pass
  literals:
  - username=admin
  - password=1f2d1e2e67df
```

注意，上面两种情况，你都不需要使用 base64 编码。

使用 `kubectl apply` 命令应用包含 `kustomization.yaml` 文件的目录创建 Secret。

```bash
kubectl apply -k .
```

### 编辑 Secret

你可以通过下面的命令编辑现有的 Secret:

```bash
kubectl edit secrets mysecret
```

### 使用 Secret

Secret 可以作为数据卷被挂载，或作为 [环境变量](https://kubernetes.io/zh/docs/concepts/containers/container-environment/) 暴露出来以供 Pod 中的容器使用。它们也可以被系统的其他部分使用，而不直接暴露在 Pod 内。 例如，它们可以保存凭据，系统的其他部分将用它来代表你与外部系统进行交互。

将 Secret 作为 Pod 中的[环境变量](https://kubernetes.io/zh/docs/concepts/containers/container-environment/)使用：

1. 创建一个 Secret 或者使用一个已存在的 Secret。多个 Pod 可以引用同一个 Secret。
2. 修改 Pod 定义，为每个要使用 Secret 的容器添加对应 Secret 键的环境变量。 使用 Secret 键的环境变量应在 `env[x].valueFrom.secretKeyRef` 中指定要包含的 Secret 名称和键名。
3. 更改镜像并／或者命令行，以便程序在指定的环境变量中查找值。

这是一个使用来自环境变量中的 Secret 值的 Pod 示例：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-env-pod
spec:
  containers:
  - name: nginx
    image: nginx
    env:
      - name: SECRET_USERNAME
        valueFrom:
          secretKeyRef:
            name: mysecret
            key: username
      - name: SECRET_PASSWORD
        valueFrom:       
          secretKeyRef:  
            name: mysecret
            key: password
  restartPolicy: Never
```

在 Pod 中使用存放在卷中的 Secret:

1. 创建一个 Secret 或者使用已有的 Secret。多个 Pod 可以引用同一个 Secret。
2. 修改你的 Pod 定义，在 `spec.volumes[]` 下增加一个卷。可以给这个卷随意命名， 它的 `spec.volumes[].secret.secretName` 必须是 Secret 对象的名字。
3. 将 `spec.containers[].volumeMounts[]` 加到需要用到该 Secret 的容器中。 指定 `spec.containers[].volumeMounts[].readOnly = true` 和 `spec.containers[].volumeMounts[].mountPath` 为你想要该 Secret 出现的尚未使用的目录。
4. 修改你的镜像并且／或者命令行，让程序从该目录下寻找文件。 Secret 的 `data` 映射中的每一个键都对应 `mountPath` 下的一个文件名。

这是一个在 Pod 中使用存放在挂载卷中 Secret 的例子：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-volume-pod
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: foo
      mountPath: "/etc/foo"
      readOnly: true
  volumes:
  - name: foo
    secret:
      secretName: mysecret
```

### 挂载的 Secret 会被自动更新

当已经存储于卷中被使用的 Secret 被更新时，被映射的键也将被更新。 组件 kubelet 在周期性同步时检查被挂载的 Secret 是不是最新的。 但是，它会使用其本地缓存的数值作为 Secret 的当前值。

