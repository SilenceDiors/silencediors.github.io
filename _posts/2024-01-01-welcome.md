---
layout: post
title: "MCP 鉴权漏洞分析"
date: 2025-11-26 12:00:00 +0800
categories: security
---

# 1. 漏洞原理

## 1.1 无鉴权

自己没有实现鉴权，也没有使用官方的MCP鉴权，压根没有考虑过MCP的鉴权，这种情况一般只有毫无敏感信息的才会这么去做。

## 1.2 自己实现鉴权逻辑缺陷

自己去实现鉴权逻辑，但是没有这方面的能力导致逻辑错误可以绕过鉴权或者鉴权无效。MCP官方也不建议这么做，建议使用官方提供的OAuth 2.1实现。

## 1.3 使用了官方的鉴权但是配置不安全

着重说一下这个，这个是大多数出问题的点，捋一下MCP使用oauth2.1的整个鉴权逻辑

### 1.3.1 授权服务器鉴权方式

首先，我们不考虑MCP的情况下，了解一下现在正常的一个授权服务器跟客户端鉴权的流程。

### 1.3.2 MCP客户端认证流程

上面的鉴权流程如果理完了，我们把资源服务器换成MCP服务器（MCP是后来者，鉴权方式不可能因为它去适配，只能它来适配之前的）再来一遍，这里我们把MCP服务器当成资源服务器，其实也没啥本质区别。

<div class="mermaid">
sequenceDiagram
    participant Client as MCP客户端
    participant MCP as MCP服务器
    participant AS as 授权服务器
    participant SSO as SSO提供商

    Client->>MCP: 1. 请求资源 GET /mcp
    MCP->>Client: 2. 401 + PRM端点信息
    Client->>MCP: 3. 获取PRM元数据
    MCP->>Client: 4. 返回授权服务器地址
    Client->>AS: 5. 获取授权服务器元数据
    AS->>Client: 6. 返回端点信息
    Client->>AS: 7. 动态注册客户端
    AS->>Client: 8. 返回client_id和client_secret
    Client->>AS: 9. 授权请求（带PKCE）
    AS->>SSO: 10. 重定向到SSO登录
    SSO->>AS: 11. 用户授权完成
    AS->>Client: 12. 返回授权码
    Client->>AS: 13. 用授权码换取Token
    AS->>Client: 14. 返回Access Token
    Client->>MCP: 15. 带Token访问资源
    MCP->>AS: 16. Token验证（Introspection）
    AS->>MCP: 17. 验证结果
    MCP->>Client: 18. 返回资源
</div>

**步骤一：握手**

访问`https://MCP.server.com/mcp`或其他端点，返回401和PRM端点信息

```
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Bearer realm="mcp",
  resource_metadata="https://MCP.server.com/.well-known/oauth-protected-resource"
```

**步骤二：请求PRM数据**

访问上一步拿到的MCPserver的公开端点`https://MCP.server.com/.well-known/oauth-protected-resource`获取PRM信息（受保护资源元数据）

```json
{
   //MCP服务器
  "resource": "https://MCP.server.com/mcp",
  //认证服务器
  "authorization_servers": ["https://AUTH.server.com"],
  //支持的权限范围
  "scopes_supported": ["mcp:tools", "mcp:resources"]
}
```

**步骤三：获取授权服务器接口信息**

获取授权服务器的授权端点（也是公开的元数据），客户端将构建一个标准元数据 URI，并向OpenID Connect (OIDC) Discovery或OAuth 2.0 Auth Server Metadata端点（取决于授权服务器的支持情况）发出请求

```json
{
  //授权服务器主域名
  "issuer": "https://auth.server.com",
  //获取授权码
  "authorization_endpoint": "https://auth.server.com/authorize",
  //获取令牌
  "token_endpoint": "https://auth.server.com/token",
  //注册
  "registration_endpoint": "https://auth.server.com/register"
}
```

**步骤四：授权服务器注册**

静态注册，在授权服务器中自行配置客户端注册信息；动态注册：`https://auth.server.com/register`，发送如下json数据（静态动态注册客户端很重要后面会接上），注册成功的话授权服务器将返回一个包含客户端注册信息的 JSON 数据块。

```json
{
  "client_name": "My MCP Client",
  "redirect_uris": ["http://localhost:3000/callback"],
  "grant_types": ["authorization_code", "refresh_token"],
  "response_types": ["code"]
}
```

**步骤五：用户授权**

用户在`https://auth.server.com/authorize`，并获取返回的认证信息授权给步骤四动态注册的客户端：

```
GET /authorize?response_type=code&client_id=550e8400-e29b-41d4-a716-446655440000&redirect_uri=http://localhost:3030/callback&state=abc123xyz&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&code_challenge_method=S256&scope=user HTTP/1.1
Host: auth.server.com
```

SDK中实现的demo是返回302登陆页面（正常操作都是接入SSO）

```python
return RedirectResponse(
    url=await self.provider.authorize(
        client,
        auth_params,
    ),
    status_code=302,
    headers={"Cache-Control": "no-store"},
)
```

授权之后然后返回到客户端授权码（localhost:3030是上面注册时候设置的redict_uri（客户端回调地址），code就是授权码）

```
HTTP/1.1 302 Found
Location: http://localhost:3030/callback?code=mcp_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6&state=abc123xyz
Cache-Control: no-store
```

然后客户端带着code访问授权服务器/token端点，标黄部分就是拿到的acesstoken

```
POST /token HTTP/1.1
Host: auth.server.com
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code&code=mcp_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6&redirect_uri=http://localhost:3030/callback&client_id=550e8400-e29b-41d4-a716-446655440000&code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk&resource=http://mcp.server.com/mcp
```

返回

```
HTTP/1.1 200 OK
Content-Type: application/json
Cache-Control: no-store
Pragma: no-cache
Content-Length: 234

{
  "access_token": "mcp_1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0t1u2v3w4x5y6z7",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "user"
}
```

**步骤六：访问MCP服务接口/GET**

```
GET /mcp HTTP/1.1
Host: MCP.server.com
//第五步从授权服务器拿的认证信息
Authorization: Bearer mcp_1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0t1u2v3w4x5y6z7
```

**步骤七：MCP服务器访问授权服务器令牌introspection**

```
POST /introspect HTTP/1.1
Host: auth.server.com
Content-Type: application/x-www-form-urlencoded
Content-Length: 67

token=mcp_1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0t1u2v3w4x5y6z7
```

这一步就是MCP服务器把accesstoken通过/introspection接口拿到授权服务器去校验一下，根据拿到的结果给MCPclient分配权限。然后通过，client可以正常访问/mcp接口了。

### 1.3.3 MCP服务端与授权服务器配置

1、授权服务器容器镜像拉取到本地，并启动基本配置。`docker run -p 127.0.0.1:8080:8080 -e ADMIN_USERNAME=admin -e ADMIN_PASSWORD=admin quay.io/keycloak/keycloak start-dev`（安全威胁1：默认弱口令admin/admin。）

2、客户端动态注册配置页面`http://localhost:8080/realms/master/.well-known/openid-configuration`

3、进行作用域设置（安全威胁2："客户端范围"mcp:tools权限资源配置缺陷）

4、令牌受众设置：配置令牌的作用MCP server端点（安全威胁3：配置范围过宽或者错误导致的令牌透传）

5、"客户端"、"客户端注册"和"受信任主机"设置

上文中客户端认证的步骤四，在注册的时候传入如下参数

```json
{
  "client_name": "My MCP Client",
  "redirect_uris": ["http://localhost:3000/callback"],
  "grant_types": ["authorization_code", "refresh_token"],
  "response_types": ["code"]
}
```

所以在这里就要明确的配置受信任主机（Trusted Hosts）是重要的安全机制，需要设置可注册的IP地址。（此处安全威胁4：可信MCP HOST IP地址配置范围控制缺陷）

6、令牌自省（Token Introspection）：符合Oauth规范的一种形式，mcp server作为中间人（可以带着mcp client的令牌去跟授权服务器判断令牌是否有效的权限）去跟授权服务器注册客户端。

<div class="mermaid">
graph TB
    subgraph "MCP客户端认证流程"
        A[MCP Client<br/>客户端] -->|1. 请求资源| B[MCP Server<br/>资源服务器]
        B -->|2. 401 Unauthorized<br/>返回PRM端点| A
        A -->|3. 获取PRM元数据| B
        B -->|4. 返回授权服务器地址| A
        A -->|5. 获取授权服务器元数据| C[Authorization Server<br/>授权服务器]
        C -->|6. 返回端点信息| A
        A -->|7. 动态客户端注册| C
        C -->|8. 返回client_id| A
        A -->|9. 授权请求+PKCE| C
        C -->|10. 返回授权码| A
        A -->|11. 用授权码换取Token| C
        C -->|12. 返回Access Token| A
        A -->|13. 带Token访问资源| B
        B -->|14. Token Introspection| C
        C -->|15. 验证结果| B
        B -->|16. 返回资源| A
    end
</div>

（安全威胁5：mcp server的client secret硬编码在mcp serverSDK的代码中。）

再附上原汁原味的官方SDK代码里画的图，是让在授权的时候接入SSO的

<div class="mermaid">
graph LR
    A[Client<br/>客户端] -->|1. 授权请求| B[MCP Server<br/>MCP服务器]
    B -->|2. 重定向到SSO| C[3rd Party OAuth<br/>第三方OAuth服务器]
    C -->|3. 用户授权| D[SSO Provider<br/>SSO提供商]
    D -->|4. 授权完成| C
    C -->|5. 重定向回MCP| B
    B -->|6. 生成授权码| E[redirect_uri<br/>客户端回调地址]
    E -->|7. 授权码| A
    A -->|8. 交换Token| C
    C -->|9. Access Token| A
</div>

### 1.3.4 真实应用场景风险

#### 1.3.4.1 混淆助手攻击

在实际的应用场景中，MCP服务器不但会像1.3.2中一样作为授权转发验证服务器，也充当着客户端与第三方API交互的代理服务器，因为MCP服务器本身就要具备工具执行、api调用的相关工作。这个时候它相对于资源服务器作为客户端，在授权服务器中的配置与普通客户端没有差别。

下面的攻击场景有几个前提：1、用户保持登陆状态（SSO或会话形式）。2、MCP服务器中使用静态client_id的方式在授权服务器中注册为客户端且充当客户端的代理。3、cookie中设置字段consent:true/false来判断client是否历史同意过某调用范围。（自定义的功能，为了用户体验不需要每次操作都点击授权同意）。

**MCP 代理服务器**：一种 MCP 服务器，它将 MCP 客户端连接到第三方 API，提供 MCP 功能，同时委托操作并作为单一 OAuth 客户端连接到第三方 API 服务器。

**第三方授权服务器**：就像上文中的授权服务器，它有时候不仅仅用户认证，三方的API授权也在其中注册，用于保护第三方 API 的授权服务器。

**第三方 API服务**：提供实际 API 功能的受保护资源服务器。访问此 API 需要由第三方授权服务器颁发的令牌。（正常的实现中api服务也不提供鉴权还是在第三方授权服务器中注册为资源服务器）

（安全威胁6：混淆助手攻击）

<div class="mermaid">
sequenceDiagram
    participant User as 用户<br/>已SSO登录
    participant Attacker as 攻击者
    participant MCP as MCP代理服务器<br/>静态client_id
    participant AS as 第三方授权服务器
    participant API as 第三方API

    rect rgb(200, 230, 200)
        Note over User,API: 正常流程
        User->>MCP: 正常访问资源
        MCP->>AS: Token Introspection验证
        AS-->>MCP: 验证通过
        MCP->>API: 访问第三方API
        Note over User,AS: 设置consent cookie
    end
    
    rect rgb(255, 200, 200)
        Note over Attacker,API: 攻击流程（1-click攻击）
        Attacker->>User: 发送恶意授权链接
        Note right of Attacker: client_id=mcp-proxy-static<br/>redirect_uri=https://attacker.com/callback
        User->>AS: 点击链接（1-click）
        Note over AS: 检测到consent cookie<br/>跳过同意屏幕
        AS->>AS: 自动授权（无用户确认）
        AS->>Attacker: 授权码重定向到攻击者服务器
        Attacker->>AS: 用授权码换取Access Token
        AS-->>Attacker: 返回Access Token
        Attacker->>API: 以用户身份访问第三方API
        Note over Attacker,API: 攻击成功！
    end
</div>

a.用户SSO接入后或者说会话保持着，通常通过 MCP 代理服务器进行身份验证（令牌内省），以访问第三方 API。

b.在此流程中，自实现的SDK，授权服务器会在useragent上设置一个 cookie，表明用户同意使用静态客户端 ID（优化体验，就这里出的问题导致1-click，点击链接，而不是正常的2-click，点击链接，还要点击同意）。

c.攻击者随后向用户发送一个恶意链接，其中包含精心构造的授权请求，该请求包含恶意重定向 URI 以及新动态注册的客户端 ID或者。（此时等于重新走一下1.3.2步骤五--->将用户认证返回给客户端地址，就这里做的文章）。

```
https://auth.server.com/authorize?
  client_id=mcp-proxy-static&
  redirect_uri=https://attacker.com/callback&
  response_type=code&
  scope=read write&
  state=random-state-123
```

```
https://auth.server.com/authorize?
  client_id=xxx-xxx-xxx（攻击者动态注册的）&
  redirect_uri=https://attacker.com/callback&
  response_type=code&
  scope=read write&
  state=random-state-123
```

正常情况下，动态注册的客户端走用户授权，需要重新点击确定，但是坏就坏在这里不管如何动态注册，都被MCP代理的client_id给固定起来了然后内省到授权服务器去验证。

d.当用户点击链接时，他们的浏览器仍然保留着之前合法请求的consent cookie(这个放在user agent字段中，判断是否同意)。

e.第三方授权服务器检测到 cookie 后，会跳过同意屏幕。

f.MCP 授权码被重定向到攻击者的服务器（在动态客户端注册期间精心构造的 redirect_uri 中指定）

g.攻击者未经用户明确同意，便将窃取的授权码交换为 MCP 服务器的访问令牌。

h.攻击者现在以被入侵用户的身份访问第三方 API。

#### 1.3.4.2 会话安全缺陷

如果实现了MCP client与server的会话机制，自然也就存在会话劫持冒充的问题。（安全威胁7:会话安全漏洞）不建议使用。

# 2. 漏洞危害

- **未授权访问受保护资源**：攻击者可以访问本应需要授权的 MCP 工具和资源
- **数据泄露**：攻击者可以获取敏感的用户数据、配置信息等
- **权限提升**：攻击者可以执行本应需要特定权限的操作
- **系统入侵**：如果 MCP 服务器有管理功能，攻击者可能完全控制用户系统实现RCE（CVE-2025-49596）

# 3. 修复方式

## 3.1 开发原则

- 不要自行实现令牌验证或授权逻辑，使用官方使用的Oauth2.1
- 令牌有效期控制
- 令牌必须验证
- 密钥存储安全（磁盘，代码硬编码）
- https
- 权限最小化
- 日志记录脱敏或者不记录敏感认证信息
- 不要将会话IDMcp-Session-Id等作为授权手段

## 3.2 修复建议

### 3.2.1 安全威胁1：默认弱口令admin/admin

在使用三方授权服务器的时候账号密码需要使用强口令，不要使用示例的默认配置。

### 3.2.2 安全威胁2：权限资源配置缺陷

对于资源服务器或者MCP服务器的SCOPE配置权限需要把关。

### 3.2.3 安全威胁3：配置范围过宽或者错误导致的令牌透传

作用端点没有配置好，导致令牌作用的端点过多，没有做好把控，造成令牌透传到各个作用服务。

### 3.2.4 安全威胁4：可信MCP HOST IP地址配置范围控制缺陷

MCP client动态注册的地址没有配置好，导致任意地址的动态注册，需要进行最小化原则。

### 3.2.5 安全威胁5：client-secret硬编码

建议使用vault进行接入存储secret。

### 3.2.6 安全威胁6：混淆助手攻击

或者叫透传客户端id攻击都可以，官方给出这样的修复建议：使用静态客户端 ID 的 MCP 代理服务器必须先获得每个动态注册客户端的用户同意，然后才能将客户端转发到第三方授权服务器（可能需要额外的同意）。

**解决方案1（让攻击者在1-click情况下拿不到授权码）**

动态注册mcp proxy server的clientid，并在认证服务器中实现动态client_id与redirect_uri的绑定，如果有变化需要提醒安全风险并获取同意。

<div class="mermaid">
graph TB
    subgraph "安全配置"
        A[动态注册MCP Proxy<br/>client_id] --> B[client_id与<br/>redirect_uri绑定]
        B --> C{redirect_uri变化?}
        C -->|是| D[显示安全警告]
        C -->|否| E[正常授权]
        D --> F[要求用户明确同意]
        F --> G[用户确认后授权]
    end
    
    style D fill:#fff3cd
    style F fill:#d1ecf1
    style G fill:#d4edda
</div>

**解决方案2:（攻击者拿到授权码的情况下也拿不到accesstoken）**

使用OAuth-PKCE拓展。

<div class="mermaid">
sequenceDiagram
    participant Client as 客户端
    participant AS as 授权服务器
    
    Note over Client: 生成PKCE参数
    Client->>Client: 生成code_verifier<br/>（随机字符串）
    Client->>Client: 计算code_challenge<br/>SHA256(code_verifier)
    
    Client->>AS: 授权请求<br/>带code_challenge
    AS->>Client: 返回授权码
    
    Note over Client: 必须提供code_verifier
    Client->>AS: Token请求<br/>授权码+code_verifier
    AS->>AS: 验证code_verifier<br/>SHA256(code_verifier)==code_challenge?
    
    alt 验证通过
        AS->>Client: 返回Access Token
    else 验证失败
        AS->>Client: 拒绝请求
    end
    
    Note over Client,AS: 即使攻击者获得授权码<br/>没有code_verifier也无法换取Token
</div>

### 3.2.7 安全威胁7:会话安全漏洞

不要将会话IDMcp-Session-Id等作为授权手段，不建议使用会话做认证，记录状态的时候需要防止透传或者绕过验证信息。
