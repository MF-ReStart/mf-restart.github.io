# 对象类资源格式

Kubernetes API 仅支持接受及响应 JSON 格式的数据（JSON 对象），同时，为了便于使用，它也允许用户提供 YAML 格式的 POST 对象，但 API Server 接受和返回的所有 JSON 对象都遵循同一个模式，它们都具有 kind 和 apiVersion 字段，用于表示对象所属的资源类型、API 群组及相关版本。

大多数的对象或列表类型的资源还需要具有三个嵌套型的字段 metadata、spec、status。其中 metadata 字段为资源提供元数据信息，如名称、资源隶属的名称空间和标签等。spec 则用于定义用户期望的状态，不同的资源类型，其状态的意义也各不相同。status 则记录着活动对象的当前状态信息，它由 Kubernetes 系统自行维护，对用户来说为只读状态。

Kubectl 的命令可以分为三类：陈述式命令（Imperative commands）、陈述式对象配置（Imperative object configuration）和声明式对象配置（Declarative object configuration）。

陈述式命令就是此前管理应用生命周期用到的 run、expose 和 delete 等命令，它们直接作用于 Kubernetes 系统上的活动对象，简单易用，但是不支持代码复用、修改复审及审计日志的功能。对于新手来说，更容易上手学习。

陈述式对象配置管理方式支持使用 create、delete、get 和 replace 等命令，与陈述式命令不同之处在于，它通过资源配置清单读取需要管理的目标资源对象。陈述式对象配置管理操作同样直接作用于 Kubernetes 系统上的活动对象，即便修改配置清单中极小的一部分内容，使用 replace 命令进行的对象更新也会导致整个对象被替换。

声明式对象配置并不直接指明要进行的对象管理操作，而是提供配置清单文件给 Kubernetes 系统，并委托系统跟踪活动对象的状态变动。资源对象的创建、删除及修改操作可全部通过唯一的 apply 命令来完成。并且每次操作时，提供给命令的配置信息都存放于对象的注解信息中，并通过比对检查活动对象的当前状态、注解中的配置信息及资源清单中的配置信息三方进行变更合并，从而实现仅修改变动字段的高级补丁机制。

##  资源配置清单

我们前面使用 Kubectl 管理应用生命周期，使用的是陈述式命令。下面我们将以资源配置清单的格式来创建活动对象。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ikubernetes-deployment
  labels:
    app: ikubernetes-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ikubernetes
  template:
    metadata:
      labels:
        app: ikubernetes
    spec:
      containers:
      - name: ikubernetes
        image: ikubernetes/myapp:v1
        ports:
        - containerPort: 80 
```

在该活动对象实例中：

- 创建名为 ikubernetes-deployment （由 `.metadata.name` 字段标明）的 Deployment。
- 该 Deployment 创建三个（由 `replicas` 字段标明） Pod 副本。
- `selector` 字段定义 Deployment 如何查找要管理的 Pods。这里只需选择在 Pod 模板中定义的标签（app: ikubernetes）。
- `template` 字段包含以下子字段：
  - Pod 被使用 `labels` 字段打上 app: ikubernetes 标签。
  - Pod 模板规约 （即 .`template.spec` 字段）指示 Pods 运行一个 ikubernetes 容器，并指定容器运行版本的镜像。

Kubernetes API 标准的资源组织格式由五个核心字段组成：

- apiVersion: 定义这个资源使用的 API 版本。
- kind: 定义这个资源的类型。
- metadata: 资源的元数据。
- spec: 资源的规约，描述所期望的对象应有的状态。
- status: 记录对象在系统上的当前状态。

在编写资源配置清单时如果对资源的字段不确定，可以使用 Kubernetes 内置的 explain 命令列出受支持资源的字段：

```bash
# 获取资源及其字段的文档
kubectl explain pods

# 获取资源的特定字段
kubectl explain pods.spec.containers
```
