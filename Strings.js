.pragma library

// The panel's Chinese text, keyed by the English it replaces. Panel.qml looks
// every visible string up here through tr(); a key with no entry simply stays
// English, so a new string never breaks the page. %1, %2 … are filled in by
// the caller and may move to wherever the sentence needs them.
var zh = {
  // Hero and filters
  "Agents": "全部 Agent",
  "Subscription": "订阅",
  "Prepaid": "预付费",
  "%1 subscription": "%1 个订阅",
  "%1 subscriptions": "%1 个订阅",
  "%1 tokens today": "今日 %1 token",
  "No AI coding subscriptions found.\nAgents show up here once you've used them.": "未找到 AI 编程订阅。\n用过的 Agent 会显示在这里。",
  "All": "全部",
  "Today": "今天",
  "7d": "7天",
  "30d": "30天",
  "90d": "90天",
  "Cache": "缓存",
  "Project: %1 · click to clear": "项目：%1 · 点击清除",

  // Section names: in the customize list, then as headings
  "Summary": "概览",
  "Activity calendar": "活动日历",
  "Limits": "限额",
  "Plan capacity": "套餐容量",
  "Trend": "趋势",
  "Tokens by agent": "各 Agent 用量",
  "Tokens by model": "各模型用量",
  "Tokens by project": "各项目用量",
  "Token breakdown": "Token 构成",
  "Hours of the week": "一周时段",
  "Top sessions": "会话排行",
  "SUMMARY": "概览",
  "ACTIVITY": "活动",
  "LIMITS": "限额",
  "PLAN CAPACITY": "套餐容量",
  "TREND": "趋势",
  "TOKENS BY AGENT": "各 Agent 用量",
  "TOKENS BY MODEL": "各模型用量",
  "TOKENS BY PROJECT": "各项目用量",
  "TOKEN BREAKDOWN": "Token 构成",
  "HOURS OF THE WEEK": "一周时段",
  "TOP SESSIONS": "会话排行",

  // Customize
  "Customize sections": "自定义板块",
  "Done": "完成",
  "Hide": "隐藏",
  "Show": "显示",

  // Ranges and counts
  "today": "今天",
  "last %1 days": "最近 %1 天",
  "all time": "全部时间",
  " tokens": " token",
  "no activity": "无活动",
  "top %1 of %2": "前 %1 / 共 %2",
  "peak %1": "峰值 %1",

  // Durations
  "now": "现在",
  "%1d %2h": "%1天%2小时",
  "%1h %2m": "%1小时%2分",
  "%1m": "%1分钟",

  // Limits
  "Monthly": "每月",
  "Weekly": "每周",
  "Session": "会话",
  "Limit": "限额",
  "Resets in %1": "%1后重置",
  "Credits": "余额",
  "%1 left": "剩余 %1",
  "%1 spent of %2 funded": "已用 %1 / 充值 %2",
  "estimated": "估算",

  // Status headlines the collectors report
  "Waiting for auth": "等待登录",
  "Sign-in expired": "登录已过期",
  "Balance unavailable": "余额不可用",
  "%1 unavailable": "%1 不可用",
  "%1 limits unavailable": "%1 限额不可用",

  // Summary tiles
  "Tokens": "Token",
  "Tokens, no cache reads": "Token（不含缓存）",
  "Output": "输出",
  "Visible output plus reasoning": "可见输出加推理",
  "Est. cost": "预估费用",
  "%1 unpriced": "%1 个未定价",
  "No price in pricing.json for:": "pricing.json 中没有这些模型的价格：",
  "At the list prices in pricing.json": "按 pricing.json 中的标价计算",
  "Sessions": "会话",
  "%1 requests": "%1 次请求",
  "Cache hit": "缓存命中",
  "Share of prompt tokens served from cache": "提示 token 中由缓存提供的比例",
  "Active days": "活跃天数",
  "of %1": "共 %1 天",
  "flat vs prior": "与上期持平",
  "%1% vs prior": "%1% 较上期",

  // Activity calendar
  "%1 active day": "活跃 %1 天",
  "%1 active days": "活跃 %1 天",
  "Streak %1d · longest %2d": "连续 %1 天 · 最长 %2 天",
  "active, total not recorded": "有活动，未记录总量",
  "Click to clear": "点击清除",
  "Click to show only this day": "点击只看这一天",

  // Plan capacity
  "full window ≈ used ÷ share used": "完整窗口 ≈ 已用 ÷ 已用占比",
  "Used %1 in %2 requests since %3": "自 %3 起 %2 次请求共用 %1",
  "= %1% of the window, measured %2": "= 窗口的 %1%，测量于 %2",
  "Full window ≈ %1": "完整窗口 ≈ %1",
  "%1 at list prices": "按标价 %1",
  "%1 per 30 days": "每 30 天 %1",
  "Counts only what ran on this machine: use elsewhere\non the account makes the real allowance larger.": "只统计本机的用量：账号在别处的使用\n会让实际额度比这里更大。",

  // Trend
  "by hour": "按小时",
  "by day": "按天",
  "by week": "按周",
  "Week of %1": "%1 当周",

  // Lists
  "click to focus": "点击聚焦",
  "Unknown": "未知",
  "In %1 · out %2 · cache read %3 · cache write %4": "输入 %1 · 输出 %2 · 缓存读取 %3 · 缓存写入 %4",
  "filtered · click the row to clear": "已筛选 · 点击该行清除",
  "Click to clear the filter": "点击清除筛选",
  "Click to show only this project": "点击只看这个项目",
  "Input (uncached)": "输入（未缓存）",
  "Cache read": "缓存读取",
  "Cache write": "缓存写入",
  "Reasoning": "推理",
  "cache hit %1": "缓存命中 %1",
  "busiest %1": "最忙 %1",
  "peak context %1": "上下文峰值 %1",
  "unpriced": "未定价",

  // Footer
  "Merged from %1 device": "已合并 %1 台设备",
  "Merged from %1 devices": "已合并 %1 台设备",
  "Usage sync mkdir failed": "用量同步：创建目录失败",
  "Usage sync scan failed": "用量同步：扫描失败"
}
