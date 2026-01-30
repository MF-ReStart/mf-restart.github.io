# Ingress

Ingress 是对集群中服务的外部访问进行管理的 API 对象，典型的访问方式是 HTTP。

Ingress 可以提供负载均衡、SSL 终结和基于名称的虚拟托管。

## Ingress 是什么？

[Ingress](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.21/#ingress-v1beta1-networking-k8s-io) 公开了从集群外部到集群内[服务](https://kubernetes.io/zh/docs/concepts/services-networking/service/)的 HTTP 和 HTTPS 路由。 流量路由由 Ingress 资源上定义的规则控制。

下面是一个将所有流量都发送到同一 Service 的简单 Ingress 示例：

![](https://img.imgdb.cn/item/607553c38322e6675cd7616b.jpg)

可以将 Ingress 配置为服务提供外部可访问的 URL、负载均衡流量、终止 SSL/TLS，以及提供基于名称的虚拟主机等能力。 [Ingress 控制器](https://kubernetes.io/zh/docs/concepts/services-networking/ingress-controllers) 通常负责通过负载均衡器来实现 Ingress，尽管它也可以配置边缘路由器或其他前端来帮助处理流量。

Ingress 不会公开任意端口或协议。 将 HTTP 和 HTTPS 以外的服务公开到 Internet 时，通常使用 [Service.Type=NodePort](https://kubernetes.io/zh/docs/concepts/services-networking/service/#nodeport) 或 [Service.Type=LoadBalancer](https://kubernetes.io/zh/docs/concepts/services-networking/service/#loadbalancer) 类型的服务。

## 环境准备

你必须具有 [Ingress 控制器](https://kubernetes.io/zh/docs/concepts/services-networking/ingress-controllers) 才能满足 Ingress 的要求。 仅创建 Ingress 资源本身没有任何效果。

你可能需要部署 Ingress 控制器，例如 [ingress-nginx](https://kubernetes.github.io/ingress-nginx/deploy/)。 你可以从许多 [Ingress 控制器](https://kubernetes.io/zh/docs/concepts/services-networking/ingress-controllers) 中进行选择。

理想情况下，所有 Ingress 控制器都应符合参考规范。但实际上，不同的 Ingress 控制器操作略有不同。

## Ingress 资源

一个最小的 Ingress 资源示例：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minimal-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
      - path: /testpath
        pathType: Prefix
        backend:
          service:
            name: test
            port:
              number: 80
```

与所有其他 Kubernetes 资源一样，Ingress 需要使用 `apiVersion`、`kind` 和 `metadata` 字段。 Ingress 对象的命名必须是合法的 [DNS 子域名名称](https://kubernetes.io/zh/docs/concepts/overview/working-with-objects/names#dns-subdomain-names)。 有关使用配置文件的一般信息，请参见[部署应用](https://kubernetes.io/zh/docs/tasks/run-application/run-stateless-application-deployment/)、 [配置容器](https://kubernetes.io/zh/docs/tasks/configure-pod-container/configure-pod-configmap/)、 [管理资源](https://kubernetes.io/zh/docs/concepts/cluster-administration/manage-deployment/)。 Ingress 经常使用注解（annotations）来配置一些选项，具体取决于 Ingress 控制器，例如 [重写目标注解](https://github.com/kubernetes/ingress-nginx/blob/master/docs/examples/rewrite/README.md)。 不同的 [Ingress 控制器](https://kubernetes.io/zh/docs/concepts/services-networking/ingress-controllers) 支持不同的注解。查看文档以供你选择 Ingress 控制器，以了解支持哪些注解。

Ingress [规约](https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#spec-and-status) 提供了配置负载均衡器或者代理服务器所需的所有信息。 最重要的是，其中包含与所有传入请求匹配的规则列表。 Ingress 资源仅支持用于转发 HTTP 流量的规则。

### Ingress 规则

每个 HTTP 规则都包含以下信息：

- 可选的 `host`。在此示例中，未指定 `host`，因此该规则适用于通过指定 IP 地址的所有入站 HTTP 通信。 如果提供了 `host`（例如 foo.bar.com），则 `rules` 适用于该 `host`。
- 路径列表 paths（例如，`/testpath`）,每个路径都有一个由 `serviceName` 和 `servicePort` 定义的关联后端。 在负载均衡器将流量定向到引用的服务之前，主机和路径都必须匹配传入请求的内容。
- `backend`（后端）是 [Service 文档](https://kubernetes.io/zh/docs/concepts/services-networking/service/) 中所述的服务和端口名称的组合。 与规则的 `host` 和 `path` 匹配的对 Ingress 的 HTTP（和 HTTPS ）请求将发送到列出的 `backend`。

通常在 Ingress 控制器中会配置 `defaultBackend`（默认后端），以服务于任何不符合规约中 `path` 的请求。

### DefaultBackend

没有 `rules` 的 Ingress 将所有流量发送到同一个默认后端。 `defaultBackend` 通常是 [Ingress 控制器](https://kubernetes.io/zh/docs/concepts/services-networking/ingress-controllers) 的配置选项，而非在 Ingress 资源中指定。

如果 `hosts` 或 `paths` 都没有与 Ingress 对象中的 HTTP 请求匹配，则流量将路由到默认后端。

### 资源后端

Resource 后端是一个 ObjectRef，指向同一命名空间中的另一个 Kubernetes，将其作为 Ingress 对象。Resource 与 Service 配置是互斥的，在二者均被设置时会无法通过合法性检查。Resource 后端的一种常见用法是将所有入站数据导向带有静态资产的对象存储后端。

### 路径类型

Ingress 中的每个路径都需要有对应的路径类型（Path Type）。未明确设置 `pathType` 的路径无法通过合法性检查。当前支持的路径类型有三种：

- `ImplementationSpecific`: 对于这种路径类型，匹配方法取决于 IngressClass。 具体实现可以将其作为单独的 `pathType` 处理或者与 `Prefix` 或 `Exact` 类型作相同处理。
- `Exact`: 精确匹配 URL 路径，且区分大小写。
- `Prefix`: 基于以 `/` 分隔的 URL 路径前缀匹配。匹配区分大小写，并且对路径中的元素逐个完成。 路径元素指的是由 `/` 分隔符分隔的路径中的标签列表。 如果每个 *p* 都是请求路径 *p* 的元素前缀，则请求与路径 *p* 匹配。

**说明：** 如果路径的最后一个元素是请求路径中最后一个元素的子字符串，则不会匹配 （例如：`/foo/bar` 匹配 `/foo/bar/baz`, 但不匹配 `/foo/barbaz`）。

### 示例

| 类型   | 路径                            | 请求路径        | 匹配与否？               |
| ------ | ------------------------------- | --------------- | ------------------------ |
| Prefix | `/`                             | （所有路径）    | 是                       |
| Exact  | `/foo`                          | `/foo`          | 是                       |
| Exact  | `/foo`                          | `/bar`          | 否                       |
| Exact  | `/foo`                          | `/foo/`         | 否                       |
| Exact  | `/foo/`                         | `/foo`          | 否                       |
| Prefix | `/foo`                          | `/foo`, `/foo/` | 是                       |
| Prefix | `/foo/`                         | `/foo`, `/foo/` | 是                       |
| Prefix | `/aaa/bb`                       | `/aaa/bbb`      | 否                       |
| Prefix | `/aaa/bbb`                      | `/aaa/bbb`      | 是                       |
| Prefix | `/aaa/bbb/`                     | `/aaa/bbb`      | 是，忽略尾部斜线         |
| Prefix | `/aaa/bbb`                      | `/aaa/bbb/`     | 是，匹配尾部斜线         |
| Prefix | `/aaa/bbb`                      | `/aaa/bbb/ccc`  | 是，匹配子路径           |
| Prefix | `/aaa/bbb`                      | `/aaa/bbbxyz`   | 否，字符串前缀不匹配     |
| Prefix | `/`, `/aaa`                     | `/aaa/ccc`      | 是，匹配 `/aaa` 前缀     |
| Prefix | `/`, `/aaa`, `/aaa/bbb`         | `/aaa/bbb`      | 是，匹配 `/aaa/bbb` 前缀 |
| Prefix | `/`, `/aaa`, `/aaa/bbb`         | `/ccc`          | 是，匹配 `/` 前缀        |
| Prefix | `/aaa`                          | `/ccc`          | 否，使用默认后端         |
| 混合   | `/foo` (Prefix), `/foo` (Exact) | `/foo`          | 是，优选 Exact 类型      |

### 最基本的 Ingress 资源

注意：在此示例中，未指定 `host`，因此该规则适用于通过指定 IP 地址的所有入站 HTTP 通信。 如果提供了 `host`（例如 foo.bar.com），则 `rules` 适用于该 `host`。

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-wildcard-host
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
      - pathType: Prefix
        path: "/nginx"
        backend:
          service:
            name: nginx-service
            port:
              number: 80
  defaultBackend:
    service:
      name: default-http-backend
      port:
        number: 80    
```

### 基于 URL 路由代理服务

配置根据请求的 HTTP URI 将来自同一 IP 地址的流量路由到多个 Service。

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-wildcard-host
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: "www.ingress.com"
    http:
      paths:
      - pathType: Prefix
        path: "/nginx"
        backend:
          service:
            name: nginx-service
            port:
              number: 80
      - pathType: Prefix
        path: "/tomcat"
        backend:
          service:
            name: tomcat-service
            port:
              number: 80
  defaultBackend: # 如果hosts或paths都没有与Ingress对象中的HTTP请求匹配,则流量将路由到默认后端
    service:
      name: default-http-backend
      port:
        number: 80
```

### 基于名称的虚拟托管

基于名称的虚拟主机支持将针对多个主机名的 HTTP 流量路由到同一 IP 地址上。

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-wildcard-host
spec:
  rules:
  - host: "www.nginx.com"
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: nginx-service
            port:
              number: 80
  - host: "www.tomcat.com"
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: tomcat-service
            port:
              number: 80
  defaultBackend:
    service:
      name: default-http-backend
      port:
        number: 80
```

### TLS

可以通过设定包含 TLS 私钥和证书的 [Secret](https://kubernetes.io/zh/docs/concepts/configuration/secret/) 来保护 Ingress。 Ingress 只支持单个 TLS 端口 443，并假定 TLS 连接终止于 Ingress 节点 （与 Service 及其 Pod 之间的流量都以明文传输）。 如果 Ingress 中的 TLS 配置部分指定了不同的主机，那么它们将根据通过 SNI TLS 扩展指定的主机名 （如果 Ingress 控制器支持 SNI）在同一端口上进行复用。 TLS Secret 必须包含名为 `tls.crt` 和 `tls.key` 的键名。 这些数据包含用于 TLS 的证书和私钥。例如：

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: testsecret-tls
  namespace: default
data:
  tls.crt: base64 编码的 cert
  tls.key: base64 编码的 key
type: kubernetes.io/tls
```

在 Ingress 中引用此 Secret 将会告诉 Ingress 控制器使用 TLS 加密从客户端到负载均衡器的通道。 你需要确保创建的 TLS Secret 创建自包含 `https-example.foo.com` 的公用名称（CN）的证书。 这里的公共名称也被称为全限定域名（FQDN）。

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-wildcard-host
spec:
  tls:
  - hosts:
      - www.missf.top
    secretName: www-missf-top
  rules:
  - host: www.missf.top
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: nginx-service
            port:
              number: 80
  defaultBackend:
    service:
      name: default-http-backend
      port:
        number: 80
```

#### 生成 tls 自签证书

CFSSL 是 CloudFlare 开源的一款 PKI/TLS 工具。 CFSSL 包含一个命令行工具和一个用于签名、验证并且捆绑 TLS 证书的 HTTP API 服务，使用 Go 语言编写。

**安裝 `CFSSL` 工具**

```bash
curl -s -L -o /usr/local/bin/cfssl https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
curl -s -L -o /usr/local/bin/cfssljson https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
curl -s -L -o /usr/local/bin/cfssl-certinfo https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64
chmod +x /usr/local/bin/cfssl*
```

**生成配置证书生成策略文件**

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
```

这个策略，有一个默认的配置和一个 `profile`，这里的 `profile` 是 kubernetes。

signing: 表示该证书可用于签名其它证书。

server auth: 表示 client 可以用该 CA 对 server 提供的证书进行验证。

client auth: 表示 server 可以用该 CA 对 client 提供的证书进行验证。

expiry: 表示证书的有效期。

**生成 CA 证书和私钥配置文件**

```json
cat > ca-csr.json <<EOF
{
    "CN": "kubernetes",
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
            "OU": "Devops"
        }
    ]
}
EOF
```

CN: Common Name，kube-apiserver 从证书中提取该字段作为请求的用户名 (User Name)，浏览器使用该字段验证网站是否合法。

C: Country， 国家。

ST: State，州，省。

L: Locality，地区，城市。

O: Organization，kube-apiserver 从证书中提取该字段作为请求用户所属的组 (Group)。

OU: Organization Unit Name，组织单位名称，公司部门。

**生成 CA 证书、CA 私钥、CSR 文件**

```bash
cfssl gencert -initca ca-csr.json | cfssljson -bare ca -

# 得到如下文件
[root@k8s-master ~/kubernetes/ssl]$ ll
total 28
-rw-r--r-- 1 root root  294 Apr 17 15:46 ca-config.json
-rw-r--r-- 1 root root 1013 Apr 17 15:48 ca.csr
-rw-r--r-- 1 root root  274 Apr 17 15:47 ca-csr.json
-rw------- 1 root root 1679 Apr 17 15:48 ca-key.pem
-rw-r--r-- 1 root root 1387 Apr 17 15:48 ca.pem
```

**生成服务端的证书信息**

```json
cat > www.missf.top-csr.json <<EOF
{
  "CN": "www.missf.top",
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
```

**使用 ca 证书签发证书**

```bash
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes www.missf.top-csr.json | cfssljson -bare www.missf.top
```

**使用证书创建 secret 资源**

```bash
kubectl create secret tls www-missf-top --cert=www.missf.top.pem --key=www.missf.top-key.pem
```
