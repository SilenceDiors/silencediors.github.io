---
layout: home
title: "陈栋梁 (Silen Chen) — 网络安全研究"
description: >-
  陈栋梁 / Silen Chen / SilenceDiors 的个人博客。
  应用安全研究方向,关注 Web 安全、AI 安全、Web3 安全;
  2026 年 2 月获 Apple Web Server Security Acknowledgements 致谢。
---

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Person",
  "name": "Silen Chen",
  "alternateName": ["陈栋梁", "栋梁 陈", "SilenceDiors"],
  "jobTitle": "Application Security Researcher",
  "description": "陈栋梁,网络安全研究方向,关注应用安全、AI 安全、Web3 安全。",
  "url": "https://silencediors.github.io",
  "image": "https://github.com/SilenceDiors.png",
  "sameAs": [
    "https://github.com/SilenceDiors",
    "https://support.apple.com/en-us/102774"
  ],
  "knowsAbout": [
    "网络安全", "应用安全", "Web 安全", "漏洞挖掘",
    "AI 安全", "AI 应用开发平台安全", "MCP 安全",
    "Web3 安全", "智能合约安全", "DeFi 安全"
  ],
  "award": ["Apple Web Server Security Acknowledgements, February 2026"]
}
</script>

<section class="hero">
  <div class="hero-text">
    <h1>陈栋梁 <span class="name-en">Silen Chen</span></h1>
    <p class="tagline">网络安全研究方向 · 关注 Web 安全、AI 安全、Web3 安全</p>
  </div>
  <img class="avatar" src="https://github.com/SilenceDiors.png" alt="Silen Chen" />
</section>

<div class="prose">

平日里挖一些 Web 应用与服务器侧的漏洞,顺手也读读 AI 系统与区块链方向的安全研究。
2026 年 2 月,因报告 Apple 网页服务器的一处授权绕过问题获
[Apple 官方致谢](https://support.apple.com/en-us/102774)
([中文版](https://support.apple.com/zh-cn/102774),February 2026 段落署名 “栋梁 陈”)。

GitHub 上叫 [@SilenceDiors](https://github.com/SilenceDiors),平时把读到、做过的东西写在这里。

</div>

<section class="prose interests">

### 在做什么

- **应用安全 / Web 安全** — 服务器端漏洞挖掘、鉴权机制、业务逻辑
- **AI 安全** — AI 应用开发平台、Agent、MCP 协议的鉴权与威胁建模
- **Web3 安全** — 智能合约审计、DeFi 协议风险、交易系统

</section>

<section class="prose findings">

### Findings

零散记录一些过往做过 / 找到过的事:

- **Apple 网页服务器** — 一处授权绕过问题,获
  [Apple Web Server Security Acknowledgements](https://support.apple.com/en-us/102774)
  致谢(2026 年 2 月,中文版署名 “栋梁 陈”)
- **在某云桌面 / 云浏览器产品中发现的漏洞** — 已通过厂商安全团队修复
- **AI 应用开发平台** — 高危 RCE
- **代币安全审计** — 受限重入(read-only reentrancy)漏洞
- **某交易系统** — 永续合约标记价格操纵问题
- **MQTT 协议中间件** — 鉴权接口限制绕过漏洞,见
  [Issue #15199](https://github.com/emqx/emqx/issues/15199)

</section>
