# 企业交换机知识图谱 · 骨架 v1

> 12 Agent 并行研究（市场×技术×趋势×经典）→ 合成。2026-07-17。

## 核心洞见

交换机的所有复杂性源于一个根本矛盾：**物理分布式的转发设备，需要逻辑一致的全网状态。**

由这个矛盾可以统一解释一切——为什么 SDN 要把控制面抽到一台服务器上？因为分布式一致性太难了。为什么 AI 集群要 PFC+ECN 双环？因为流量突发太快，状态同步跟不上。为什么 Broadcom 80% 份额不可动摇？因为交换芯片的"够快+够一致"太难做，一旦做成就有巨大的沉没成本护城河。为什么以太网总是赢？因为它默认不在追求完美一致性，只追求够好——然后在上面迭代补丁。**以太网赢了四十年不是因为它最好，而是因为它允许你在上面搭任何东西——包括替代它的东西。**

## 八根骨头

### 1. 交换芯片（ASIC Architecture）——"包怎么在硬件里跑"
**核心问题**：一颗交换芯片内部如何实现 Tbps 级线速包处理？
**经典来源**：*Network Algorithmics* (Varghese)、*The All-New Switch Book* (Seifert)
**时效性**：🟡 核心架构稳定，代际参数在变

### 2. 网络操作系统（Switch NOS）——"谁在指挥芯片"
**核心问题**：控制面如何把人类意图翻译成 ASIC 转发表项？
**经典来源**：*Interconnections* (Perlman)、SONiC/SAI 开源生态
**时效性**：🟡 三层架构稳定，SONiC 企业化在演进

### 3. L2/L3 转发与 Overlay 协议栈——"包怎么找到目的地"
**核心问题**：从 MAC 学习到 VXLAN EVPN 到 SRv6，转发平面如何跨越物理拓扑实现虚拟网络的任意连通？
**经典来源**：*Interconnections* (Perlman)、*BGP Design and Implementation*、*TCP/IP Illustrated* (Stevens)
**时效性**：🟢 EVPN/VXLAN 格式已稳定

### 4. 拥塞控制与无损网络——"AI 训练为什么不能丢包"
**核心问题**：RoCEv2 + PFC + ECN + DCQCN 如何让以太网从"尽力而为"变成"零丢包"？
**经典来源**：*TCP/IP Illustrated* (Stevens)、DCQCN 论文、NVIDIA Spectrum-X 工程实践
**时效性**：🔴 UEC 1.0 将重写协议、800G 下参数需重新调优

### 5. 物理层与光互连——"比特怎么变成光"
**核心问题**：SerDes、可插拔光模块、CPO 共封装光学如何定义交换机的物理带宽上限？
**经典来源**：*Ethernet: The Definitive Guide* (Spurgeon)、Broadcom Tomahawk CPO 白皮书
**时效性**：🔴 CPO/LPO/硅光格局未定，2026 是元年

### 6. AI 集群网络架构——"十万张 GPU 怎么连"
**核心问题**：Scale-up（NVLink/UALink）和 Scale-out（Spectrum-X/RoCEv2）如何分工？
**经典来源**：NVIDIA DGX 参考架构、Meta Llama 3 24K-GPU RoCE 论文、UEC 1.0
**时效性**：🔴 最活跃的领域，每月有新部署数据

### 7. 产业竞争格局——"谁在卖、谁在买、为什么赢"
**核心问题**：市场份额、芯片路线、商业模式如何塑造交换机的技术选择和采购决策？
**经典来源**：*Making the Cisco Connection* (Bunnell)、Dell'Oro/IDC 市场数据
**时效性**：🟡 格局趋势清晰，季度份额波动

### 8. 技术史与设计哲学——"这些设计为什么长这样"
**核心问题**：以太网为什么赢、SDN 为什么要把控制面抽出来、解耦为什么不可逆？
**经典来源**：*Dealers of Lightning* (Hiltzik)、*Where Wizards Stay Up Late* (Hafner)
**时效性**：🟢 历史不折旧

## 传导链（DAG）

```
① 交换芯片 ──→ ② NOS ──→ ③ 协议栈 ──┬──→ ④ 拥塞控制（无损网络）
                                       ├──→ ⑤ 物理层/光互连（CPO）
                                       └──→ ⑥ AI 集群网络架构（全部会师）

⑦ 产业格局 —— 全程并行（解释"为什么这个技术是这家公司在推"）
⑧ 技术史   —— 殿后（把 7 根骨头串成因果链）
```

| 传导 | 关系 | 说明 |
|------|------|------|
| ①→② | 强依赖 | 不懂芯片缓存架构，就不懂 NOS 为什么要抽象 SAI |
| ①+②→③ | 强依赖 | 转发逻辑跑在芯片上、由 NOS 控制 |
| ③→④ | 中依赖 | 先懂怎么转发，再懂怎么不丢包 |
| ③+⑤→⑥ | 强依赖 | AI 集群 = 高速物理 + 无损转发 + 拥塞控制 + 拓扑 |
| ⑦ | 并行 | 可全程同步读 |
| ⑧ | 殿后 | 放在最后将前面串成因果链 |

## 经典参考文献

| 书名 | 作者 | 年 | 为什么是经典 |
|------|------|-----|-------------|
| *Interconnections* | Radia Perlman | 1992/1999 | STP 发明者，从算法本质解释交换机/路由器内部工作原理 |
| *Network Algorithmics* | George Varghese | 2004/2022 | 唯一从算法角度系统讲解高速路由器/交换机设计的书 |
| *Ethernet: The Definitive Guide* | Charles Spurgeon | 2000/2014 | 3747 页以太网标准的唯一人类可读版 |
| *The All-New Switch Book* | Rich Seifert | 2000/2008 | 交换机设计者的内部视角——转发引擎、交换矩阵、拥塞控制 |
| *MPLS Fundamentals* | Luc De Ghein | 2006 | 公认最好的单本 MPLS 教材 |
| *BGP Design and Implementation* | Randy Zhang | 2004 | BGP 工程设计的案头书 |
| *TCP/IP Illustrated, Vol 1* | W. Richard Stevens | 1994/2011 | TCP/IP 的事实圣经——用抓包逐字段解释协议行为 |
| *Computer Networking: A Top-Down Approach* | Kurose & Ross | 2000/2020 | 全球使用最广的计算机网络教材 |
| *Making the Cisco Connection* | David Bunnell | 2000 | 唯一一本 Cisco 商业史 |
| *Dealers of Lightning* | Michael Hiltzik | 1999 | 以太网诞生的 PARC 文化 |
| *Where Wizards Stay Up Late* | Katie Hafner | 1996 | ARPANET→Internet 的权威叙事 |

## 每根骨头的经典层 × 前沿层

| 骨头 | 经典层（稳定） | 前沿层（2024-2026） | 时效 |
|------|-------------|-----------------|------|
| 1. 芯片 | Shared buffer vs VOQ 架构原理、包分类算法、交换矩阵设计 | Tomahawk 6(102.4T/3nm) vs Silicon One G300、CPO 封装改造、国产盛科 25.6T | 🟡 |
| 2. NOS | 三平面分离、SAI 接口哲学、ONIE 引导标准 | SONiC 企业发行版对比、Nokia EDA 2026 进展、Cisco→SONiC 迁移工具 | 🟡 |
| 3. 协议 | VXLAN 封装/VNI 空间、BGP EVPN Type-2/5、IP 最长前缀匹配 | UEC 1.0 落地、SRv6 uSID ASIC 兼容、GENEVE vs VXLAN 企业网渗透 | 🟢 |
| 4. 拥塞 | TCP 拥塞控制算法族、PFC 802.1Qbb、DCQCN 三角色模型 | Spectrum-X 自适应路由实测、UEC 新拥塞信令、xAI/Meta 万卡 RoCEv2 生产数据 | 🔴 |
| 5. 物理 | 以太网帧格式、QSFP-DD/OSFP、PAM4 信号完整性 | CPO 商用节奏、LPO 2025-2027 窗口、1.6T OSFP-XD、TSMC COUPE 3D 硅光 | 🔴 |
| 6. AI 网络 | AllReduce 带宽模型、胖树/CLOS 拓扑、ECMP 多路径 | Spectrum-X vs UEC 路线竞争、Meta $135B 采购、UALink vs NVLink、推理网络新需求 | 🔴 |
| 7. 产业 | Cisco 收购驱动模式、以太网 vs ATM/令牌环的"够好且便宜"胜利 | NVIDIA Q1'26 份额 21.5% 跃居第一、HPE $14B 收购 Juniper 整合、中国国产化真实进展 | 🟡 |
| 8. 技术史 | 以太网 PARC→Metcalfe→802.3、IP 尽力而为 Cerf/Kahn、STP Perlman 一天发明→30 年技术债 | UEC 是否成为"以太网的 InfiniBand 时刻"、白盒是否复制 x86 服务器的解耦轨迹 | 🟢 |

## 学习路线

```
零基础：①芯片 → ③协议(到IP路由) → ②NOS → ③(VXLAN/EVPN) → ④拥塞 → ⑤物理 → ⑥AI网络
有基础：③(快速过) → ① → ② → ④ → ⑤ → ⑥
产业视角：⑦ 全程并行
深度理解：⑧ 殿后
```

## 市场速览（研究细节见附录）

- AI 重新定义行业：NVIDIA Q1'26 以 21.5% 份额跃居 DC 以太网第一（年增 192%），靠 GPU+网络捆绑
- 中国格局：华为/H3C/锐捷 三家包揽运营商集采（国产化政策），但制程制裁是硬约束（~2 代差距）
- 芯片底座：Broadcom 80% 商用硅份额，Tomahawk 6（102.4T/3nm）领先 NVIDIA Spectrum 约一年
- 白盒分化：Hyperscaler 70%+ 白盒渗透 vs 企业 <5% vs SP ~10%（Celestica 已是 AI 后端网络第一 ODM）
- CPO 元年 2026：Broadcom Bailly + NVIDIA Spectrum Photonic 率先商用，光模块→芯片内集成
