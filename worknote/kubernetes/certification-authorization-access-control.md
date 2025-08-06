# 认证、授权与准入控制

在任何将资源或服务提供给有限使用者的系统上，认证和授权是两个必不可少的功能，前者用于身份鉴别，负责验证“来者是谁”，而后者则实现权限分派，负责验证“他有权做什么事”。Kubernetes 系统完全分离了身份验证和授权功能，将二者分别以多种不同的插件实现，而且还有特有的准入控制机制，能在“写”请求上辅助完成更为精细的操作验证及变异功能。

## Kubernetes 访问控制

API Server 作为 Kubernetes 集群系统的网关，是访问及管理资源对象的唯一入口，它默认监听 TCP 的 6443 端口，通过 HTTPS 协议暴露了一个 RESTful 风格的接口。所有需要访问集群资源的集群组件或客户端，包括 kube-controller-manager、kube-scheduler、kubelet 和 kube-proxy 等集群基础组件，CoreDNS 等集群附加组件，以及 kubectl 命令等都必须要经过网关请求与集群通信。所有客户端均要经由 API Server 访问或改变集群状态以及完成数据存储，并且 API Server 会对每一次的访问请求进行合法检验，包括用户身份鉴别，操作权限验证以及操作是否符合全局规范的约束等。所有检查均正常完成且对象配置信息合法性检验无误后才能访问或存入数据到后端存储系统 ETCD 中。

![](https://hercules-gitbook-image.oss-cn-shenzhen.aliyuncs.com/gitbook/apiserver.png)

客户端认证操作由 API Server 配置的一到多个认证插件完成。收到请求后，API Server 依次调用配置的认证插件来校验客户端的身份，直到其中一个插件可以识别出请求者的身份为止。授权操作则由一到多个授权插件完成，这些插件负责确定通过认证的用户是否有权限执行发出的资源请求，该类操作包括创建、读取、删除或修改指定的对象等。随后通过授权检测的用户请求修改相关的操作还要经由一到多个准入控制插件的遍历式检测，例如使用默认值补足要创建的目标资源对象中未定义的各个字段、检查目标 Namespace 资源对象是否存在、检查请求创建的 Pod 对象是否违反系统资源限制等，其中的任何检查失败都可能导致写入操作失败。

### 用户账号与用户组

Kubernetes 系统上的用户账号及用户组的实现机制与常规应用略有不同。Kubernetes 集群将那些通过命令行工具 kubectl 、客户端库或者直接使用 RESTful 接口向 API Server 发起请求的客户端上的请求主体分为两个不同的类别：现实中的“人”和 Pod 对象，它们的用户身份分别对应用户账号（User Account，也称普通用户）和服务账号（Service Account，简称 SA）。

用户账户：其使用主体往往是“人”，一般由外部的用户管理系统存储和管理，Kubernetes 本身不维护这一类的任何用户账户信息，他们不会存储到 API Server 之上，仅仅用于检验用户是否有权限执行其所请求的操作。

服务账号：其使用主体是“应用程序”，专用于为 Pod 资源中的服务进程提供访问 Kubernetes API 时的身份标识（identity），Service Account 资源通常要绑定到特定的名称空间，它们由 API Server 自动创建或通过 API 调用，由管理员手动创建，通常附带着一组访问 API Server 的认证凭据 ------ Secret，可由同一名称空间的 Pod 应用访问 API Server 时使用。

用户账号通常是用于复杂的业务逻辑管控，作用于系统全局，因而名称必须全局唯一。Kubernetes 并不会存储由认证插件从客户端请求中提取的用户及所属的组信息，因而也就没有办法对普通用户进行身份认证，他们仅仅用于检验该操作主体是否有权限执行其所请求的操作。相比较来说，服务账号则隶属于名称空间级别，仅用于实现某些特定操作任务，因此功能上要轻量得多。这两类账号都可以隶属于一个或多个用户组。

对 API Server 来说，来自客户端的请求要么与用户账户进行绑定，要么以某个服务账户的身份进行，否则会被视为匿名请求。这意味着集群内部或外部的每个进程，包括由人类用户使用 kubectl，以及各节点上运行的 kubelet 进程，再到控制平面的成员组件，必须在向 API Server 发出请求时进行身份验证。

### 认证、授权、准入控制基础

Kubernetes 使用身份验证插件对 API Server 请求进行身份验证，它允许管理员自定义服务账号和用户账号要启用或禁用的插件，并支持各自同时启用多种认证机制。具体设定时，至少应该为服务账号和用户账号各自启用一个认证插件。

如果启用了多种认证机制，账号认证过程由认证插件以串行的方式进行，直到其中一种认证机制成功完成即结束。若认证失败，服务器则返回 401 状态码，反之，请求者就会被 Kubernetes 识别为某个具体的用户（以其用户名进行标识），并且该连接上随后的操作都会以此用户身份进行。API Server 对于接收到的每个访问请求会调用认证插件，尝试将以下属性与访问请求相关联。

- 用户名：用户名，例如 Kubernetes-admin 等。
- 用户 ID: 用户的数字标签符，用于确保用户身份的唯一性。
- 用户组：用户所属的组，用于权限指派和继承， 常见的值可能是 `system:masters` 或者 `devops-team` 等。
- 附加字段：键值数据类型的字符串，用于提供认证需要用到的额外信息。

API Server 支持以下几种具体的认证方式，其中所有的令牌认证机制通常被统称为“承载令牌认证”。

X509 客户证书认证：通过给 API 服务器传递 `--client-ca-file=SOMEFILE` 选项，就可以启动客户端证书身份认证。 所引用的文件必须包含一个或者多个证书机构，用来验证向 API 服务器提供的客户端证书。 如果提供了客户端证书并且证书被验证通过，则 subject 中的公共名称（Common Name）就被作为请求的用户名。

静态令牌文件认证：当 API 服务器的命令行设置了 `--token-auth-file=SOMEFILE` 选项时，会从文件中读取持有者令牌。目前，令牌会长期有效，并且在不重启 API 服务器的情况下无法更改令牌列表。

启动引导令牌认证：一种动态管理承载令牌进行身份认证的方式，常用于简化组建新 Kubernetes 集群时将节点加入集群的认证过程，需要由 Kube-apiserver 通过 --enable-bootstrap-token-auth 选项启用，新的工作节点首次加入时，Master 使用引导令牌确认节点身份的合法性之后自动为其签署数字证书以用于后续的安全通信，kubeadm 初始化的集群也是这种认证方式。

Server Account 令牌：该认证方式会由 kube-apiserver 程序自动启用，它同样使用签名的承载令牌来验证请求，该认证方式还支持通过可选项 --service-account-key-file 加载签署承载令牌的秘钥文件，未指定时将使用 API Server 自己的 TLS 私钥，Server Account 通常由 API Server 自动创建，并通过 Server Account 准入控制器将其注入 Pod 对象，包括 Server Account 上的承载令牌，容器中的应用程序请求 API Server 的服务时以此完成身份认证。 

那些未能被任何验证插件明确拒绝的请求中的用户即为匿名用户，该类用户会被冠以 system：anonymous 用户名，隶属于 system: unauthenticated 用户组。若 API Server 启用了除 Always Allow 以外的认证机制，则匿名用户处于启用状态，但是，处于安全因素考虑，建议管理员通过 --anonymous-auth=false 选项将其禁用。

除了身份信息，请求报文还需要提供操作方法及其目标对象，例如针对某 Pod 资源对象进行的创建、查看、修改或者删除操作等。具体包含以下信息。

- API: 用于定义请求的目标是否为一个 API 资源。
- Request path: 请求的非资源路径，例如 /api 或 /healthz。
- API group: 要访问的 API 组，仅对资源型请求有效，默认为 core API group。
- Namespace: 目标资源的名称空间，仅对于隶属于名称空间类型的资源有效。
- API request verb: API 请求类的操作，即资源请求，包括 get、list、create、update、patch、watch、delete 等。
- HTTP request verb: HTTP 请求类的操作，即非资源类请求要执行的操作，如 get、post、put、delete 等。
- Resource: 请求的目标资源的 ID 或名称。
- Subersource: 请求的子资源。

为了核验用户的操作许可，成功通过身份认证后的操作请求还需要转交给授权插件进行许可权限检查，以确保其拥有相应操作的许可。API Server 只要支持使用 4 类内置的授权插件来定义用户的操作权限。

- Node: 基于 Pod 资源的目标调度节点来实现对 kubelet 的访问控制。
- ABAC: Attribute-based access control，基于属性的访问控制。
- RBAC: Role-based access control，基于角色的访问控制。
- Webhook: 基于 HTTP 回调机制实现外部 REST 服务检查，确认用户授权的访问控制。

另外，还有 AlwaysDeny 和 AlwaysAllow 两个特殊的授权插件，其中 AlwaysDeny（总是拒绝）仅用于测试，而 AlwaysAllow（总是允许），则用于不期望进行授权检查时直接在授权检查阶段放行所有的操作请求。--authorization-mode 选项用于定义 API Server 要启用的授权机制，多个选项值彼此间以逗号进行分隔。

而准入控制器则用于在客户端请求经过身份验证和授权检查之后，将对象持久化存储到 etcd 之前拦截请求，从而实现在资源的创建，更新和删除操作期间强制执行对象的语义验证等功能，而读取资源信息的操作请求则不会经由准入控制器检查。API Server 内置了许多准入控制器，常用的包含下面列出的几种。

- AlwaysAdmin 和 AlwaysDeny: 前者允许所有请求，后者则拒绝所有请求。（已废弃，仅了解）
- AlwaysPullmages: 总是下载镜像，即每次创建 Pod 对象之前都要去下载镜像。
- NamespaceLifecycle: 拒绝在不存在的名称空间中创建资源，而删除名称空间则会级联删除其下的所有其他资源。
- LimitRanger: 可用资源范围界定，用于对设置了 LimitRange 的对象所发出的所有请求进行监控，以确保其资源请求不会超限。
- ServiceAccount: 用于实现服务账号管控机制的自动化，实现创建 Pod 对象时自动为其附加相关的 Service Account 对象。
- DefaultStorageClass: 监控所有创建 PVC 对象的请求，以保证那些没有附加任何专用 StorageClass 的请求会被自动设定一个默认值。
- ResourceQuota: 用于为名称空间设置可用资源上限，并确保当其中创建的任何设置了资源限额的对象时，不会超出名称空间的资源配额。       

早期的准入控制器代码需要由管理员编译进 kube-apiserver 中才能使用，实现方式缺乏灵活性。于是 Kubernetes 自 v1.7 版本引入了 Initializers 和 External Admin Webhooks 来尝试突破此限制，而且 v1.9 版本起，External Admin Webhooks 被分为 Mutating-Admission Webhooks 和 ValidatingAdmission Webhooks 两种类型，分别用于在 API 中执行对象配置的变异和验证操作。检查期间，仅那些顺利通过所有准入控制器检查的资源操作请求的结果才能保存到 etcd 中，而任何一个准入控制器的拒绝都将导致写入请求失败。

## ServiceAccount 及认证

 Kubernetes 原生的应用程序意味着专为运行于 Kubernetes 系统之上而开发的应用程序，这些程序托管运行在 Kubernetes 之上，能够直接与 API Server 进行交互，并进行资源状态的查询或更新，例如 Flannel 和 CoreDNS 等。显然，API Server 同样需要对来自 Pod 资源中的客户端程序进行身份验证，服务账号也是专用于这类场景的账号。ServiceAccount 资源一般由用户身份信息及保存了认证信息的 Secret 对象组成。

### ServiceAccount 自动化

我们创建的每个 Pod 资源都自动关联了一个 Secret 存储卷，并由其容器挂载至 /var/run/secret/kubernetes.io/serviceaccount 目录。各容器的挂载点目录通常存在 3 个文件：ca.crt、namespace 和 token，其中，token 文件保存了 ServiceAccount 的认证令牌，容器中的进程使用该账户认证到 API Server ，进而由认证插件完成用户认证并将其用户名传递给授权插件。

每个 Pod 对象只有一个服务账号，若创建 Pod 资源时未予以明确指定，则 ServiceAccount 准入控制器会为其自动附加当前名称空间中默认的服务账号，其名称通常为 default。  

Kubernetes 系统通过 3 个独立的组件相互协作实现了上面描述的 Pod 对象服务账号的自动化过程：ServiceAccount 准入控制器、令牌控制器和 ServiceAccount 控制器。ServiceAccount 控制器负责为名称空间管理相应的资源对象，它需要确保每个名称空间中都存在一个名为 default 的服务账号对象。ServiceAccount 准入控制器内置在 API Server 中，负责在创建或更新 Pod 时按需进行 ServiceAccount 资源对象相关信息的修改，这包括如下操作。

- 若 Pod 没有显式定义使用的 ServiceAccount 对象，则将其设置为 default。
- 若 Pod 显式引用了 ServiceAccount，则负责检查被引用的对象是否存在，不存在时将拒绝 Pod 资源的创建请求。
- 若 Pod 中不包含 ImagePullSecret，则把 ServiceAccount 的 ImagePullSecret 附加其上。
- 为带有访问 API 的令牌的 Pod 对象添加一个存储卷。
- 为 Pod 对象中的每个容器添加一个 volumeMount，将 ServiceAccount 的存储卷挂载至 /var/run/secret/kubernetes.io/serviceaccount。

令牌控制器是控制平面组件 Controller Manager 中的一个专用控制器，它工作于异步模式，负责完成如下任务。

- 监控 ServiceAccount 的创建操作，并为其添加用于访问 API 的 Secret 对象。
- 监控 ServiceAccount 的删除操作，并删除其相关的所有 ServiceAccount 令牌秘钥。
- 监控 Secret 对象的添加操作，确保其引用的 ServiceAccount 存在，并在必要时为 Secret 对象添加认证令牌。
- 监控 Secret 对象的删除操作，以确保删除每个 ServiceAccount 对此 Secret 的引用。

### ServiceAccount 基础应用

ServiceAccount 是 Kubernetes API 上的一种资源类型，它属于名称空间级别，用于让 Pod 对象内部的应用程序在与 API Server 通信时完成身份认证。

命令式 ServiceAccount 资源创建：

kubectl create serviceaccount 命令能够快速创建自定义的 ServiceAccount 资源，我们仅需要在命令后给出目标 ServiceAccount 资源的名称。

```bash
[root@k8s-master ~]# kubectl create serviceaccount my-service-account
serviceaccount/my-service-account created
```

Kubernetes 会为创建的 ServiceAccount 资源自动生成并附加一个 Secret 对象，该对象以 ServiceAccount 资源名称为前缀。该 Secret 对象属于特殊的 kubernetes.io/service-account-token 类型，它包含 ca.crt、namespace 和 secret 这 3 个数据项，它们分别是 Kubernetes Root CA 证书、Secret 对象所在名称空间和访问 API Server 的令牌。

ServiceAccount 资源清单：

更完善的创建 ServiceAccount 资源的方式是使用资源规范，该规范比较简单，它没有 spec 字段，仅指定了资源名称，以及允许 Pod 对象将其自动挂载为存储卷，引用的 Secret 对象则由系统自动生成。

```yaml
apiVersion: v1
kind: ServiceAccout
metadata:
  name: sa-demo
  namespace: default
automountServiceAccountToken: true # 是否让Pod自动挂载API令牌
```

## kubeconfig 配置文件

基于无状态协议 HTTP/HTTPS 的 API Server 需要验证每次连接请求中的用户身份，因而 kube-controller-manager、kube-scheduler 和 kube-proxy 等各类客户端组件必须能自动完成身份认证信息的提交，但通过程序选项来提供这些信息会导致敏感信息泄露。另外，管理员还面临着使用 kubectl 工具接入不同集群时的认证及认证信息映射难题。为此，Kubernetes 设计了一种称为 kubeconfig 的配置文件，它保存有接入一到多个 Kubernetes 集群的相关配置信息，并允许管理员按需在各配置间灵活切换。

```bash
                              kubernetes cluster1 API Server
kubectl ---> kubeconfig --->  kubernetes cluster2 API Server
                              kubernetes cluster3 API Server
```

客户端程序可以通过默认路径、--kubeconfig 选项或者 KUBECONFIG 环境变量自定义要加载的 kubeconfig 文件，从而能够在每次的访问请求中可认证到目标 API Server。

### kubeconfig 文件格式

kubeconfig 文件中，各集群的接入端点以列表形式定义在 clusters 配置段中，每个列表项代表一个 Kubernetes 集群，并拥有名称识别；各身份认证信息定义在 users 配置段中，每个列表项代表一个能够认证到某 Kubernetes 集群的凭据。将身份凭据与集群分开定义以便复用，具体使用时还要以 context（上下文）在二者之间按需建立映射关系，各 context 以列表形式定义在 context 配置段中，而当前使用的映射关系则定义在 current-context 配置段中。 

```yaml
clusters:
- cluster:
  name: kubernetes
  ......
users:
- name: kubernetes-admin
  ......
contexts:
- context:
  name: kubernetes-admin@kubernetes
  ......
current-context: kubernetes-admin@kubernetes
```

使用 kubeadm 初始化 Kubernetes 集群过程中，在 Master 节点上生成的 /etc/kubernetes/admin.conf 文件就是一个 kubeconfig 格式的文件，它由 kubeadm init 命令自动生成，可由 kubectl 加载后接入当前集群的 API Server。kubeconfig 文件的默认加载路径为 $HOME/.kube/config，在 kubeadm init 命令初始化集群过程中有一个步骤便是将 /etc/kubenetes/admin.conf 复制为该默认搜索路径上的文件。当然也可以通过 --kubeconfig 选项或 KUBECONFIG 环境变量将其修改为其他路径。

kubectl config view 命令能打印 kubeconfig 文件的内容，下面的命令结果显示了默认路径下的文件配置，包括集群列表、用户列表、上下文列表以及当前使用的上下文等。

```yaml
[root@k8s-master ~]# kubectl config view
apiVersion: v1
kind: Config
preferences: {}
clusters:
- cluster:
    certificate-authority-data: DATA+OMITTED
    server: https://10.10.110.190:6443
  name: kubernetes
users:
- name: kubernetes-admin
  user:
    client-certificate-data: REDACTED
    client-key-data: REDACTED
contexts:
- context:
    cluster: kubernetes
    user: kubernetes-admin
  name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes
```

用户可以在 kubeconfig 配置文件中按需自定义相关的配置信息，以实现使用不同的用户账号接入集群等功能。kubeconfig 是一个文本文件，尽管可以使用文本处理工具直接编辑，但强烈建议用户使用 kubectl config 及其子命令进行该文件的设定，以便利用其它自动进行语法检测等额外功能。kubectl config 的常用子命令有如下几项。

- view: 打印 kubeconfig 文件内容。
- set-cluster: 设定新的集群信息，以单独的列表项保存于 cluster 配置段。
- set-credentials: 设置认证凭据，保存为 users 配置段的一个列表项。
- set-context: 设置新的上下文信息，保存为 context 配置段的一个列表项。
- use-context: 设定 current-context 配置段，确定当前以哪个用户的身份接入到哪个集群当中。
- delete-cluster: 删除 cluster 中指定的列表项。
- delete-context: 删除 context 中指定的列表项。
- get-cluster: 获取 cluster 中定义的集群列表。
- get-context: 获取 context 中定义的上下文列表。

### 自定义 kubeconfig 文件

通常，一个完整 kubeconfig 配置文件的定义至少应该包括集群、身份凭证、上下文以及当前上下文 4 项，但在保存有集群身份和身份凭据的现有 kubeconfig 文件基础上添加新的上下文时，可能只需要提供身份凭据而复用现有的集群定义，具体操作步骤需要按实际情况判定。

示例：为 dev 用户授权 default 命名空间下 Pod 读取权限。

1. 以证书认证方式授权 kubeconfig（使用现有 Kubernetes CA 签发 dev 证书）。

```json
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
         "expiry": "87600h",
         "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ]
      }
    }
  }
}
EOF

cat > kubernetes-dev-csr.json <<EOF
{
  "CN": "kubernetes-dev",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
       "C": "CN",
       "ST": "GuangDong",
       "L": "ShenZhen",
       "O": "Kubernetes",
       "OU": "System"
    }
  ]
}
EOF

cfssl gencert -ca=/etc/kubernetes/pki/ca.crt -ca-key=/etc/kubernetes/pki/ca.key -config=ca-config.json -profile=kubernetes kubernetes-dev-csr.json | cfssljson -bare kubernetes-dev

# 利用 Kubenetes CA 签发得到 dev 的公钥和私钥
kubernetes-dev-key.pem
kubernetes-dev.pem
```

2. 设置集群参数，包括集群名称、API Server URL 和 kubenetes-ca 证书。

```bash
kubectl config set-cluster dev --embed-certs=true \
  --certificate-authority=/etc/kubernetes/pki/ca.crt \
  --server="https://10.10.110.190:6443" \
  --kubeconfig=$HOME/.kube/kube-dev.cnofig
```

3. 添加身份凭据，使用前面生成的 dev 证书认证客户端。

```bash
kubectl config set-credentials kubernetes-dev \
  --client-key=kubernetes-dev-key.pem \
  --client-certificate=kubernetes-dev.pem \
  --embed-certs=true \
  --kubeconfig=$HOME/.kube/kube-dev.cnofig
```

4. 以用户 kubernetes-dev 的身份凭据与 dev 集群建立映射关系。

```bash
kubectl config set-context kubernetes-dev@dev \
  --cluster=dev \
  --user=kubernetes-dev \
  --kubeconfig=$HOME/.kube/kube-dev.cnofig
```

5. 设置 kube-dev.cnofig 配置文件当前上下文为 kubernetes-dev@dev。

```bash
kubectl config use-context kubernetes-dev@dev --kubeconfig=$HOME/.kube/kube-dev.cnofig
```

6. 使用 kube-dev.cnofig 配置文件进行访问测试。

```bash
kubectl get namespaces --kubeconfig=$HOME/.kube/kube-dev.cnofig
Error from server (Forbidden): namespaces is forbidden: User "kubernetes-dev" cannot list resource "namespaces" in API group "" at the cluster scope
```

这是因为 kubernetes-dev 用户没有绑定 Role，所以不具有任何权限。

## 基于角色的访问控制：RBAC

DAC（自主访问控制）、MAC（强制访问控制）、RBAC（基于角色的访问控制）和 ABAC（基于属性的访问控制）这四种主流的权限管理模型中，Kubernetes 支持使用后两种完成普通账户和服务账户的权限管理，另外支持的权限管理模型还有 Node 和 Webhook 两种。

RBAC 是一种新型、灵活且使用广泛的访问控制机制，它将权限授予角色，通过让“用户”扮演一到多个“角色”完成灵活的权限管理，这有别于传统访问控制机制中将权限直接赋予使用者的方式。相对于 Kubernetes 支持的 ABAC 和 Webhook 等授权机制，RBAC 具有如下优势：

- 对集群中的资源和非资源型 URL 的权限实现了完整覆盖。
- 整个 RBAC 完全由少数几个 API 对象实现，而且与其他 API 对象一样可以使用 kubectl 或 API 调用进行操作。
- 支持权限的运行时调整，无须重新启动 API Server。

### RBAC 授权模型

RBAC 是一种特定的权限管理模型，它把可以施加在“资源对象”上的“动作”称为“许可权限”，这些许可权限能够按需组合在一起构建出“角色”及其职能，并通过为“用户账户或组账户”分配一到多个角色完成权限委派。这些能够发出动作的用户在 RBAC 中也称为“主体”。

```bash
          Role1 
user ---> Role2 ---> 权限（操作--->对象）
          Role3
```

RBAC 访问控制模型中，授权操作只能通过角色完成，主体只有在分配到角色之后才能行使权限，且仅限于从其绑定的各角色之上继承而来的权限。换句话说，用户的权限仅能够通过角色分配获得，未能得到显示角色委派的用户则不具有任何权限。

简单来说，RBAC 就是一种访问控制模型，它以角色为中心界定“谁”（subject）能够“操作”（verb）哪个或哪类“对象”（object）。动作的发出者即“主体”，通常以“账户”为载体，在 Kubernetes 系统上，它可以是普通账户，也可以是服务账户。“动作”用于表明要执行的具体操作，包括创建、删除、修改和查看等行为，对于 API Server 来说，即 PUT、DELETE 和 GET 等请求方法。而“对象”则是指管理操作能够施加的目标实体，对 Kubernetes API 来说主要指各类资源对象以及非资源型 URL。

Kubernetes 系统的 RBAC 授权插件将角色分为 Role 和 ClusterRole 两类，它们都是 Kubernetes 内置支持的 API 资源类型，其中 Role 作用于名称空间级别，用于承载名称空间内的资源权限集合，而 ClusterRole 则能够同时承载名称空间和集群级别的资源权限集合。Role 无法承载集群级别的资源类型的操作权限，这类的资源包括集群级别的资源（例如 Nodes），非资源类型的端点（例如 /healthz），以及作用于所有名称空间的资源等。

利用 Role 和 ClusterRole 两类角色进行赋权时，需要用到另外两种资源 RoleBinding 和 ClusterRoleBinding，它们同样时由 API Server 内置支持的资源类型。RoleBinding 用于将 Role 绑定到一个或者一组用户之上，它隶属于且仅能作用于其所在的单个名称空间。RoleBinding 可以引用同一名称空间中的 Role，也可以引用集群级别的 ClusterRole，但引用 ClusterRole 的许可权限会降低到仅能在 RoleBinding 所在的名称空间生效。而 ClusterRoleBinding 则用于将 ClusterRole 绑定到用户或组，它作用于集群全局，且仅能够引用 ClusterRole。

### Role 和 ClusterRole

如前所述，Role 和 ClusterRole 是 API Server 内置的两种资源类型，它们在本质上都只是一组许可权限的集合。

下面的配置清单示例在 default 名称空间中定义了一个 Role 的资源，它设定了读取、列出及监视 pods 和 services 资源。

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pods-reader
rules:
- apiGroup: [""] # "" 表示核心 API 群组
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]
```

ClusterRole 资源隶属于集群级别，它引用名称空间级别的资源意味着相关的操作权限能够在所有名称空间生效，同时，它也能够引用 Role 所不支持的集群级别的资源类型，例如 nodes 和 persistentvolumes 等。下面的示例清单定义了 ClusterRole 资源，它拥有管理集群节点信息的权限。ClusterRole 不属于名称空间，所以其配置不能够使用 metadata.namespace 字段。

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: nodes-admin
rules:
- apiGroup: [""] # "" 表示核心 API 群组
  resources: ["nodes"]
  verbs: ["*"]
```

Role 或 ClusterRole 对象本身并不能作为动作的执行主体，它们需要“绑定”到主体（例如 User、Group 或 Service Account）之上完成赋权，而后由相应主体执行资源操作。

### RoleBinding 与 ClusterRoleBinding

