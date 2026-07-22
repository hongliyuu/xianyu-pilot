# 全局样式模块

`../styles.css` 是唯一入口。导入顺序是级联契约，不能仅为了文件排列而调整。

| 文件 | 职责 |
| --- | --- |
| `tokens.css` | 全局设计令牌，如颜色、阴影、圆角与布局尺寸。 |
| `base.css` | 元素重置与页面基础样式。 |
| `shell.css` | 应用根布局。 |
| `navigation.css` | 桌面侧栏和导航状态。 |
| `workspace.css` | 主内容区、顶部栏和页面标题。 |
| `components.css` | 跨页面复用的卡片、表格、表单、图表等 UI 规则。 |
| `responsive.css` | 现有全局断点规则，保留原有级联顺序。 |
| `assets.css` | 图标与本地视觉资源基础规则。 |
| `overlays.css` | 模态框及扫码、手动添加账号等覆盖层。 |
| `visual-overrides.css` | 从设计资源迁移来的视觉覆盖规则。 |
| `states.css` | 启动、通知、空状态和交互增强规则。 |

页面和组件专属样式仍应放在对应 `.vue` 文件的 `<style scoped>` 中。修改跨页面样式时，先按职责选择模块；涉及断点时，同步检查 `responsive.css` 中的覆盖规则。
